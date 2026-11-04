#include "include/video_frames/video_frames_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "video_frames_plugin.h"

void VideoFramesPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  video_frames::VideoFramesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
