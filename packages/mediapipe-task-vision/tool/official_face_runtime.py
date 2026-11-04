"""The official runtime the independent reference generators record: Google's
wheel pinned for this host in core's `referenceWheels`, which the Dart tests
check every receipt against. Google's wheels name no source revision.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402

_HOST = host_runtime()
LIBRARY_NAME = _HOST['library']
LIBRARY_SHA256 = _HOST['library_sha256']
VERSION = _HOST['version']
SOURCE_REVISION = None
RUNTIME = 'mediapipe==' + VERSION
