import Foundation

internal func makeEmptyTemporaryFile(withPathExtension pathExtension: String) throws -> URL {
  let outputTemporaryDirectoryURL = try FileManager.default
    .url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: FileManager.default.temporaryDirectory,
      create: true
    )
  let outputURL = outputTemporaryDirectoryURL
    .appendingPathComponent(makeRandomFileName())
    .appendingPathExtension(pathExtension)
  try? FileManager.default.removeItem(at: outputURL)
  return outputURL
}

fileprivate func makeRandomFileName() -> String {
  let random_int = arc4random_uniform(.max)
  return NSString(format: "%x", random_int) as String
}
