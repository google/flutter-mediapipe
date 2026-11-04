cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "video_frames")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "video_frames_plugin")
add_library(${PLUGIN_NAME} SHARED
  "include/video_frames/video_frames_plugin_c_api.h"
  "video_frames_plugin_c_api.cpp"
  "video_frames_plugin.cpp"
  "video_frames_plugin.h"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
# Media Foundation's source reader, which ships with Windows.
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter flutter_wrapper_plugin mfplat mfreadwrite mfuuid)

set(video_frames_bundled_libraries "" PARENT_SCOPE)
