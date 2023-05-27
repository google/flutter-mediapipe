package com.google.mediapipe_task_text

import androidx.annotation.NonNull

import android.content.Context
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.google.mediapipe.examples.textclassifier.TextClassifierHelper


/** MediapipeTaskTextPlugin */
class MediapipeTaskTextPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var classifierHelper: TextClassifierHelper

//  private val listener = object :
//    TextClassifierHelper.TextResultsListener {
//    override fun onResult(
//      results: TextClassifierResult,
//      inferenceTime: Long
//    ) {
//      // Instead of popping a bottomsheet - need to return data on the MethodChannel
//      runOnUiThread {
//        activityMainBinding.bottomSheetLayout.inferenceTimeVal.text =
//          String.format("%d ms", inferenceTime)
//
//        adapter.updateResult(results.classificationResult()
//          .classifications().first()
//          .categories().sortedByDescending {
//              it.score()
//          }, classifierHelper.currentModel
//        )
//      }
//    }
//
//    override fun onError(error: String) {
//      // Instead of popping a toast - need to return the error on the MethodChannel
//      Toast.makeText(this@MainActivity, error, Toast.LENGTH_SHORT).show()
//    }
//  }

  fun registerWith(
    @NonNull registrar: io.flutter.plugin.common.PluginRegistry.Registrar
  ) {
      val plugin = MediapipeTaskTextPlugin();
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
      // a string (I think)
       val results = classifierHelper.classify(call.argument("text") ?: "")
       
       result.success(results)
     } else {
       result.notImplemented()
     }
   }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
