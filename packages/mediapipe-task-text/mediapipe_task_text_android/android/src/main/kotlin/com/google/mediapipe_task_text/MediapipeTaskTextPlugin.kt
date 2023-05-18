package com.google.mediapipe_task_text

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MediapipeTaskTextPlugin */
class MediapipeTaskTextPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  // private lateinit var channel : MethodChannel
  // private lateinit var context: Context
  // private lateinit var activity: Activity

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

//   override fun onAttachedToActivity(binding: ActivityPluginBinding) {
//     activity = binding.activity
//   }

//   override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
//     channel = MethodChannel(flutterPluginBinding.binaryMessenger, "mediapipe_task_text")
//     channel.setMethodCallHandler(this)
//     context = flutterPluginBinding.applicationContext
//   }

   override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
     if (call.method == "getPlatformVersion") {
       result.success("Android ${android.os.Build.VERSION.RELEASE}")
     } else if (call.method == "initClassifier") {
       var classifier = TextClassifierHelper(
         currentModel = call.argument("modelPath")!!,
         context = context
 //          context = this@MainActivity,
 //          listener = listener
       )
     } else if (call.method == "classify") {
       // inferenceTime is the amount of time, in milliseconds, that it takes to
       // classify the input text.
       var inferenceTime = SystemClock.uptimeMillis()
       val results = classifier.classify(call.argument("text") ?: "")
       inferenceTime = SystemClock.uptimeMillis() - inferenceTime
       val item = results.classificationResult().classifications()[0].categories()[0]
       // TODO: MARSHAL `results`!
       result.success(item.categoryName() + " " + item.score())
     } else {
       result.notImplemented()
     }
   }

//   override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
//     channel.setMethodCallHandler(null)
//   }
}
