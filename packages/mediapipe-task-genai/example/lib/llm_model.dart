enum Hardware { cpu, gpu }

enum LlmModel {
  gemma4bCpu,
  gemma4bGpu,
  gemma8bCpu,
  gemma8bGpu;

  Hardware get hardware => switch (this) {
        gemma4bCpu => Hardware.cpu,
        gemma4bGpu => Hardware.gpu,
        gemma8bCpu => Hardware.cpu,
        gemma8bGpu => Hardware.gpu,
      };

  String get dartDefine => switch (this) {
        gemma4bCpu => const String.fromEnvironment('GEMMA_4B_CPU_URI'),
        gemma4bGpu => const String.fromEnvironment('GEMMA_4B_GPU_URI'),
        gemma8bCpu => const String.fromEnvironment('GEMMA_8B_CPU_URI'),
        gemma8bGpu => const String.fromEnvironment('GEMMA_8B_GPU_URI'),
      };

  String get environmentVariableUriName => switch (this) {
        gemma4bCpu => 'GEMMA_4B_CPU_URI',
        gemma4bGpu => 'GEMMA_4B_GPU_URI',
        gemma8bCpu => 'GEMMA_8B_CPU_URI',
        gemma8bGpu => 'GEMMA_8B_GPU_URI',
      };

  String get displayName => switch (this) {
        gemma4bCpu => 'Gemma\n4b CPU',
        gemma4bGpu => 'Gemma\n4b GPU',
        gemma8bCpu => 'Gemma\n8b CPU',
        gemma8bGpu => 'Gemma\n8b GCPU',
      };
}
