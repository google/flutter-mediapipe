#include "include/video_frames/video_frames_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gst/app/gstappsink.h>
#include <gst/gst.h>
#include <gst/video/video.h>

#include <cstring>
#include <map>
#include <memory>
#include <string>

// Decodes video files for Dart with GStreamer, one frame per `next` call:
// playbin picks the demuxer and decoder, and an appsink behind videoconvert
// receives every frame as RGBA. Pulling runs on the platform thread; the
// pipeline decodes on GStreamer's own threads, so a pull waits only for the
// frame in progress.

namespace {

FlMethodResponse* Failure(const char* code, const std::string& message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message.c_str(), nullptr));
}

// The clockwise turn GStreamer's image-orientation tag names.
int ClockwiseDegrees(const gchar* orientation) {
  if (orientation == nullptr) return 0;
  if (g_str_has_suffix(orientation, "-90")) return 90;
  if (g_str_has_suffix(orientation, "-180")) return 180;
  if (g_str_has_suffix(orientation, "-270")) return 270;
  return 0;
}

// The pipeline's first error on its bus, if any.
std::string BusError(GstElement* pipeline) {
  g_autoptr(GstBus) bus = gst_element_get_bus(pipeline);
  g_autoptr(GstMessage) message =
      gst_bus_pop_filtered(bus, GST_MESSAGE_ERROR);
  if (message == nullptr) return "";
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* debug = nullptr;
  gst_message_parse_error(message, &error, &debug);
  return error != nullptr ? error->message : "GStreamer failed.";
}

class VideoFileReader {
 public:
  ~VideoFileReader() {
    if (pipeline_ != nullptr) {
      gst_element_set_state(pipeline_, GST_STATE_NULL);
      gst_object_unref(pipeline_);
    }
  }

  // Opens [path] and prerolls the first frame; on failure sets [error].
  bool Open(const std::string& path, std::string* error) {
    g_autoptr(GError) uri_error = nullptr;
    g_autofree gchar* uri = gst_filename_to_uri(path.c_str(), &uri_error);
    if (uri == nullptr) {
      *error = uri_error != nullptr ? uri_error->message : "Bad path";
      return false;
    }
    pipeline_ = gst_element_factory_make("playbin", nullptr);
    GstElement* sink = gst_element_factory_make("appsink", "frames");
    GstElement* convert = gst_element_factory_make("videoconvert", nullptr);
    GstElement* audio = gst_element_factory_make("fakesink", nullptr);
    if (pipeline_ == nullptr || sink == nullptr || convert == nullptr ||
        audio == nullptr) {
      *error = "GStreamer lacks playbin, videoconvert or appsink.";
      return false;
    }
    g_autoptr(GstCaps) caps = gst_caps_new_simple(
        "video/x-raw", "format", G_TYPE_STRING, "RGBA", nullptr);
    // Unsynchronized, so frames come as fast as they are pulled; two in the
    // queue keep the decoder busy without holding the whole file.
    g_object_set(sink, "caps", caps, "sync", FALSE, "max-buffers", 2, "drop",
                 FALSE, nullptr);
    GstElement* video = gst_bin_new(nullptr);
    gst_bin_add_many(GST_BIN(video), convert, sink, nullptr);
    gst_element_link(convert, sink);
    g_autoptr(GstPad) input = gst_element_get_static_pad(convert, "sink");
    gst_element_add_pad(video, gst_ghost_pad_new("sink", input));
    g_object_set(pipeline_, "uri", uri, "video-sink", video, "audio-sink",
                 audio, nullptr);
    appsink_ = GST_APP_SINK(sink);

    gst_element_set_state(pipeline_, GST_STATE_PAUSED);
    if (gst_element_get_state(pipeline_, nullptr, nullptr, 30 * GST_SECOND) ==
        GST_STATE_CHANGE_FAILURE) {
      *error = BusError(pipeline_);
      if (error->empty()) *error = "GStreamer cannot decode " + path + ".";
      return false;
    }
    g_autoptr(GstSample) preroll = gst_app_sink_pull_preroll(appsink_);
    GstCaps* negotiated =
        preroll != nullptr ? gst_sample_get_caps(preroll) : nullptr;
    GstVideoInfo info;
    if (negotiated == nullptr || !gst_video_info_from_caps(&info, negotiated)) {
      *error = path + " has no video track.";
      return false;
    }
    if (GST_VIDEO_INFO_FPS_D(&info) > 0) {
      frame_rate_ = static_cast<double>(GST_VIDEO_INFO_FPS_N(&info)) /
                    GST_VIDEO_INFO_FPS_D(&info);
    }
    GstTagList* tags = nullptr;
    g_signal_emit_by_name(pipeline_, "get-video-tags", 0, &tags);
    if (tags != nullptr) {
      gchar* orientation = nullptr;
      if (gst_tag_list_get_string(tags, GST_TAG_IMAGE_ORIENTATION,
                                  &orientation)) {
        rotation_ = ClockwiseDegrees(orientation);
        g_free(orientation);
      }
      gst_tag_list_unref(tags);
    }
    gint64 duration = 0;
    if (gst_element_query_duration(pipeline_, GST_FORMAT_TIME, &duration)) {
      duration_us_ = duration / 1000;
    }
    // The preroll frame comes back as the first pulled sample.
    gst_element_set_state(pipeline_, GST_STATE_PLAYING);
    return true;
  }

