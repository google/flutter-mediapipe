#include "video_frames_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

namespace video_frames {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

namespace {

constexpr DWORD kVideo = static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);

std::wstring Wide(const std::string& utf8) {
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring wide(static_cast<size_t>(size > 0 ? size - 1 : 0), L'\0');
  if (size > 1) {
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  }
  return wide;
}

std::string Describe(const char* what, HRESULT status) {
  char code[16];
  snprintf(code, sizeof(code), "0x%08lX", static_cast<unsigned long>(status));
  return std::string(what) + " failed (" + code + ")";
}

}  // namespace

// One file's source reader, which converts every decoder output to 32-bit
// RGB (BGRX in memory) with Media Foundation's video processor.
class VideoFileReader {
 public:
  // Opens [path]; on failure returns null and sets [error].
  static std::unique_ptr<VideoFileReader> Open(const std::string& path,
                                               std::string* error) {
    auto reader = std::unique_ptr<VideoFileReader>(new VideoFileReader());
    ComPtr<IMFAttributes> attributes;
    HRESULT status = MFCreateAttributes(&attributes, 1);
    if (SUCCEEDED(status)) {
      status = attributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
    }
    if (SUCCEEDED(status)) {
      status = MFCreateSourceReaderFromURL(Wide(path).c_str(), attributes.Get(),
                                           &reader->reader_);
    }
    if (FAILED(status)) {
      *error = Describe("Opening the file", status);
      return nullptr;
    }
    reader->reader_->SetStreamSelection(
        static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
    status = reader->reader_->SetStreamSelection(kVideo, TRUE);
    if (FAILED(status)) {
      *error = path + " has no video track.";
      return nullptr;
    }
    // MF_MT_VIDEO_ROTATION is the clockwise turn that shows the frame
    // upright, as Dart takes it: the gallery's rotated.mp4, tagged to be
    // shown a quarter turn clockwise, reads 90.
    ComPtr<IMFMediaType> native;
    if (SUCCEEDED(reader->reader_->GetNativeMediaType(kVideo, 0, &native))) {
      UINT32 rotation = 0;
      if (SUCCEEDED(native->GetUINT32(MF_MT_VIDEO_ROTATION, &rotation))) {
        reader->rotation_ = static_cast<int>(rotation % 360);
      }
      MFGetAttributeSize(native.Get(), MF_MT_FRAME_SIZE, &reader->native_width_,
                         &reader->native_height_);
      UINT32 numerator = 0, denominator = 0;
      if (SUCCEEDED(MFGetAttributeRatio(native.Get(), MF_MT_FRAME_RATE,
                                        &numerator, &denominator)) &&
          denominator > 0) {
        reader->frame_rate_ = static_cast<double>(numerator) / denominator;
      }
    }
    ComPtr<IMFMediaType> output;
    status = MFCreateMediaType(&output);
    if (SUCCEEDED(status)) status = output->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    if (SUCCEEDED(status)) status = output->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    if (SUCCEEDED(status)) {
      status = reader->reader_->SetCurrentMediaType(kVideo, nullptr, output.Get());
    }
    if (FAILED(status) || !reader->ReadFormat()) {
      *error = Describe("Choosing RGB32 output", status);
      return nullptr;
    }
    PROPVARIANT duration;
    PropVariantInit(&duration);
    if (SUCCEEDED(reader->reader_->GetPresentationAttribute(
            static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE), MF_PD_DURATION,
            &duration)) &&
        duration.vt == VT_UI8) {
      // 100-nanosecond units.
      reader->duration_us_ = static_cast<int64_t>(duration.uhVal.QuadPart / 10);
    }
    PropVariantClear(&duration);
    return reader;
  }

  EncodableMap Info() const {
    return {
        {EncodableValue("rotation"), EncodableValue(rotation_)},
        {EncodableValue("durationUs"), EncodableValue(duration_us_)},
        {EncodableValue("frameRate"), EncodableValue(frame_rate_)},
    };
  }

