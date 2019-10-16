import AVFoundation

enum AudioUtilError: Error {
  case invalidAsset
  case invalidAssetReaderState
}

private let TIME_RANGE_INTERVAL_DURATION_FOR_MEMORY_LIMITED_DEVICES: CFTimeInterval = 15 // TODO:
private let TIME_RANGE_INTERVAL_DURATION: CFTimeInterval = 45
private let TIME_RANGE_ADDITIONAL_END_INTERVAL: CFTimeInterval = 0.25

class AudioUtil {
  private static let queue = DispatchQueue(label: "audio conversion queue")

  // TODO: refactor this to take an AVAssetTrack as input
  public static func extractMonoAudio(forAsset asset: AVAsset, _ completionHandler: @escaping (Error?, AVAsset?) -> Void) {
    asset.loadValuesAsynchronously(forKeys: ["playable"]) {
      do {
        let audioAssetTracks = asset.tracks(withMediaType: .audio)
        guard let audioAssetTrack = audioAssetTracks.last else {
          completionHandler(nil, nil)
          return
        }
        let outputURL = try FileManager.default
          .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          .appendingPathComponent("mono_output")
          .appendingPathExtension("mov")
        try? FileManager.default.removeItem(at: outputURL)
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let assetReader = try AVAssetReader(asset: asset)
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        channelLayout.mChannelBitmap = []
        channelLayout.mNumberChannelDescriptions = 0
        let channelLayoutAsData = NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout))
        let readerSettings: [String: Any] = [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVChannelLayoutKey: channelLayoutAsData,
          AVNumberOfChannelsKey: 1,
        ]
        let assetReaderOutput = AVAssetReaderTrackOutput(track: audioAssetTrack, outputSettings: readerSettings)
        assetReaderOutput.alwaysCopiesSampleData = false
        if assetReader.canAdd(assetReaderOutput) {
          assetReader.add(assetReaderOutput)
        }
        let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        assetWriterInput.expectsMediaDataInRealTime = false
        if assetWriter.canAdd(assetWriterInput) {
          assetWriter.add(assetWriterInput)
        }
        let readerSuccess = assetReader.startReading()
        if !readerSuccess {
          completionHandler(assetWriter.error, nil)
          return
        }
        let writerSuccess = assetWriter.startWriting()
        if !writerSuccess {
          completionHandler(assetWriter.error, nil)
          return
        }
        assetWriter.startSession(atSourceTime: .zero)
        assetWriterInput.requestMediaDataWhenReady(on: queue) {
          while true {
            if !assetWriterInput.isReadyForMoreMediaData {
              continue
            }
            if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
              assetWriterInput.append(sampleBuffer)
            } else {
              break
            }
          }
          assetReader.cancelReading()
          assetWriterInput.markAsFinished()
          assetWriter.endSession(atSourceTime: asset.duration)
          assetWriter.finishWriting {
            let outputAsset = AVURLAsset(url: outputURL)
            completionHandler(nil, outputAsset)
          }
        }
      } catch {
        completionHandler(error, nil)
      }
    }
  }

  private static func createSampleBuffers(withAsset asset: AVAsset, _ sampleCallback: (CMSampleBuffer) -> Void) -> AudioUtilError? {
    guard case let .success(result) = createAssetReaderAndOutput(withAsset: asset) else {
      return .invalidAsset
    }
    let (assetReader, assetReaderOutput) = result
    let audioAssetTracks = asset.tracks(withMediaType: .audio)
    guard let audioAssetTrack = audioAssetTracks.last else {
      return .invalidAsset
    }
    let timeRanges = splitTimeRanges(withAssetTrack: audioAssetTrack)
    for (index, timeRange) in timeRanges.enumerated() {
      if index > 0 {
        assetReaderOutput.reset(forReadingTimeRanges: [timeRange as NSValue])
      } else {
        assetReader.timeRange = timeRange
        assetReader.startReading()
      }
      while assetReader.status == .reading {
        guard let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() else {
          break
        }
        guard CMSampleBufferIsValid(sampleBuffer), let desc = CMSampleBufferGetFormatDescription(sampleBuffer),
          CMAudioFormatDescriptionGetStreamBasicDescription(desc) != nil else {
          continue
        }
        sampleCallback(sampleBuffer)
      }
    }
    assetReader.cancelReading()
    return nil
  }

  public static func createAssetReaderAndOutput(withAsset asset: AVAsset)
    -> Result<(AVAssetReader, AVAssetReaderTrackOutput), AudioUtilError> {
    let audioAssetTracks = asset.tracks(withMediaType: .audio)
    guard let audioAssetTrack = audioAssetTracks.last else {
      return .failure(.invalidAsset)
    }
    let assetReaderOutput = AVAssetReaderTrackOutput(track: audioAssetTrack, outputSettings: nil)
    assetReaderOutput.alwaysCopiesSampleData = false
    assetReaderOutput.supportsRandomAccess = true
    do {
      let assetReader = try AVAssetReader(asset: asset)
      if !assetReader.canAdd(assetReaderOutput) {
        return .failure(.invalidAssetReaderState)
      }
      assetReader.add(assetReaderOutput)
      return .success((assetReader, assetReaderOutput))
    } catch {
      return .failure(.invalidAsset)
    }
  }

  public static func splitTimeRanges(withAssetTrack assetTrack: AVAssetTrack) -> [CMTimeRange] {
    let intervalDuration = TIME_RANGE_INTERVAL_DURATION
    if assetTrack.timeRange.duration < CMTimeMakeWithSeconds(intervalDuration, preferredTimescale: 600) {
      return [assetTrack.timeRange]
    }
    let maxSegmentDuration = CMTimeMakeWithSeconds(intervalDuration, preferredTimescale: 600)
    var segmentStart = assetTrack.timeRange.start
    var timeRanges = [CMTimeRange]()
    while segmentStart < assetTrack.timeRange.end {
      let additionalEndTime = CMTimeMakeWithSeconds(TIME_RANGE_ADDITIONAL_END_INTERVAL, preferredTimescale: 600)
      let segmentEnd = min(segmentStart + maxSegmentDuration + additionalEndTime, assetTrack.timeRange.end)
      let timeRange = CMTimeRange(start: segmentStart, end: segmentEnd)
      timeRanges.append(timeRange)
      segmentStart = min(segmentStart + maxSegmentDuration, assetTrack.timeRange.end)
    }
    return timeRanges
  }
}