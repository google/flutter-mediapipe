#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import AVFoundation
import CoreVideo

/// Decodes video files for Dart with AVAssetReader, one frame per `next`
/// call. Each file has its own reader and serial queue, so decoding never runs
/// on the main thread; replies go back on the main thread.
public final class VideoFramesPlugin: NSObject, FlutterPlugin {
  private var readers: [Int: VideoFileReader] = [:]
  private var nextId = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "video_frames", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(VideoFramesPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "open":
      guard let path = arguments["path"] as? String else {
        result(FlutterError(code: "open", message: "No path", details: nil))
        return
      }
      let id = nextId
      nextId += 1
      let reader = VideoFileReader(url: URL(fileURLWithPath: path))
      Task {
        do {
          var info = try await reader.open()
          info["id"] = id
          await MainActor.run {
            self.readers[id] = reader
            result(info)
          }
        } catch {
          await MainActor.run { result(Self.failure("open", error)) }
        }
      }
    case "next":
      guard let id = arguments["id"] as? Int, let reader = readers[id] else {
        result(FlutterError(code: "next", message: "No such video file", details: nil))
        return
      }
      reader.queue.async {
        do {
          let frame = try reader.next()
          DispatchQueue.main.async { result(frame) }
        } catch {
          DispatchQueue.main.async { result(Self.failure("next", error)) }
        }
      }
    case "close":
      if let id = arguments["id"] as? Int, let reader = readers.removeValue(forKey: id) {
        reader.queue.async { reader.close() }
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func failure(_ code: String, _ error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
}

private struct VideoFileError: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

/// One file's track output; used on [queue] only once opened.
private final class VideoFileReader: @unchecked Sendable {
  let queue = DispatchQueue(label: "video_frames.reader")
  private let url: URL
  private var reader: AVAssetReader?
  private var output: AVAssetReaderTrackOutput?

  init(url: URL) { self.url = url }

  /// Opens the first video track and starts reading it as BGRA, which
  /// AVFoundation converts to from any pixel format, 10-bit HDR included.
  func open() async throws -> [String: Any] {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw VideoFileError("\(url.lastPathComponent) has no video track.")
    }
    let (transform, rate) = try await track.load(.preferredTransform, .nominalFrameRate)
    let duration = try await asset.load(.duration)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    guard reader.startReading() else {
      throw reader.error ?? VideoFileError("AVAssetReader did not start.")
    }
    self.reader = reader
    self.output = output
    return [
      "rotation": Self.clockwiseDegrees(transform),
      "durationUs": Self.microseconds(duration) ?? 0,
      "frameRate": Double(rate),
    ]
  }

  /// The next frame's BGRA pixels, or nil after the last frame.
  func next() throws -> [String: Any]? {
    guard let reader, let output else { throw VideoFileError("The video file is closed.") }
    while true {
      guard let sample = output.copyNextSampleBuffer() else {
        if reader.status == .failed {
          throw reader.error ?? VideoFileError("Decoding failed.")
        }
        return nil
      }
      // A sample without an image, such as a track's end marker, has no frame.
      guard let buffer = CMSampleBufferGetImageBuffer(sample),
        let timestamp = Self.microseconds(CMSampleBufferGetPresentationTimeStamp(sample))
      else { continue }
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
      guard let base = CVPixelBufferGetBaseAddress(buffer) else { continue }
      let height = CVPixelBufferGetHeight(buffer)
      let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
      let pixels = Data(bytes: base, count: bytesPerRow * height)
      return [
        "timestampUs": timestamp,
        "width": CVPixelBufferGetWidth(buffer),
        "height": height,
        "layout": "bgra",
        "planes": [[FlutterStandardTypedData(bytes: pixels), bytesPerRow, 4]],
      ]
    }
  }

  func close() {
    reader?.cancelReading()
    reader = nil
    output = nil
  }

  /// The clockwise turn the track's display transform applies, a multiple of
  /// 90: a phone's portrait video is stored sideways with a quarter turn.
  private static func clockwiseDegrees(_ transform: CGAffineTransform) -> Int {
    let quarters = Int((atan2(transform.b, transform.a) * 2 / .pi).rounded())
    return ((quarters % 4) + 4) % 4 * 90
  }

  private static func microseconds(_ time: CMTime) -> Int? {
    guard time.isValid, time.isNumeric else { return nil }
    return Int(CMTimeConvertScale(time, timescale: 1_000_000, method: .roundHalfAwayFromZero).value)
  }
}
