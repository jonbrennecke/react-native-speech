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
    case pending(SFSpeechRecognitionTask)
    case final(SFSpeechRecognitionResult)
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
      if case let .failure(reason) = runNextTaskAsyncronously() {
        print(reason)
        delegate.speechTranscriptionRequestDidFail()
      }
      return .success(())
    case let .failure(error):
      state = .failed
      return .failure(error)
    }
  }

  enum TaskError: Error {
    case invalidState
    case noUnstartedTasks
  }

  // TODO: change return value
  private func runNextTaskAsyncronously() -> Result<(), TaskError> {
    guard case .pending(var tasks, let startTime) = state else {
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
    guard case let .unstarted(request) = tasks[index] else {
      return .failure(.noUnstartedTasks)
    }
    print("starting task #\(index) of \(tasks.count)")
    let recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
    tasks[index] = .pending(recognitionTask)
    state = .pending(tasks, startTime)
    return .success(())
  }

  private func createSpeechRecognitionRequests() -> Result<[SFSpeechAudioBufferRecognitionRequest], SpeechTranscriptionError> {
    var requests = [SFSpeechAudioBufferRecognitionRequest]()
    AudioUtil.generatePCMBuffers(fromAudioFile: audioFile, format: createSpeechRecognitionNativeAudioFormat()) { result in
      switch result {
      case let .success(audioPCMBuffer):
        let request = createSpeechRecognitionRequest()
        request.append(audioPCMBuffer)
        request.endAudio()
        requests.append(request)
      case let .failure(reason):
        // TODO: return a failure result from main function
//        return .failure(.invalidAsset)
        print(reason)
        break
      }
    }
    return .success(requests)
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
  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully _: Bool) {
    if let error = task.error as NSError? {
      if error.code == 203, error.localizedDescription == "Retry" {
        // NOTE: if this is not the first video ignore the retry error
        // (e.g. if the video is just slightly longer than the cutoff duration, the 2nd segment will commonly have no speech
        if case .pending(var tasks, let startTime) = state, tasks.count > 1 {
          let maybeIndex = tasks.firstIndex { state in
            if case let .pending(t) = state, t == task {
              return true
            }
            return false
          }
          guard let index = maybeIndex else {
            // TODO: this case is unhandled
            return
          }
          tasks.remove(at: index)
          state = .pending(tasks, startTime)
          if allTasksAreFinalized(tasks) {
            let results = createFinalResults(with: tasks)
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            delegate.speechTranscriptionRequest(didFinalizeTranscriptionResults: results, inTime: executionTime)
            delegate.speechTranscriptionRequestDidEnd()
          } else {
            if case let .failure(reason) = runNextTaskAsyncronously() {
              print(reason)
              delegate.speechTranscriptionRequestDidFail()
            }
          }
          return
        }
        // TODO: check error code before sending "speechTranscriptionRequestDidNotDetectSpeech"
        delegate.speechTranscriptionRequestDidNotDetectSpeech()
        delegate.speechTranscriptionRequestDidFail()
        return
      }
    }
    delegate.speechTranscriptionRequestDidFail()
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