  // The next frame as top-down BGRA; nullopt with an empty [error] after the
  // last frame.
  std::optional<EncodableMap> Next(std::string* error) {
    while (true) {
      DWORD flags = 0;
      LONGLONG timestamp = 0;
      ComPtr<IMFSample> sample;
      const HRESULT status =
          reader_->ReadSample(kVideo, 0, nullptr, &flags, &timestamp, &sample);
      if (FAILED(status)) {
        *error = Describe("Decoding", status);
        return std::nullopt;
      }
      if (flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) {
        if (!ReadFormat()) {
          *error = "The video changed to a format the reader cannot read.";
          return std::nullopt;
        }
      }
      if (flags & MF_SOURCE_READERF_ENDOFSTREAM) return std::nullopt;
      if (!sample) continue;
      ComPtr<IMFMediaBuffer> buffer;
      if (FAILED(sample->ConvertToContiguousBuffer(&buffer))) continue;
      BYTE* data = nullptr;
      DWORD length = 0;
      if (FAILED(buffer->Lock(&data, nullptr, &length))) continue;
      const LONG row = stride_ < 0 ? -stride_ : stride_;
      std::vector<uint8_t> pixels;
      if (length >= static_cast<DWORD>(row) * frame_height_) {
        pixels.resize(static_cast<size_t>(width_) * height_ * 4);
        for (UINT32 y = 0; y < height_; y++) {
          // A negative stride stores the bottom row first.
          const size_t source_row =
              stride_ < 0 ? frame_height_ - 1 - (top_ + y) : top_ + y;
          const BYTE* source = data + source_row * static_cast<size_t>(row) +
                               static_cast<size_t>(left_) * 4;
          uint8_t* target = pixels.data() + static_cast<size_t>(y) * width_ * 4;
          memcpy(target, source, static_cast<size_t>(width_) * 4);
          // RGB32 leaves the fourth byte undefined.
          for (UINT32 x = 0; x < width_; x++) target[x * 4 + 3] = 255;
        }
      }
      buffer->Unlock();
      if (pixels.empty()) continue;
      EncodableList plane = {EncodableValue(std::move(pixels)),
                             EncodableValue(static_cast<int32_t>(width_ * 4)),
                             EncodableValue(4)};
      return EncodableMap{
          // 100-nanosecond units.
          {EncodableValue("timestampUs"), EncodableValue(static_cast<int64_t>(timestamp / 10))},
          {EncodableValue("width"), EncodableValue(static_cast<int32_t>(width_))},
          {EncodableValue("height"), EncodableValue(static_cast<int32_t>(height_))},
          {EncodableValue("layout"), EncodableValue("bgra")},
          {EncodableValue("planes"), EncodableValue(EncodableList{EncodableValue(plane)})},
      };
    }
  }

 private:
  VideoFileReader() = default;

