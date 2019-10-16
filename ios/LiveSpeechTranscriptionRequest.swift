import AVFoundation
import Speech

class LiveSpeechTranscriptionRequest: NSObject, SpeechTranscriptionRequest {
  private enum State {
    case unstarted
    case pending(TaskState, CFAbsoluteTime)
    case completed
    case failed
  }

  private enum TaskState {
    case unstarted(SFSpeechAudioBufferRecognitionRequest)
    case started(SFSpeechRecognitionTask)
    case stopped(SFSpeechRecognitionTask)
    case final(SFSpeechRecognitionResult)
  }

  private var state: State = .unstarted
  private let delegate: SpeechTranscriptionRequestDelegate
  private weak var audioEngine: AVAudioEngine?
  private weak var recognizer: SFSpeechRecognizer?

  init(audioEngine: AVAudioEngine, recognizer: SFSpeechRecognizer, delegate: SpeechTranscriptionRequestDelegate) {
    self.audioEngine = audioEngine
    self.delegate = delegate
    self.recognizer = recognizer
  }

  public func startTranscription() -> Result<(), SpeechTranscriptionError> {
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playAndRecord)
    try? audioSession.setActive(true, options: AVAudioSession.SetActiveOptions())
    guard let audioEngine = audioEngine else {
      state = .failed
      return .failure(.invalidAudioEngine)
    }
    let startTime = CFAbsoluteTimeGetCurrent()
    audioEngine.reset()
    let node = audioEngine.inputNode
    let format = node.outputFormat(forBus: 0)
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    audioEngine.prepare()
    do {
      try audioEngine.start()
      state = .pending(.unstarted(request), startTime)
      guard let recognizer = recognizer else {
        state = .failed
        return .failure(.invalidSpeechRecognizer)
      }
      let task = recognizer.recognitionTask(with: request, delegate: self)
      state = .pending(.started(task), startTime)
      return .success(())
    } catch {
      state = .failed
      return .failure(.audioEngineError(error))
    }
  }

  public func stopTranscription() -> Result<(), SpeechTranscriptionError> {
    guard let audioEngine = audioEngine, audioEngine.isRunning else {
      state = .failed
      return .failure(.invalidAudioEngine)
    }
    guard case let .pending(.started(task), startTime) = state else {
      return .failure(.invalidState)
    }
    task.cancel()
    audioEngine.stop()
    let node = audioEngine.inputNode
    node.removeTap(onBus: 0)
    state = .pending(.stopped(task), startTime)
    return .success(())
  }
}

extension LiveSpeechTranscriptionRequest: SFSpeechRecognitionTaskDelegate {
  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully success: Bool) {
    if success {
      delegate.speechTranscriptionRequestDidEnd()
      return
    }
    if let error = task.error as NSError? {
      if error.code == 203, error.localizedDescription == "Retry" {
        delegate.speechTranscriptionRequestDidNotDetectSpeech()
        return
      }
    }
    delegate.speechTranscriptionRequestDidFail()
  }

  func speechRecognitionTaskWasCancelled(_: SFSpeechRecognitionTask) {}

  func speechRecognitionTaskFinishedReadingAudio(_: SFSpeechRecognitionTask) {}

  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
    guard case let .pending(.stopped(pendingTask), startTime) = state, pendingTask == task else {
      return
    }
    state = .pending(.final(result), startTime)
    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
    delegate.speechTranscriptionRequest(didFinalizeTranscriptionResults: [result], inTime: executionTime)
  }

  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
    guard case let .pending(.started(pendingTask), _) = state, pendingTask == task else {
      return
    }
    delegate.speechTranscriptionRequest(didHypothesizeTranscriptions: [transcription])
  }
}
