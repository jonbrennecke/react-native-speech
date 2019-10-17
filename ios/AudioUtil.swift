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
    _ callback: (Result<AVAudioPCMBuffer, AudioConversionFailure>) -> Void
  ) {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44100,
        channels: 1,
        interleaved: true
      )
    else {
      callback(.failure(.failedToCreateOutputFormat))
      return
    }
    var offset: UInt32 = 0
    let audioFileLength = AVAudioFrameCount(audioFile.length)
    var size = AVAudioFrameCount(4096)
    audioFile.framePosition = AVAudioFramePosition(offset)
    while offset <= audioFile.length {
      if audioFileLength - offset < size {
        size = audioFileLength - size
      }
      guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: size) else {
        callback(.failure(.failedToCreateOutputBuffer))
        return
      }
      do {
        try audioFile.read(into: outputBuffer, frameCount: size)
        callback(.success(outputBuffer))
      } catch {
        callback(.failure(.failedWithError(error)))
      }
      offset += size
    }
  }

  static func generatePCMBuffer(fromAudioFile audioFile: AVAudioFile, format: AVAudioFormat) -> Result<AVAudioPCMBuffer, AudioConversionFailure> {
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: format.commonFormat,
        sampleRate: audioFile.processingFormat.sampleRate,
        channels: 1,
        interleaved: true
      ),
      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: AVAudioFrameCount(audioFile.length)
      )
    else {
      return .failure(.failedToCreateInputBuffer)
    }
    do {
      try audioFile.read(into: inputBuffer)
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
    let frameCapacity = AVAudioFrameCount(Double(inputBuffer.frameCapacity) / sampleRateConversionRatio)
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
