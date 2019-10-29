import AVFoundation
import Speech

class FileSpeechTranscriptionRequest: NSObject, SpeechTranscriptionRequest {
  private enum State {
    case unstarted
    case pending([TaskState], CFAbsoluteTime)
    case completed
    case failed
  }

  private enum TaskState {
    case unstarted(SFSpeechAudioBufferRecognitionRequest)
    case pending(SFSpeechRecognitionTask, SFSpeechAudioBufferRecognitionRequest)
    case final(SFSpeechRecognitionResult)
  }

  private enum TaskError: Error {
    case invalidState
    case noUnstartedTasks
  }

  private var state: State = .unstarted
  private let audioFile: AVAudioFile

  private let delegate: SpeechTranscriptionRequestDelegate
  private weak var recognizer: SFSpeechRecognizer! // TODO: should be optional? not optional!

  init?(forAudioFile audioFile: AVAudioFile, recognizer: SFSpeechRecognizer, delegate: SpeechTranscriptionRequestDelegate) {
    self.audioFile = audioFile
    self.recognizer = recognizer
    self.delegate = delegate
    super.init()
  }

  public func startTranscription() -> Result<(), SpeechTranscriptionError> {
    let startTime = CFAbsoluteTimeGetCurrent()
    switch createSpeechRecognitionRequests() {
    case let .success(requests):
      let tasks: [TaskState] = requests.map { .unstarted($0) }
      state = .pending(tasks, startTime)
      if case .failure = runNextTaskAsyncronously() {
        delegate.speechTranscriptionRequestDidFail()
        return .failure(.invalidState)
      }
      return .success(())
    case let .failure(error):
      state = .failed
      return .failure(error)
    }
  }

  private func createSpeechRecognitionRequests() -> Result<[SFSpeechAudioBufferRecognitionRequest], SpeechTranscriptionError> {
    let nativeFormat = createSpeechRecognitionNativeAudioFormat()
    var requests = [SFSpeechAudioBufferRecognitionRequest]()
    let intervals = makeIntervals(forSplitting: audioFile, intervalDuration: 15)
    for interval in intervals {
      let (start, duration) = interval
      let result = generateFixedLengthPCMBuffers(
        audioFile: audioFile,
        format: nativeFormat,
        start: start,
        duration: duration
      )
      switch result {
      case let .success(audioPCMBuffers):
        let request = createSpeechRecognitionRequest()
        audioPCMBuffers.forEach { request.append($0) }
        request.endAudio()
        requests.append(request)
      case .failure:
        return .failure(.invalidAsset)
      }
    }
    return .success(requests)
  }

  private func runNextTaskAsyncronously() -> Result<(), TaskError> {
    guard case .pending(let tasks, _) = state else {
      return .failure(.invalidState)
    }
    guard let index = tasks.firstIndex(where: { taskState in
      guard case .unstarted = taskState else {
        return false
      }
      return true
    }) else {
      return .failure(.noUnstartedTasks)
    }
    return runTaskAsynchronously(index: index)
  }

  private func runTaskAsynchronously(index: Int) -> Result<(), TaskError> {
    guard case .pending(var tasks, let startTime) = state else {
      return .failure(.invalidState)
    }
    if case let .unstarted(request) = tasks[index] {
      let recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
      tasks[index] = .pending(recognitionTask, request)
      state = .pending(tasks, startTime)
      return .success(())
    }
    return .failure(.noUnstartedTasks)
  }

  private func runNextTaskOrFinish() -> Result<(), TaskError> {
    guard case let .pending(tasks, startTime) = state else {
      return .failure(.invalidState)
    }
    if allTasksAreFinalized(tasks) {
      let results = createFinalResults(with: tasks)
      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
      delegate.speechTranscriptionRequest(didFinalizeTranscriptionResults: results, inTime: executionTime)
      delegate.speechTranscriptionRequestDidEnd()
    }
    switch runNextTaskAsyncronously() {
    case .success:
      return .success(())
    case let .failure(error):
      return .failure(error)
    }
  }

  private func createSpeechRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = false
    return request
  }

  private func createSpeechRecognitionNativeAudioFormat() -> AVAudioFormat {
    return createSpeechRecognitionRequest().nativeAudioFormat
  }

  private func allTasksAreFinalized(_ tasks: [TaskState]) -> Bool {
    return tasks.allSatisfy { taskState in
      guard case .final = taskState else {
        return false
      }
      return true
    }
  }

  private func createFinalResults(with tasks: [TaskState]) -> [SFSpeechRecognitionResult] {
    var results = [SFSpeechRecognitionResult]()
    for case let .final(result) in tasks {
      results.append(result)
    }
    return results
  }
}

extension FileSpeechTranscriptionRequest: SFSpeechRecognitionTaskDelegate {
  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully success: Bool) {
    if let error = task.error as NSError? {
      if error.code == 203, error.localizedDescription == "Retry" {
        if case .pending(var tasks, let startTime) = state, tasks.count > 1 {
          guard let index = tasks.firstIndex(where: { state in
            if case let .pending(t, _) = state, t == task {
              return true
            }
            return false
          }) else {
            delegate.speechTranscriptionRequestDidFail()
            return
          }
          tasks.remove(at: index)
          state = .pending(tasks, startTime)
          if case .failure = runNextTaskOrFinish() {
            delegate.speechTranscriptionRequestDidFail()
          }
          return
        }
        // TODO: check error code before sending "speechTranscriptionRequestDidNotDetectSpeech"
        delegate.speechTranscriptionRequestDidNotDetectSpeech()
        delegate.speechTranscriptionRequestDidFail()
        return
      }
    }
    if !success {
      delegate.speechTranscriptionRequestDidFail()
    }
  }

  func speechRecognitionTaskWasCancelled(_: SFSpeechRecognitionTask) {
    // TODO: need to test this case
  }

  func speechRecognitionTaskFinishedReadingAudio(_: SFSpeechRecognitionTask) {}

  func speechRecognitionTask(_: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
    guard case .pending(var tasks, let startTime) = state else {
      // TODO: invalid state
      return
    }
    guard let index = tasks.firstIndex(where: { taskState in
      guard case .pending = taskState else {
        return false
      }
      return true
    }) else {
      return
    }
    tasks[index] = .final(result)
    state = .pending(tasks, startTime)
    if allTasksAreFinalized(tasks) {
      let results = createFinalResults(with: tasks)
      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
      delegate.speechTranscriptionRequest(didFinalizeTranscriptionResults: results, inTime: executionTime)
      delegate.speechTranscriptionRequestDidEnd()
    } else {
      switch runNextTaskAsyncronously() {
      case .success:
        fallthrough
      case .failure(.noUnstartedTasks):
        return
      case .failure:
        delegate.speechTranscriptionRequestDidFail()
      }
    }
  }

  func speechRecognitionTask(_: SFSpeechRecognitionTask, didHypothesizeTranscription _: SFTranscription) {
    // NOTE: unused; FileSpeechTranscriptionRequest does not generate partial results
  }
}
