cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "video_frames")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "video_frames_plugin")
add_library(${PLUGIN_NAME} SHARED "video_frames_plugin.cc")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
# GStreamer, the desktop's media framework; decoding H.264 also needs a
# decoder plugin such as gstreamer1.0-libav.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET
  gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter PkgConfig::GTK PkgConfig::GSTREAMER)

set(video_frames_bundled_libraries "" PARENT_SCOPE)
