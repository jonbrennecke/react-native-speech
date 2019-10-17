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
      startNextTask()
      return .success(())
    case let .failure(error):
      state = .failed
      return .failure(error)
    }
  }

  private func startNextTask() {
    guard case .pending(var tasks, let startTime) = state else {
      state = .failed
      return
    }
    let maybeIndex = tasks.firstIndex { state in
      guard case .unstarted = state else {
        return false
      }
      return true
    }
    guard let index = maybeIndex else {
      state = .completed
      return
    }
    guard case let .unstarted(request) = tasks[index] else {
      state = .completed
      return
    }
    let recognitionTask = recognizer.recognitionTask(with: request, delegate: self)
    tasks[index] = .pending(recognitionTask)
    state = .pending(tasks, startTime)
  }

  private func createSpeechRecognitionRequests() -> Result<[SFSpeechAudioBufferRecognitionRequest], SpeechTranscriptionError> {
    var requests = [SFSpeechAudioBufferRecognitionRequest]()
    let request = createSpeechRecognitionRequest()
    switch AudioUtil.generatePCMBuffer(fromAudioFile: audioFile, format: request.nativeAudioFormat) {
    case let .success(audioPCMBuffer):
      request.append(audioPCMBuffer)
    case .failure:
      return .failure(.invalidAsset)
    }
    request.endAudio()
    requests.append(request)
    return .success(requests)
  }

  private func createSpeechRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = false
    return request
  }

  private func checkIfFinalized(tasks: [TaskState], startTime: CFAbsoluteTime) {
    let areAllTasksFinalized = tasks.allSatisfy { state in
      guard case .final = state else {
        return false
      }
      return true
    }
    if areAllTasksFinalized {
      var results = [SFSpeechRecognitionResult]()
      for case let .final(result) in tasks {
        results.append(result)
      }
      let executionTime = CFAbsoluteTimeGetCurrent() - startTime
      delegate.speechTranscriptionRequest(didFinalizeTranscriptionResults: results, inTime: executionTime)
    } else {
      startNextTask()
    }
  }
}

extension FileSpeechTranscriptionRequest: SFSpeechRecognitionTaskDelegate {
  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully success: Bool) {
    if success {
      delegate.speechTranscriptionRequestDidEnd()
      return
    }
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
            // TODO:
            return
          }
          tasks.remove(at: index)
          state = .pending(tasks, startTime)
          checkIfFinalized(tasks: tasks, startTime: startTime)
          delegate.speechTranscriptionRequestDidEnd()
          return
        }
        delegate.speechTranscriptionRequestDidNotDetectSpeech()
        delegate.speechTranscriptionRequestDidFail()
        return
      }
    }
    guard case .pending = state else {
      delegate.speechTranscriptionRequestDidEnd()
      return
    }
    delegate.speechTranscriptionRequestDidFail()
  }

  func speechRecognitionTaskWasCancelled(_: SFSpeechRecognitionTask) {}

  func speechRecognitionTaskFinishedReadingAudio(_: SFSpeechRecognitionTask) {}

  func speechRecognitionTask(_: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
    guard case .pending(var tasks, let startTime) = state else {
      // TODO: invalid state
      return
    }
    let maybeIndex = tasks.firstIndex { state in
      guard case .pending = state else {
        return false
      }
      return true
    }
    guard let index = maybeIndex else {
      // TODO: invalid state
      return
    }
    guard case .pending = tasks[index] else {
      // TODO: invalid state
      return
    }
    tasks[index] = .final(result)
    state = .pending(tasks, startTime)
    checkIfFinalized(tasks: tasks, startTime: startTime)
  }

  func speechRecognitionTask(_: SFSpeechRecognitionTask, didHypothesizeTranscription _: SFTranscription) {
    // NOTE: unused; FileSpeechTranscriptionRequest does not generate partial results
  }
}
