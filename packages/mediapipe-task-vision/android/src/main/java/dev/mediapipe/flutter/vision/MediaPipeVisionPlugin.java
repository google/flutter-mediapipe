package dev.mediapipe.flutter.vision;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.Looper;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Names the device's GPU for the vision capabilities, which withdraw a GPU
 * path on the GPU families where Google's runtime fails (upstream-issues.md
 * UP-023). The tasks themselves run on Google's MediaPipe vision library
 * through Dart FFI; this plugin does not touch them.
 */
public final class MediaPipeVisionPlugin implements FlutterPlugin {
  private MethodChannel channel;
  private final Handler main = new Handler(Looper.getMainLooper());

  @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "mediapipe_vision/android");
    channel.setMethodCallHandler(this::gpuRenderer);
  }

  @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
  }

  private void gpuRenderer(MethodCall call, MethodChannel.Result reply) {
    if (!"gpuRenderer".equals(call.method)) {
      reply.notImplemented();
      return;
    }
    // Not on the platform thread: probing makes a GL context current.
    new Thread(() -> {
      String name = gpuName();
      main.post(() -> reply.success(name));
    }, "MediaPipe GPU name").start();
  }

  // The GPU's GL renderer and vendor, read once. Empty when no GLES context can
  // be made (then no GPU family is singled out).
  private static volatile String gpuName;

  /** The GPU's name, probed on a thread of its own so no caller's GL state moves. */
  private static String gpuName() {
    String name = gpuName;
    if (name != null) return name;
    String[] found = {""};
    Thread probe = new Thread(() -> found[0] = probeGpuName(), "MediaPipe GPU probe");
    probe.start();
    try {
      probe.join(5000);
    } catch (InterruptedException interrupted) {
      Thread.currentThread().interrupt();
    }
    synchronized (MediaPipeVisionPlugin.class) {
      if (gpuName == null) gpuName = found[0];
      return gpuName;
    }
  }

  /** `renderer (vendor)` from a 1x1 offscreen GLES 2 context, or empty. */
  private static String probeGpuName() {
    EGLDisplay display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
    int[] version = new int[2];
    if (display == EGL14.EGL_NO_DISPLAY || !EGL14.eglInitialize(display, version, 0, version, 1)) {
      return "";
    }
    EGLConfig[] configs = new EGLConfig[1];
    int[] count = new int[1];
    int[] wanted = {EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
        EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE};
    if (!EGL14.eglChooseConfig(display, wanted, 0, configs, 0, 1, count, 0) || count[0] < 1) {
      return "";
    }
    EGLContext glContext = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
        new int[] {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE}, 0);
    EGLSurface surface = EGL14.eglCreatePbufferSurface(display, configs[0],
        new int[] {EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE}, 0);
    String name = "";
    try {
      if (glContext != EGL14.EGL_NO_CONTEXT && surface != EGL14.EGL_NO_SURFACE
          && EGL14.eglMakeCurrent(display, surface, surface, glContext)) {
        String renderer = GLES20.glGetString(GLES20.GL_RENDERER);
        String vendor = GLES20.glGetString(GLES20.GL_VENDOR);
        name = (renderer == null ? "" : renderer) + (vendor == null ? "" : " (" + vendor + ")");
        EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
            EGL14.EGL_NO_CONTEXT);
      }
    } finally {
      if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
      if (glContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, glContext);
      // The default display is shared with Flutter and MediaPipe: never terminated.
      EGL14.eglReleaseThread();
    }
    return name;
  }
}
