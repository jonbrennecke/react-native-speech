import AVFoundation

enum AudioUtilError: Error {
  case invalidAsset
  case invalidAssetReaderState
}

private let TIME_RANGE_INTERVAL_DURATION: CFTimeInterval = 45
private let TIME_RANGE_ADDITIONAL_END_INTERVAL: CFTimeInterval = 0.25

enum AudioConversionFailure: Error {
  case failedWithError(Error)
  case failedToReadAudioFile
  case failedToCreateOutputFormat
  case failedToCreateInputBuffer
  case failedToCreateOutputBuffer
  case failedToExportAudioFile
  case failedToCreateExportSession
  case missingAudioTrack
}

func generatePCMBuffers(
  fromAudioFile audioFile: AVAudioFile,
  format: AVAudioFormat
) -> Result<[AVAudioPCMBuffer], AudioConversionFailure> {
  let audioFileLength = audioFile.length
  let audioFileSampleRate = audioFile.processingFormat.sampleRate
  let audioFileDuration = CFTimeInterval(audioFileLength) / audioFileSampleRate
  let intervalDuration = getIntervalDuration()
  let durationRemaining = max(audioFileDuration.remainder(dividingBy: intervalDuration), 0)
  let numberOfSplits = Int(floor(audioFileDuration / intervalDuration))
  var splits = Array(
    stride(from: CFTimeInterval(0), to: CFTimeInterval(numberOfSplits) * intervalDuration, by: intervalDuration)
      .map { (start: $0, duration: intervalDuration) }
  )
  if durationRemaining > 0 {
    splits.append((start: audioFileDuration - durationRemaining, duration: durationRemaining))
  }
  let audioBufferResults = splits.map { (split: (CFTimeInterval, CFTimeInterval)) -> Result<AVAudioPCMBuffer, AudioConversionFailure> in
    let (start, duration) = split
    return generatePCMBuffer(
      fromAudioFile: audioFile,
      format: format,
      start: start,
      duration: duration
    )
  }
  return audioBufferResults.reduce(into: .success([])) { acc, result in
    guard case var .success(array) = acc else {
      return
    }
    switch result {
    case let .failure(failure):
      acc = .failure(failure)
    case let .success(buffer):
      array.append(buffer)
      acc = .success(array)
    }
  }
}

fileprivate func getIntervalDuration() -> CFTimeInterval {
  #if targetEnvironment(simulator)
    return CFTimeInterval(15)
  #else
    return UIDevice.current.name.contains("iPhone 6")
      ? CFTimeInterval(15)
      : CFTimeInterval(55)
  #endif
}

fileprivate func generatePCMBuffer(
  fromAudioFile audioFile: AVAudioFile,
  format: AVAudioFormat,
  start: CFTimeInterval,
  duration: CFTimeInterval
) -> Result<AVAudioPCMBuffer, AudioConversionFailure> {
  let audioFileSampleRate = audioFile.processingFormat.sampleRate
  let frameCount = AVAudioFrameCount(duration * audioFileSampleRate)
  guard
    let inputBuffer = AVAudioPCMBuffer(
      pcmFormat: audioFile.processingFormat,
      frameCapacity: frameCount
    )
  else {
    return .failure(.failedToCreateInputBuffer)
  }
  do {
    audioFile.framePosition = AVAudioFramePosition(start * audioFileSampleRate)
    try audioFile.read(into: inputBuffer, frameCount: frameCount)
    return convert(audioPCMBuffer: inputBuffer, to: format)
  } catch {
    return .failure(.failedWithError(error))
  }
}

fileprivate func convert(
  audioPCMBuffer inputBuffer: AVAudioPCMBuffer,
  to outputFormat: AVAudioFormat
) -> Result<AVAudioPCMBuffer, AudioConversionFailure> {
  let sampleRateConversionRatio = inputBuffer.format.sampleRate / outputFormat.sampleRate
  let frameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) / sampleRateConversionRatio)
  guard
    let formatConverter = AVAudioConverter(from: inputBuffer.format, to: outputFormat),
    let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity)
  else {
    return .failure(.failedToCreateOutputBuffer)
  }
  var error: NSError?
  let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
    outStatus.pointee = AVAudioConverterInputStatus.haveData
    return inputBuffer
  }
  formatConverter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
  if let error = error {
    return .failure(.failedWithError(error))
  }
  return .success(outputBuffer)
}

func createTemporaryAudioFile(
  fromAsset asset: AVAsset,
  completionHandler: @escaping (Result<AVAudioFile, AudioConversionFailure>) -> Void
) {
  let audioAssetTracks = asset.tracks(withMediaType: .audio)
  guard let audioAssetTrack = audioAssetTracks.last else {
    return completionHandler(.failure(.missingAudioTrack))
  }
  guard
    let outputURL = try? makeEmptyTemporaryFile(withPathExtension: "m4a"),
    let assetExportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
  else {
    return completionHandler(.failure(.failedToCreateExportSession))
  }
  assetExportSession.outputURL = outputURL
  assetExportSession.outputFileType = .m4a
  assetExportSession.timeRange = audioAssetTrack.timeRange
  assetExportSession.exportAsynchronously {
    if assetExportSession.status == .failed {
      return completionHandler(.failure(.failedToExportAudioFile))
    }
    guard
      let audioFile = try? AVAudioFile(
        forReading: outputURL,
        commonFormat: .pcmFormatInt16,
        interleaved: true
      )
    else {
      return completionHandler(.failure(.failedToExportAudioFile))
    }
    completionHandler(.success(audioFile))
  }
}
