"""Capture Google's Text to Speech outputs for Kyutai's PocketTTS English.

Runs the official Python API from the checksum-pinned speech wheel for this
host, as generate_speech_reference.py does for Phonon, on
`AudioModels.pocketTtsEn`: its voices, an utterance in the default voice and
in a second one, the same utterance at speaking rate 1.5, and a stream. Never
derive expected values from the Dart implementation.

Google's 1.2.2 runtime does not give every task it creates the same answer on
every host: on GitHub's Linux runners with AMD EPYC 9V45 processors, each new
task times the fox's words on one of two 15 ms grids (brown ending at 0.96 s
or 0.975 s), about half the time each, in its Python on the wheel's library or
on the family library the package bundles, and in the package alike, while
every synthesis on one task keeps that task's grid. So where the first tasks'
samples differ, each case keeps every distinct answer from CREATES tasks, the
first as before and the others as its `alternatives`, and the tests accept
the package's answer only when it is one of Google's.
"""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import sys

from generate_audio_reference import FIXTURES, HOST_NAMES, PACKAGE
from generate_speech_reference import ENVELOPE_SECONDS, STREAM_TEXT, audio

sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402
from model_pins import model_sha256  # noqa: E402
from tool_helpers import reference_json  # noqa: E402

MODEL = 'pocket_tts_en_int8.litertlm'

# Each utterance: the text, the voice id and the locale (None for the
# options' defaults, which name alba).
UTTERANCES = {
    'fox': ('The quick brown fox jumps over the lazy dog.', None, None),
    'marius': ('Good morning, how are you today?', 'marius', None),
}
# Spoken by a task created with speaking_rate 1.5.
FAST_UTTERANCE = UTTERANCES['fox'][0]
# Tasks created for each case where the first SETTLE disagree sample for
# sample, as they never do on macOS or Windows. With two answers, each from at
# least a third of tasks, the package's task gives one that 32 of Google's
# missed less than once in a million runs of a case.
SETTLE, CREATES = 4, 32
# speech_test.dart's _levelDelta: answers within it of each other are one.
LEVEL_DELTA = 2e-3


def same_answer(a, b):
    """Whether two synthesized results are one answer for the tests: the same
    length, rate and words, and every level within LEVEL_DELTA."""
    return ((a['samples'], a['sample_rate_hz'], a['words']) ==
            (b['samples'], b['sample_rate_hz'], b['words']) and
            len(a['envelope']) == len(b['envelope']) and
            max(abs(x - y) for x, y in zip([a['peak'], *a['envelope']],
                                            [b['peak'], *b['envelope']])) <= LEVEL_DELTA)


def same_chunks(a, b):
    return len(a) == len(b) and all(
        (x['chunk_index'], x['is_final']) == (y['chunk_index'], y['is_final']) and
        same_answer(x, y) for x, y in zip(a, b))


def answers(runs, same):
    """The distinct answers in runs, in order."""
    kept = []
    for run in runs:
        if not any(same(run, answer) for answer in kept):
            kept.append(run)
    return kept


def sample(run):
    """run() on SETTLE new tasks, then on CREATES in all if their samples
    differ, with each run's samples' digest dropped."""
    runs = [run() for _ in range(SETTLE)]
    if len({digest for digest, _ in runs}) > 1:
        runs += [run() for _ in range(CREATES - SETTLE)]
    print(len(runs), 'tasks', flush=True)
    return [result for _, result in runs]


def tts_reference(model):
    import mediapipe as mp
    from mediapipe.tasks.python.audio import text_to_speech

    def create(**options):
        return text_to_speech.TextToSpeech.create_from_options(
            text_to_speech.TextToSpeechOptions(
                base_options=mp.tasks.BaseOptions(model_asset_path=str(model)), **options))

    def default_voice():
        samples = hashlib.sha256()

        def heard(result, text):
            samples.update(result.samples.tobytes())
            return audio(result, text)

        with create() as task:
            voices = [{'voice_id': v.voice_id, 'display_name': v.display_name,
                       'locale': v.locale, 'sample_rate_hz': v.sample_rate_hz,
                       'is_downloaded': v.is_downloaded} for v in task.list_voices()]
            utterances = {name: heard(task.synthesize(text, voice_id=voice, locale=locale), text)
                          for name, (text, voice, locale) in UTTERANCES.items()}
            chunks = [{'chunk_index': chunk.chunk_index, 'is_final': chunk.is_final,
                       **heard(chunk, STREAM_TEXT)}
                      for chunk in task.synthesize_stream(STREAM_TEXT)]
        return samples.hexdigest(), {'voices': voices, 'utterances': utterances,
                                     'chunks': chunks}

    def fast_rate():
        with create(speaking_rate=1.5) as task:
            result = task.synthesize(FAST_UTTERANCE)
            return hashlib.sha256(result.samples.tobytes()).hexdigest(), audio(
                result, FAST_UTTERANCE)

    def with_alternatives(found):
        return {**found[0], **({'alternatives': found[1:]} if len(found) > 1 else {})}

    runs = sample(default_voice)
    voices = runs[0]['voices']
    assert all(run['voices'] == voices for run in runs)
    utterances = {}
    for name, (text, voice, locale) in UTTERANCES.items():
        found = answers([run['utterances'][name] for run in runs], same_answer)
        utterances[name] = {'text': text, 'voice_id': voice, 'locale': locale,
                            **with_alternatives(found)}
        print(name, found[0]['samples'], 'samples,', len(found), 'answers', flush=True)
    chunks = answers([run['chunks'] for run in runs], same_chunks)
    print('stream', len(chunks[0]), 'chunks,', len(chunks), 'answers', flush=True)
    found = answers(sample(fast_rate), same_answer)
    fast = {'text': FAST_UTTERANCE, 'speaking_rate': 1.5, **with_alternatives(found)}
    print('fast', len(found), 'answers', flush=True)
    return {'voices': voices, 'utterances': utterances, 'fast': fast,
            'stream': {'text': STREAM_TEXT, 'chunks': chunks[0],
                       **({'alternatives': chunks[1:]} if len(chunks) > 1 else {})}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path, help='Extracted official wheel')
    parser.add_argument('--output', type=Path,
                        default=FIXTURES / 'official_pocket_tts_reference.json')
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp

    runtime = host_runtime('releaseReferenceWheels')
    name, version = HOST_NAMES[platform.system()], runtime['version']
    assert mp.__version__ == version, mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    model = PACKAGE / 'models' / MODEL
    models = {MODEL: model_sha256(MODEL)}
    assert hashlib.sha256(model.read_bytes()).hexdigest() == models[MODEL], MODEL

    report = {
        'runtime': f'mediapipe=={version}',
        'source': f'official Python TextToSpeech, {name} wheel, CPU',
        'models': models,
        'envelope': f'RMS of each {ENVELOPE_SECONDS:g} s window, the last one partial',
        'word_offsets': 'UTF-8 byte offsets in the text, as Google reports them',
        'cases': {'text_to_speech': tts_reference(model)},
    }
    args.output.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(reference_json(report, ensure_ascii=False) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
