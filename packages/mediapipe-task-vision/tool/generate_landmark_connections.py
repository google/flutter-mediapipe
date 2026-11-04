"""Copy Google's face, hand and pose drawing edges into Dart, indices unchanged.

Overlays never hand-copy an edge list: this writes the three tables from the
official Python API, eight or so pairs per line. Run it in the pinned official
environment:

    build/ci-tmp/gpu-reference-env/bin/python \\
        packages/mediapipe-task-vision/tool/generate_landmark_connections.py
"""
from pathlib import Path
import shutil
import subprocess
import sys

import mediapipe as mp
from mediapipe.tasks.python.vision.face_landmarker import FaceLandmarksConnections
from mediapipe.tasks.python.vision.hand_landmarker import HandLandmarksConnections
from mediapipe.tasks.python.vision.pose_landmarker import PoseLandmarksConnections

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'mediapipe-core/tool'))
from tool_helpers import dart_rows  # noqa: E402

VERSION = '1.0.0'

# Each file's classes: the Dart name, Google's class, what it draws, and the
# Dart member for each of Google's tables.
FILES = {
    'face_landmarks_connections.dart': [
        ('FaceLandmarksConnections', FaceLandmarksConnections, 'facial', {
            'tessellation': 'FACE_LANDMARKS_TESSELATION',
            'contours': 'FACE_LANDMARKS_CONTOURS',
            'leftIris': 'FACE_LANDMARKS_LEFT_IRIS',
            'rightIris': 'FACE_LANDMARKS_RIGHT_IRIS',
        }),
    ],
    'landmarks_connections.dart': [
        ('HandLandmarksConnections', HandLandmarksConnections, 'hand', {
            'all': 'HAND_CONNECTIONS',
            'palm': 'HAND_PALM_CONNECTIONS',
            'thumb': 'HAND_THUMB_CONNECTIONS',
            'indexFinger': 'HAND_INDEX_FINGER_CONNECTIONS',
            'middleFinger': 'HAND_MIDDLE_FINGER_CONNECTIONS',
            'ringFinger': 'HAND_RING_FINGER_CONNECTIONS',
            'pinkyFinger': 'HAND_PINKY_FINGER_CONNECTIONS',
        }),
        ('PoseLandmarksConnections', PoseLandmarksConnections, 'pose', {
            'all': 'POSE_LANDMARKS',
        }),
    ],
}


def main():
    assert mp.__version__ == VERSION, mp.__version__
    for name, classes in FILES.items():
        lines = [
            '// Copyright 2023 The MediaPipe Authors.',
            '// Licensed under the Apache License, Version 2.0.',
            f"// Generated from MediaPipe v{VERSION}'s Python API.",
            '// Regenerate: tool/generate_landmark_connections.py',
            '',
            '// dart format off',
        ]
        for dart_name, source, what, members in classes:
            lines += [
                '',
                f"/// Google's `{dart_name}`: the {what} drawing edges, in the",
                '/// original index order.',
                f'abstract final class {dart_name} {{',
            ]
            for member, attribute in members.items():
                edges = getattr(source, attribute)
                lines += [
                    f'  /// Official {attribute} ({len(edges)} edges).',
                    f'  static const List<(int, int)> {member} = [',
                    *dart_rows([f'({edge.start}, {edge.end})' for edge in edges], 4),
                    '  ];',
                ]
            lines.append('}')
        lines += ['// dart format on', '']
        output = ROOT / 'lib/src/types' / name
        output.write_text('\n'.join(lines))
        # Keep the checked-in file in the repository's format, so regenerating
        # it never fails `make check_format`.
        subprocess.run([shutil.which('dart') or 'dart', 'format', str(output)],
                       check=True, cwd=ROOT)
        print(f'Wrote {output}')


if __name__ == '__main__':
    main()
