package com.google.mediapipe_task_text

import androidx.annotation.NonNull

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.google.mediapipe.examples.textclassifier.TextClassifierHelper
import TextClassifierResult


/** MediaPipeTaskTextPlugin */
class MediaPipeTaskTextPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var classifierHelper: TextClassifierHelper

  fun registerWith(
    @NonNull registrar: io.flutter.plugin.common.PluginRegistry.Registrar
  ) {
      val plugin = MediaPipeTaskTextPlugin();
    }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "mediapipe_task_text")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

   override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
     if (call.method == "initClassifier") {
       classifierHelper = TextClassifierHelper(
         currentModel = call.argument("modelPath")!!,
         context = context,
       )
     } else if (call.method == "classify") {
       val results: TextClassifierResult = classifierHelper.classify(call.argument("text") ?: "")
       print(results.toList())
       // asdf
       result.success(results.toList())
     } else {
       result.notImplemented()
     }
   }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
