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

func makeIntervals(forSplitting audioFile: AVAudioFile, intervalDuration: CFTimeInterval) -> [(start: CFTimeInterval, duration: CFTimeInterval)] {
  let audioFileLength = audioFile.length
  let audioFileSampleRate = audioFile.processingFormat.sampleRate
  let audioFileDuration = CFTimeInterval(audioFileLength) / audioFileSampleRate
  let numberOfSplits = Int(floor(audioFileDuration / intervalDuration))
  var splits = Array(
    stride(from: CFTimeInterval(0), to: CFTimeInterval(numberOfSplits) * intervalDuration, by: intervalDuration)
      .map { (start: $0, duration: min(intervalDuration, audioFileDuration)) }
  )
  let durationRemaining = audioFileDuration.remainder(dividingBy: intervalDuration)
  if durationRemaining > 0 {
    splits.append((start: audioFileDuration - durationRemaining, duration: durationRemaining))
  } else if durationRemaining < 0 {
    let duration = audioFileDuration - intervalDuration * CFTimeInterval(numberOfSplits)
    splits.append((start: audioFileDuration - duration, duration: duration))
  }
  return splits
}

func generateFixedLengthPCMBuffers(
  audioFile: AVAudioFile,
  format: AVAudioFormat,
  start: CFTimeInterval,
  duration: CFTimeInterval,
  bufferFrameCount: Int = 1024
) -> Result<[AVAudioPCMBuffer], AudioConversionFailure> {
  let audioFileSampleRate = audioFile.processingFormat.sampleRate
  let startFramePosition = Int(start * audioFileSampleRate)
  let endFramePosition = Int((start + duration) * audioFileSampleRate)
  var buffers = [AVAudioPCMBuffer]()
  for framePosition in stride(from: startFramePosition, to: endFramePosition, by: Int(bufferFrameCount)) {
    switch generatePCMBuffer(
      fromAudioFile: audioFile,
      format: format,
      framePosition: AVAudioFramePosition(framePosition),
      frameCount: AVAudioFrameCount(bufferFrameCount)
    ) {
    case let .success(buffer):
      buffers.append(buffer)
    case let .failure(error):
      return .failure(error)
    }
  }
  return .success(buffers)
}

fileprivate func generatePCMBuffer(
  fromAudioFile audioFile: AVAudioFile,
  format: AVAudioFormat,
  framePosition: AVAudioFramePosition,
  frameCount: AVAudioFrameCount
) -> Result<AVAudioPCMBuffer, AudioConversionFailure> {
  let readFrameCount = min(frameCount, AVAudioFrameCount(audioFile.length - framePosition))
  guard
    let inputBuffer = AVAudioPCMBuffer(
      pcmFormat: audioFile.processingFormat,
      frameCapacity: readFrameCount
    )
  else {
    return .failure(.failedToCreateInputBuffer)
  }
  do {
    audioFile.framePosition = framePosition
    try audioFile.read(into: inputBuffer, frameCount: readFrameCount)
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
        interleaved: false
      )
    else {
      return completionHandler(.failure(.failedToExportAudioFile))
    }
    completionHandler(.success(audioFile))
  }
}
