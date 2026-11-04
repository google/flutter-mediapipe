//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <camera_desktop/camera_desktop_plugin.h>
#include <file_selector_windows/file_selector_windows.h>
#include <video_frames/video_frames_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  CameraDesktopPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CameraDesktopPlugin"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  VideoFramesPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("VideoFramesPluginCApi"));
}
