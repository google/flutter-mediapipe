"""Unit tests for the R8 check: python3 -B -m unittest tool/ci/test_check_r8_usage.py"""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_r8_usage  # noqa: E402

# Lines from R8's usage.txt for release galleries, as R8 wrote them. Other
# libraries lose instance fields too; only the plugins' fields matter here.
OTHER_LIBRARIES = '''\
androidx.activity.OnBackPressedDispatcher:
    private final kotlin.Lazy eventInput$delegate
    private final java.lang.Runnable fallbackOnBackPressed
'''

# The fix: what R8 still removes from the plugins is expected.
FIXED = OTHER_LIBRARIES + '''\
dev.mediapipe.flutter.audio.R
dev.mediapipe.flutter.text.R
dev.mediapipe.flutter.vision.MediaPipeVisionPlugin$1:
    final synthetic dev.mediapipe.flutter.vision.MediaPipeVisionPlugin this$0
dev.mediapipe.flutter.vision.MediaPipeVisionPlugin:
    private static final java.lang.String MASKS
    private static final java.lang.String TAG
dev.mediapipe.flutter.text.MediaPipeTextPlugin:
    public static void close(dev.mediapipe.flutter.text.MediaPipeTextPlugin$Task)
    public static java.lang.Long timestamp(java.util.Optional)
'''

# bcd6e7d, which shipped UP-033: both Task fields holding a model buffer gone.
BCD6E7D = FIXED + '''\
dev.mediapipe.flutter.audio.MediaPipeAudioPlugin$Task:
    final java.nio.ByteBuffer model
dev.mediapipe.flutter.text.MediaPipeTextPlugin$Task:
    final java.nio.ByteBuffer model
'''


class CheckR8UsageTest(unittest.TestCase):
    def test_bcd6e7d_names_both_model_buffers(self):
        self.assertEqual(check_r8_usage.removed_fields(BCD6E7D), [
            'dev.mediapipe.flutter.audio.MediaPipeAudioPlugin$Task: '
            'final java.nio.ByteBuffer model',
            'dev.mediapipe.flutter.text.MediaPipeTextPlugin$Task: '
            'final java.nio.ByteBuffer model',
        ])

    def test_constants_synthetics_methods_and_other_libraries_pass(self):
        self.assertEqual(check_r8_usage.removed_fields(FIXED), [])

    def test_exit_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            def report(name, text):
                path = Path(directory, name)
                path.write_text(text, encoding='utf-8')
                return path

            self.assertEqual(check_r8_usage.main(report('bcd6e7d.txt', BCD6E7D)), 1)
            self.assertEqual(check_r8_usage.main(report('fixed.txt', FIXED)), 0)
            # No report means R8 never ran, and a report without members
            # means its format changed: neither may pass silently.
            self.assertEqual(check_r8_usage.main(Path(directory, 'missing.txt')), 1)
            classes_only = report('classes.txt', 'dev.mediapipe.flutter.audio.R\n')
            self.assertEqual(check_r8_usage.main(classes_only), 1)


if __name__ == '__main__':
    unittest.main()
