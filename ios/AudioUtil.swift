import AVFoundation

enum AudioUtilError: Error {
  case invalidAsset
  case invalidAssetReaderState
}

private let TIME_RANGE_INTERVAL_DURATION: CFTimeInterval = 45
private let TIME_RANGE_ADDITIONAL_END_INTERVAL: CFTimeInterval = 0.25

class AudioUtil {
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

  static func generatePCMBuffers(
    fromAudioFile audioFile: AVAudioFile,
    format: AVAudioFormat,
    _ callback: (Result<AVAudioPCMBuffer, AudioConversionFailure>) -> Void
  ) {
    let audioFileLength = audioFile.length
    let sampleRate = audioFile.processingFormat.sampleRate
    let audioFileDuration = CFTimeInterval(audioFileLength) / sampleRate
    let durationRemaining = audioFileDuration.remainder(dividingBy: 30)
    let numberOfSplits = Int(floor(audioFileDuration / 30))
    var splits = Array(
      stride(from: CFTimeInterval(0), to: CFTimeInterval(numberOfSplits * 30), by: CFTimeInterval(30))
        .map { (start: $0, duration: CFTimeInterval(30)) }
    )
    splits.append((start: audioFileDuration - durationRemaining, duration: audioFileDuration))
    splits.forEach { split in
      let (_, duration) = split
      let frameCount = duration * sampleRate
      let generateBufferResult = generatePCMBuffer(
        fromAudioFile: audioFile,
        format: format,
        frameCount: AVAudioFrameCount(frameCount)
      )
      callback(generateBufferResult)
    }
  }

  static func generatePCMBuffer(fromAudioFile audioFile: AVAudioFile, format: AVAudioFormat, frameCount: AVAudioFrameCount) -> Result<AVAudioPCMBuffer, AudioConversionFailure> {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: format.commonFormat,
        sampleRate: audioFile.processingFormat.sampleRate,
        channels: 1,
        interleaved: true
      )
    else {
      return .failure(.failedToCreateOutputFormat)
    }
    guard
      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: frameCount
      )
    else {
      return .failure(.failedToCreateInputBuffer)
    }
    do {
      try audioFile.read(into: inputBuffer, frameCount: frameCount)
      return convert(audioPCMBuffer: inputBuffer, to: format)
    } catch {
      return .failure(.failedWithError(error))
    }
  }

  static func convert(
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

  static func createTemporaryAudioFile(
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
}
