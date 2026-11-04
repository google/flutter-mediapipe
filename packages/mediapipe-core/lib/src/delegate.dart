/// The processor a task runs on, chosen when the task is created and fixed
/// until it is disposed. One enum serves vision, text and audio.
enum Delegate {
  /// Google's CPU inference, the default on every platform.
  cpu,

  /// Google's GPU inference: Metal on Apple platforms, OpenGL ES on Linux
  /// and Android, WebGL 2 in browsers. Where a platform's runtime has no GPU
  /// path for a task, its capability query says so and creation fails with
  /// the reason; the package never falls back to the CPU on its own.
  gpu,
}
