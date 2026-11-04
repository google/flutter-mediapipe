package com.example.mediapipe_gallery;

import android.Manifest;
import android.app.Instrumentation;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/** Same Flutter instrumentation runner as flutter_litert, with camera access. */
@RunWith(FlutterTestRunner.class)
public final class MainActivityTest {
  @Rule public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<MainActivity>(MainActivity.class, true, false) {
        @Override protected void beforeActivityLaunched() {
          Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
          instrumentation.getUiAutomation().grantRuntimePermission(
              instrumentation.getTargetContext().getPackageName(), Manifest.permission.CAMERA);
        }
      };
}
