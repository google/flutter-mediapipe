package dev.mediapipe.gallery.videoframes;

import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.media.Image;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Decodes video files for Dart with MediaExtractor and MediaCodec, one frame per {@code next}
 * call. Each file decodes on a thread of its own; replies go back on the main thread, as Flutter
 * requires.
 */
public final class VideoFramesPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private final Handler main = new Handler(Looper.getMainLooper());
  private final Map<Integer, Reader> readers = new HashMap<>();
  private MethodChannel channel;
  private int nextId;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "video_frames");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    for (Reader reader : readers.values()) reader.post(reader::close);
    readers.clear();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    switch (call.method) {
      case "open": {
        String path = call.argument("path");
        int id = nextId++;
        Reader reader = new Reader(path);
        reader.post(() -> {
          try {
            Map<String, Object> info = reader.open();
            info.put("id", id);
            main.post(() -> {
              readers.put(id, reader);
              result.success(info);
            });
          } catch (Exception error) {
            reader.close();
            main.post(() -> result.error("open", String.valueOf(error.getMessage()), null));
          }
        });
        break;
      }
      case "next": {
        Integer id = call.argument("id");
        Reader reader = id == null ? null : readers.get(id);
        if (reader == null) {
          result.error("next", "No such video file", null);
          return;
        }
        reader.post(() -> {
          try {
            Map<String, Object> frame = reader.next();
            main.post(() -> result.success(frame));
          } catch (Exception error) {
            main.post(() -> result.error("next", String.valueOf(error.getMessage()), null));
          }
        });
        break;
      }
      case "close": {
        Integer id = call.argument("id");
        Reader reader = id == null ? null : readers.remove(id);
        if (reader != null) reader.post(reader::close);
        result.success(null);
        break;
      }
      default:
        result.notImplemented();
    }
  }

  /** One file's extractor and decoder, used on its own thread only. */
  private static final class Reader {
    private static final long WAIT_MICROSECONDS = 10_000;
    private final String path;
    private final HandlerThread thread = new HandlerThread("video_frames");
    private final Handler handler;
    private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    private MediaExtractor extractor;
    private MediaCodec codec;
    private boolean inputDone;
    private boolean outputDone;
    // How far the file's edit list moves its video earlier where the
    // extractor ignores it (editListStartUs), set from the first frame.
    private long shiftUs;
    private boolean shifted;

    Reader(String path) {
      this.path = path;
      thread.start();
      handler = new Handler(thread.getLooper());
    }

    void post(Runnable task) {
      handler.post(task);
    }

    /** Selects the first video track and starts a decoder that writes flexible YUV images. */
    Map<String, Object> open() throws IOException {
      extractor = new MediaExtractor();
      extractor.setDataSource(path);
      MediaFormat format = null;
      for (int i = 0; i < extractor.getTrackCount(); i++) {
        MediaFormat candidate = extractor.getTrackFormat(i);
        String mime = candidate.getString(MediaFormat.KEY_MIME);
        if (mime != null && mime.startsWith("video/")) {
          extractor.selectTrack(i);
          format = candidate;
          break;
        }
      }
      if (format == null) throw new IOException(path + " has no video track.");
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) shiftUs = editListStartUs(path);
      Map<String, Object> info = new HashMap<>();
      // The clockwise turn the file asks for, as Android documents it.
      info.put("rotation", format.containsKey(MediaFormat.KEY_ROTATION)
          ? ((format.getInteger(MediaFormat.KEY_ROTATION) % 360) + 360) % 360 : 0);
      info.put("durationUs", format.containsKey(MediaFormat.KEY_DURATION)
          ? format.getLong(MediaFormat.KEY_DURATION) : 0L);
      info.put("frameRate", frameRate(format));
      codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME));
      format.setInteger(MediaFormat.KEY_COLOR_FORMAT,
          MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
      codec.configure(format, null, null, 0);
      codec.start();
      return info;
    }

    /**
     * Where the first video track's edit list starts its media, in microseconds, or 0. An encoder
     * that reorders frames (H.264 B-frames) writes the reorder delay there, 66.7 ms for two frames
     * at 30 a second, so that the first frame shows at zero. Android 9's extractor ignores it for
     * video; Android 10 applies it (mElstShiftStartTicks in MPEG4Extractor).
     */
    private static long editListStartUs(String path) {
      try (RandomAccessFile file = new RandomAccessFile(path, "r")) {
        long[] moov = box(file, 0, file.length(), "moov");
        for (long at = moov == null ? 0 : moov[0]; moov != null; ) {
          long[] trak = box(file, at, moov[1], "trak");
          if (trak == null) break;
          at = trak[1];
          long[] mdia = box(file, trak[0], trak[1], "mdia");
          long[] hdlr = mdia == null ? null : box(file, mdia[0], mdia[1], "hdlr");
          if (hdlr == null) continue;
          // Version and flags, pre_defined, then the handler type.
          file.seek(hdlr[0] + 8);
          if (file.readInt() != 0x76696465 /* vide */) continue;
          long[] mdhd = box(file, mdia[0], mdia[1], "mdhd");
          long[] edts = box(file, trak[0], trak[1], "edts");
          long[] elst = edts == null ? null : box(file, edts[0], edts[1], "elst");
          if (mdhd == null || elst == null) return 0;
          file.seek(mdhd[0]);
          int version = file.readInt() >>> 24;
          file.skipBytes(version == 1 ? 16 : 8);
          long timescale = file.readInt() & 0xffffffffL;
          file.seek(elst[0]);
          version = file.readInt() >>> 24;
          long entries = file.readInt() & 0xffffffffL;
          for (long i = 0; i < entries && timescale > 0; i++) {
            // Segment duration, then media time; -1 marks an empty edit.
            long mediaTime;
            if (version == 1) {
              file.readLong();
              mediaTime = file.readLong();
            } else {
              file.readInt();
              mediaTime = file.readInt();
            }
            if (mediaTime >= 0) return mediaTime * 1_000_000 / timescale;
          }
          return 0;
        }
      } catch (IOException unreadable) {
        // A file the extractor reads but this cannot keeps its timestamps.
      }
      return 0;
    }

    /** The payload start and end of the first [type] box from start to end, or null. */
    private static long[] box(RandomAccessFile file, long start, long end, String type)
        throws IOException {
      for (long at = start; at + 8 <= end; ) {
        file.seek(at);
        long size = file.readInt() & 0xffffffffL;
        byte[] name = new byte[4];
        file.readFully(name);
        long header = 8;
        if (size == 1) {
          size = file.readLong();
          header = 16;
        } else if (size == 0) {
          size = end - at;
        }
        if (size < header) return null;
        if (new String(name, StandardCharsets.US_ASCII).equals(type)) {
          return new long[] {at + header, at + size};
        }
        at += size;
      }
      return null;
    }

    private static double frameRate(MediaFormat format) {
      if (!format.containsKey(MediaFormat.KEY_FRAME_RATE)) return 0;
      try {
        return format.getInteger(MediaFormat.KEY_FRAME_RATE);
      } catch (ClassCastException notInteger) {
        return format.getFloat(MediaFormat.KEY_FRAME_RATE);
      }
    }

    /** Feeds samples until the decoder returns a frame; null after the last one. */
    Map<String, Object> next() {
      if (codec == null) throw new IllegalStateException("The video file is closed.");
      while (!outputDone) {
        if (!inputDone) feed();
        int index = codec.dequeueOutputBuffer(info, WAIT_MICROSECONDS);
        if (index < 0) continue;
        boolean end = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
        if (end) outputDone = true;
        Map<String, Object> frame = null;
        if (info.size > 0) {
          try (Image image = codec.getOutputImage(index)) {
            if (image == null) throw new IllegalStateException("The decoder returned no image.");
            if (!shifted) {
              // As Android 10 does: never past the first frame, so no
              // timestamp goes below zero.
              shiftUs = Math.min(shiftUs, info.presentationTimeUs);
              shifted = true;
            }
            frame = copy(image, info.presentationTimeUs - shiftUs);
          }
        }
        codec.releaseOutputBuffer(index, false);
        if (frame != null) return frame;
      }
      return null;
    }

    private void feed() {
      int index = codec.dequeueInputBuffer(WAIT_MICROSECONDS);
      if (index < 0) return;
      ByteBuffer buffer = codec.getInputBuffer(index);
      int size = buffer == null ? -1 : extractor.readSampleData(buffer, 0);
      if (size < 0) {
        codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        inputDone = true;
      } else {
        codec.queueInputBuffer(index, 0, size, extractor.getSampleTime(), 0);
        extractor.advance();
      }
    }

    /**
     * The image's visible area as three 8-bit planes. 8-bit YUV goes out as the decoder wrote it,
     * from the crop's first sample with the decoder's strides; 10-bit P010 keeps each sample's
     * high byte.
     */
    private static Map<String, Object> copy(Image image, long timestamp) {
      Rect crop = image.getCropRect();
      Image.Plane[] planes = image.getPlanes();
      List<Object> copied = new ArrayList<>();
      boolean tenBit = image.getFormat() == ImageFormat.YCBCR_P010;
      if (!tenBit && image.getFormat() != ImageFormat.YUV_420_888) {
        throw new IllegalStateException("Unsupported decoder output format " + image.getFormat());
      }
      for (int p = 0; p < 3; p++) {
        int shift = p == 0 ? 0 : 1;
        // P010 may come as Y and one interleaved UV plane, V two bytes after
        // U, rather than as three planes.
        boolean interleaved = planes.length < 3 && p > 0;
        Image.Plane plane = planes[interleaved ? 1 : p];
        ByteBuffer buffer = plane.getBuffer();
        int rowStride = plane.getRowStride();
        int pixelStride = plane.getPixelStride();
        int offset = (crop.top >> shift) * rowStride + (crop.left >> shift) * pixelStride;
        if (tenBit) {
          // 16-bit little-endian samples with the value in the high bits.
          int width = (crop.width() + shift) >> shift;
          int height = (crop.height() + shift) >> shift;
          int sample = interleaved && p == 2 ? 2 : 0;
          byte[] bytes = new byte[width * height];
          for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
              bytes[y * width + x] = buffer.get(offset + y * rowStride + x * pixelStride + sample + 1);
            }
          }
          copied.add(List.of(bytes, width, 1));
        } else {
          ByteBuffer view = buffer.duplicate();
          view.position(offset);
          byte[] bytes = new byte[view.remaining()];
          view.get(bytes);
          copied.add(List.of(bytes, rowStride, pixelStride));
        }
      }
      Map<String, Object> frame = new HashMap<>();
      frame.put("timestampUs", timestamp);
      frame.put("width", crop.width());
      frame.put("height", crop.height());
      frame.put("layout", "yuv420");
      frame.put("planes", copied);
      return frame;
    }

    void close() {
      if (codec != null) {
        try {
          codec.stop();
        } catch (IllegalStateException alreadyStopped) {
          // A decoder that failed is in no state to stop; it is released below.
        }
        codec.release();
        codec = null;
      }
      if (extractor != null) {
        extractor.release();
        extractor = null;
      }
      thread.quitSafely();
    }
  }
}