  FlValue* Info() const {
    FlValue* info = fl_value_new_map();
    fl_value_set_string_take(info, "rotation", fl_value_new_int(rotation_));
    fl_value_set_string_take(info, "durationUs", fl_value_new_int(duration_us_));
    fl_value_set_string_take(info, "frameRate", fl_value_new_float(frame_rate_));
    return info;
  }

  // The next frame's RGBA rows, or null after the last frame; a failure sets
  // [error].
  FlValue* Next(std::string* error) {
    while (true) {
      g_autoptr(GstSample) sample = gst_app_sink_pull_sample(appsink_);
      if (sample == nullptr) {
        *error = BusError(pipeline_);
        return nullptr;
      }
      GstBuffer* buffer = gst_sample_get_buffer(sample);
      GstVideoInfo info;
      if (buffer == nullptr || !GST_BUFFER_PTS_IS_VALID(buffer) ||
          !gst_video_info_from_caps(&info, gst_sample_get_caps(sample))) {
        continue;
      }
      // The buffer carries the track's media time. A file's edit list, which
      // delays an H.264 track by the encoder's frame reordering (two frames
      // in the sample clip), lives in the segment, so the stream time is the
      // timestamp the file shows the frame at, as the other platforms report.
      const GstSegment* segment = gst_sample_get_segment(sample);
      const guint64 time =
          segment == nullptr
              ? GST_BUFFER_PTS(buffer)
              : gst_segment_to_stream_time(segment, GST_FORMAT_TIME,
                                           GST_BUFFER_PTS(buffer));
      if (time == GST_CLOCK_TIME_NONE) continue;
      GstVideoFrame frame;
      if (!gst_video_frame_map(&frame, &info, buffer, GST_MAP_READ)) continue;
      const int stride = GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0);
      const int height = GST_VIDEO_FRAME_HEIGHT(&frame);
      FlValue* pixels = fl_value_new_uint8_list(
          static_cast<const uint8_t*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0)),
          static_cast<size_t>(stride) * height);
      FlValue* result = fl_value_new_map();
      fl_value_set_string_take(
          result, "timestampUs",
          fl_value_new_int(static_cast<int64_t>(time / 1000)));
      fl_value_set_string_take(result, "width",
                               fl_value_new_int(GST_VIDEO_FRAME_WIDTH(&frame)));
      fl_value_set_string_take(result, "height", fl_value_new_int(height));
      fl_value_set_string_take(result, "layout", fl_value_new_string("rgba"));
      FlValue* plane = fl_value_new_list();
      fl_value_append_take(plane, pixels);
      fl_value_append_take(plane, fl_value_new_int(stride));
      fl_value_append_take(plane, fl_value_new_int(4));
      FlValue* planes = fl_value_new_list();
      fl_value_append_take(planes, plane);
      fl_value_set_string_take(result, "planes", planes);
      gst_video_frame_unmap(&frame);
      return result;
    }
  }

 private:
  GstElement* pipeline_ = nullptr;
  GstAppSink* appsink_ = nullptr;
  int rotation_ = 0;
  int64_t duration_us_ = 0;
  double frame_rate_ = 0;
};

}  // namespace

