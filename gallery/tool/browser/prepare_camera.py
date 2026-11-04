"""Generate subject/blank/subject browser-webcam input from existing licensed fixtures.

With no argument, writes the face fixture (build/ci-tmp/web-camera.y4m) and
the hand fixture (build/ci-tmp/web-camera-hand.y4m) that
test_browser.mjs --task=face|hand streams.
"""
from pathlib import Path
import subprocess
import sys

repo = Path(__file__).resolve().parents[3]
fixtures = repo / 'packages/mediapipe-task-vision/test/fixtures'
# One subject each, so the alignment oracle has an unambiguous match.
SUBJECTS = {
    'web-camera.y4m': fixtures / 'face_detection/landmark-ex1.jpg',
    'web-camera-hand.y4m': fixtures / 'landmark_tasks/thumb_up.jpg',
}
filter_chain = (
    '[0:v]scale=640:480:force_original_aspect_ratio=decrease,'
    'pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p,setsar=1[f0];'
    '[2:v]scale=640:480:force_original_aspect_ratio=decrease,'
    'pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p,setsar=1[f2];'
    '[f0][1:v][f2]concat=n=3:v=1:a=0[out]'
)
directory = Path(sys.argv[1]) if len(sys.argv) > 1 else repo / 'build/ci-tmp'
directory.mkdir(parents=True, exist_ok=True)
for name, subject in SUBJECTS.items():
    output = directory / name
    subprocess.run([
        'ffmpeg', '-n', '-hide_banner', '-loglevel', 'error',
        '-loop', '1', '-framerate', '10', '-t', '3', '-i', str(subject),
        '-f', 'lavfi', '-t', '3', '-i', 'color=black:s=640x480:r=10',
        # Keep the final subject visible long enough for resize, delegate,
        # and navigation checks while one camera stream stays open. Chrome's
        # file-backed fake camera stops producing frames at end of file.
        '-loop', '1', '-framerate', '10', '-t', '54', '-i', str(subject),
        '-filter_complex', filter_chain, '-map', '[out]',
        '-r', '10', '-pix_fmt', 'yuv420p', str(output),
    ], check=True)
    with output.open('rb') as fixture:
        header = fixture.readline().decode('ascii').strip()
    if not all(field in header.split() for field in ('W640', 'H480', 'F10:1', 'C420jpeg')):
        raise RuntimeError(f'Unsupported Chrome Y4M camera header: {header}')
    print(f'Prepared Chrome webcam fixture {name}: {header}; {output.stat().st_size} bytes')
