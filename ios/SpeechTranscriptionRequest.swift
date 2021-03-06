import AVFoundation
import Speech

enum SpeechTranscriptionError: Error {
  case invalidState
  case invalidAsset
  case invalidAudioEngine
  case invalidSpeechRecognizer
  case audioEngineError(Error)
}

protocol SpeechTranscriptionRequestDelegate {
  func speechTranscriptionRequestDidNotDetectSpeech()
  func speechTranscriptionRequestDidEnd()
  func speechTranscriptionRequestDidFail()
  func speechTranscriptionRequest(didHypothesizeTranscriptions: [SFTranscription])
  func speechTranscriptionRequest(didFinalizeTranscriptionResults: [SFSpeechRecognitionResult], inTime: CFAbsoluteTime)
}

protocol SpeechTranscriptionRequest {
  func startTranscription() -> Result<(), SpeechTranscriptionError>
}
