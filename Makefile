pigeon:
	cd packages/mediapipe-task-text/mediapipe_task_text_platform_interface && dart run pigeon --input pigeons/classification.dart
	# --dart_out lib/classification.dart --kotlin_package "com.google.mediapipe_task_text" --kotlin_out ../../android/src/main/kotlin/com/google/mediapipe_task_text/TextClassification.kotlin
	# --experimental_swift_out ../ios/Classes/TextClassification.swift

# .PHONY:
# build: build-text
# 	pass