  // Reads the output size, stride and visible area, again whenever the
  // format changes.
  bool ReadFormat() {
    ComPtr<IMFMediaType> current;
    if (FAILED(reader_->GetCurrentMediaType(kVideo, &current)) ||
        FAILED(MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &frame_width_,
                                  &frame_height_))) {
      return false;
    }
    UINT32 stride = 0;
    if (SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE, &stride))) {
      stride_ = static_cast<LONG>(stride);
    } else if (FAILED(MFGetStrideForBitmapInfoHeader(MFVideoFormat_RGB32.Data1,
                                                     frame_width_, &stride_))) {
      return false;
    }
    // H.264 decodes whole 16-pixel macroblocks, so a 960x540 file comes out
    // 960x544; the display aperture is the part the file shows.
    left_ = 0;
    top_ = 0;
    width_ = frame_width_;
    height_ = frame_height_;
    for (const GUID& key : {MF_MT_MINIMUM_DISPLAY_APERTURE, MF_MT_GEOMETRIC_APERTURE}) {
      MFVideoArea area = {};
      UINT32 size = 0;
      if (FAILED(current->GetBlob(key, reinterpret_cast<UINT8*>(&area),
                                  static_cast<UINT32>(sizeof(area)), &size)) ||
          size != sizeof(area) || area.OffsetX.value < 0 || area.OffsetY.value < 0 ||
          area.Area.cx <= 0 || area.Area.cy <= 0) {
        continue;
      }
      const UINT32 left = static_cast<UINT32>(area.OffsetX.value);
      const UINT32 top = static_cast<UINT32>(area.OffsetY.value);
      const UINT32 width = static_cast<UINT32>(area.Area.cx);
      const UINT32 height = static_cast<UINT32>(area.Area.cy);
      if (left + width > frame_width_ || top + height > frame_height_) continue;
      left_ = left;
      top_ = top;
      width_ = width;
      height_ = height;
      return true;
    }
    // Without an aperture, the track's own size, from the file, is the
    // visible part, at the top left.
    if (native_width_ > 0 && native_height_ > 0 && native_width_ <= frame_width_ &&
        native_height_ <= frame_height_) {
      width_ = native_width_;
      height_ = native_height_;
    }
    return true;
  }

  ComPtr<IMFSourceReader> reader_;
  // The track's size as the file declares it, the decoded frame, and the
  // visible part of the frame.
  UINT32 native_width_ = 0;
  UINT32 native_height_ = 0;
  UINT32 frame_width_ = 0;
  UINT32 frame_height_ = 0;
  UINT32 left_ = 0;
  UINT32 top_ = 0;
  UINT32 width_ = 0;
  UINT32 height_ = 0;
  LONG stride_ = 0;
  int rotation_ = 0;
  int64_t duration_us_ = 0;
  double frame_rate_ = 0;
};

// static
void VideoFramesPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "video_frames",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<VideoFramesPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

VideoFramesPlugin::VideoFramesPlugin() {
  started_ = SUCCEEDED(MFStartup(MF_VERSION));
}

VideoFramesPlugin::~VideoFramesPlugin() {
  readers_.clear();
  if (started_) MFShutdown();
}

// Decoding runs on the platform thread: one frame of a short clip takes a few
// milliseconds, and replies must come from this thread anyway.
void VideoFramesPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  const auto argument = [arguments](const char* key) -> const EncodableValue* {
    if (arguments == nullptr) return nullptr;
    const auto found = arguments->find(EncodableValue(key));
    return found == arguments->end() ? nullptr : &found->second;
  };
  const std::string& method = call.method_name();
  if (method == "open") {
    const auto* path = argument("path");
    if (!started_ || path == nullptr || !std::holds_alternative<std::string>(*path)) {
      result->Error("open", started_ ? "No path" : "Media Foundation did not start");
      return;
    }
    std::string error;
    auto reader = VideoFileReader::Open(std::get<std::string>(*path), &error);
    if (!reader) {
      result->Error("open", error);
      return;
    }
    const int id = next_id_++;
    EncodableMap info = reader->Info();
    info[EncodableValue("id")] = EncodableValue(id);
    readers_[id] = std::move(reader);
    result->Success(EncodableValue(info));
    return;
  }
  const auto* id_value = argument("id");
  const int id = id_value != nullptr && std::holds_alternative<int32_t>(*id_value)
                     ? std::get<int32_t>(*id_value)
                     : -1;
  if (method == "next") {
    const auto found = readers_.find(id);
    if (found == readers_.end()) {
      result->Error("next", "No such video file");
      return;
    }
    std::string error;
    auto frame = found->second->Next(&error);
    if (frame) {
      result->Success(EncodableValue(*frame));
    } else if (error.empty()) {
      result->Success();
    } else {
      result->Error("next", error);
    }
  } else if (method == "close") {
    readers_.erase(id);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace video_frames
