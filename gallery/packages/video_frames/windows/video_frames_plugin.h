#ifndef FLUTTER_PLUGIN_VIDEO_FRAMES_PLUGIN_H_
#define FLUTTER_PLUGIN_VIDEO_FRAMES_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <map>
#include <memory>

namespace video_frames {

class VideoFileReader;

// Decodes video files for Dart with Media Foundation's source reader, one
// frame per `next` call.
class VideoFramesPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  VideoFramesPlugin();
  ~VideoFramesPlugin() override;
  VideoFramesPlugin(const VideoFramesPlugin&) = delete;
  VideoFramesPlugin& operator=(const VideoFramesPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  bool started_ = false;
  int next_id_ = 0;
  std::map<int, std::unique_ptr<VideoFileReader>> readers_;
};

}  // namespace video_frames

#endif  // FLUTTER_PLUGIN_VIDEO_FRAMES_PLUGIN_H_
