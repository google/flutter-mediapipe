"""Writes the gallery's video clips, samples/scene.mp4 and samples/rotated.mp4,
from test photos.

scene.mp4 is the video file mode's clip: one scene of three seconds at 30
frames a second, a full-body pose, a portrait and a raised hand, each drifting
slowly so tracking has something to follow. H.264 (main profile, 4:2:0) plays
on every platform and browser the gallery runs on, and a keyframe every ten
frames keeps a browser's frame-by-frame seeking cheap.

rotated.mp4 checks that a file's rotation reaches the task: ten frames of the
portrait stored a quarter turn counter-clockwise, tagged to be shown a quarter
turn clockwise, as a phone records portrait video. Upright, the face is found;
on its side or upside down it is not.

Needs ffmpeg with libx264 on the PATH.

Run from the repository root: python3 -B gallery/tool/make_sample_clip.py
"""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / 'packages/mediapipe-task-vision/test/fixtures'
OUTPUT = REPO / 'gallery/samples/scene.mp4'
ROTATED = REPO / 'gallery/samples/rotated.mp4'
SOURCES = [
    FIXTURES / 'landmark_tasks/pose.jpg',
    FIXTURES / 'face_detection/landmark-ex1.jpg',
    FIXTURES / 'landmark_tasks/thumb_up.jpg',
]

# Each photo's size in the 960x540 scene and its drift: x and y offsets that
# follow one slow loop over the clip's three seconds.
SCENE = (
    'color=c=0x20262b:s=960x540:r=30:d=3[bg];'
    '[0:v]scale=600:400,setsar=1[pose];'
    '[1:v]scale=330:220,setsar=1[face];'
    '[2:v]scale=200:213,setsar=1[hand];'
    "[bg][pose]overlay=x='10+8*sin(2*PI*t/3)':y='70+6*cos(2*PI*t/3)'"
    ':shortest=1[a];'
    "[a][face]overlay=x='620+6*cos(2*PI*t/3)':y='20+5*sin(2*PI*t/3)'[b];"
    "[b][hand]overlay=x='680+8*sin(2*PI*t/3)':y='290+6*cos(2*PI*t/3)'[out]"
)


# No encoder name or date in the files, so a rerun writes the same bytes.
EXACT = ['-map_metadata', '-1', '-fflags', '+bitexact', '-flags:v', '+bitexact']


def describe(path):
    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_frames',
        '-show_entries', 'stream=width,height,nb_read_frames,r_frame_rate:'
        'stream_side_data=rotation',
        '-of', 'json', str(path)]))['streams'][0]
    rotation = [d.get('rotation') for d in probe.get('side_data_list', [])]
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f'Wrote {path.relative_to(REPO)}: {probe["width"]}x{probe["height"]}, '
          f'{probe["nb_read_frames"]} frames at {probe["r_frame_rate"]} fps, '
          f'rotation {rotation}, {path.stat().st_size} bytes, SHA-256 {digest}')


def main():
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y']
    for source in SOURCES:
        command += ['-loop', '1', '-i', str(source)]
    command += [
        '-filter_complex', SCENE, '-map', '[out]', '-t', '3', '-r', '30',
        '-c:v', 'libx264', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
        '-g', '10', '-crf', '23', '-movflags', '+faststart', '-an',
        *EXACT, str(OUTPUT),
    ]
    subprocess.run(command, check=True)
    describe(OUTPUT)
    # transpose=2 turns the pixels a quarter turn counter-clockwise; ffmpeg's
    # display rotation counts counter-clockwise, so -90 shows them a quarter
    # turn clockwise, upright again.
    subprocess.run([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
        # Without autorotate off, ffmpeg would turn the pixels back itself.
        '-noautorotate', '-display_rotation:v:0', '-90',
        '-loop', '1', '-i', str(SOURCES[1]),
        '-vf', 'scale=320:214,transpose=2,setsar=1', '-t', '1', '-r', '10',
        '-c:v', 'libx264', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
        '-g', '10', '-crf', '23', '-movflags', '+faststart', '-an',
        *EXACT, str(ROTATED),
    ], check=True)
    describe(ROTATED)


if __name__ == '__main__':
    main()