#define VIDEO_FRAMES_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), video_frames_plugin_get_type(), \
                              VideoFramesPlugin))

struct _VideoFramesPlugin {
  GObject parent_instance;
  std::map<int, std::unique_ptr<VideoFileReader>>* readers;
  int next_id;
};

G_DEFINE_TYPE(VideoFramesPlugin, video_frames_plugin, g_object_get_type())

static int64_t ArgumentId(FlValue* arguments) {
  FlValue* id = arguments != nullptr &&
                        fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP
                    ? fl_value_lookup_string(arguments, "id")
                    : nullptr;
  return id != nullptr && fl_value_get_type(id) == FL_VALUE_TYPE_INT
             ? fl_value_get_int(id)
             : -1;
}

static void video_frames_plugin_handle_method_call(VideoFramesPlugin* self,
                                                   FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* arguments = fl_method_call_get_args(method_call);
  if (strcmp(method, "open") == 0) {
    FlValue* path = arguments != nullptr &&
                            fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP
                        ? fl_value_lookup_string(arguments, "path")
                        : nullptr;
    std::string error;
    auto reader = std::make_unique<VideoFileReader>();
    if (path == nullptr || fl_value_get_type(path) != FL_VALUE_TYPE_STRING) {
      response = Failure("open", "No path");
    } else if (!reader->Open(fl_value_get_string(path), &error)) {
      response = Failure("open", error);
    } else {
      const int id = self->next_id++;
      g_autoptr(FlValue) info = reader->Info();
      fl_value_set_string_take(info, "id", fl_value_new_int(id));
      (*self->readers)[id] = std::move(reader);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(info));
    }
  } else if (strcmp(method, "next") == 0) {
    const auto found = self->readers->find(static_cast<int>(ArgumentId(arguments)));
    if (found == self->readers->end()) {
      response = Failure("next", "No such video file");
    } else {
      std::string error;
      g_autoptr(FlValue) frame = found->second->Next(&error);
      if (frame == nullptr && !error.empty()) {
        response = Failure("next", error);
      } else {
        g_autoptr(FlValue) none = fl_value_new_null();
        response = FL_METHOD_RESPONSE(
            fl_method_success_response_new(frame != nullptr ? frame : none));
      }
    }
  } else if (strcmp(method, "close") == 0) {
    self->readers->erase(static_cast<int>(ArgumentId(arguments)));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

static void video_frames_plugin_dispose(GObject* object) {
  VideoFramesPlugin* self = VIDEO_FRAMES_PLUGIN(object);
  delete self->readers;
  self->readers = nullptr;
  G_OBJECT_CLASS(video_frames_plugin_parent_class)->dispose(object);
}

static void video_frames_plugin_class_init(VideoFramesPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_frames_plugin_dispose;
}

static void video_frames_plugin_init(VideoFramesPlugin* self) {
  self->readers = new std::map<int, std::unique_ptr<VideoFileReader>>();
  self->next_id = 0;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  video_frames_plugin_handle_method_call(VIDEO_FRAMES_PLUGIN(user_data),
                                         method_call);
}

void video_frames_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  gst_init(nullptr, nullptr);
  VideoFramesPlugin* plugin = VIDEO_FRAMES_PLUGIN(
      g_object_new(video_frames_plugin_get_type(), nullptr));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "video_frames", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
