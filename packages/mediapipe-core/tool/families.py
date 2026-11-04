"""The repository's packages, found on disk so that no tool lists them.

Core is `packages/mediapipe-core`, and every task family is a
`packages/mediapipe-task-<family>` folder with a pubspec. A new family
reaches every tool that reads this; `tool/check_repository.py` checks the
few lists that must stay hand-written.
"""
from pathlib import Path
import re

PACKAGES = Path(__file__).resolve().parents[2]
CORE = 'mediapipe-core'
TASK_PREFIX = 'mediapipe-task-'


def task_families():
    """Each task family's short name and folder under `packages/`, sorted:
    `{'audio': 'mediapipe-task-audio', ...}`."""
    return {path.name[len(TASK_PREFIX):]: path.name
            for path in sorted(PACKAGES.glob(TASK_PREFIX + '*'))
            if (path / 'pubspec.yaml').is_file()}


def package_folders():
    """Core's folder, then every task family's."""
    return [CORE, *task_families().values()]


def package_name(folder):
    """The pubspec name of `packages/<folder>`, such as `mediapipe_vision`."""
    text = (PACKAGES / folder / 'pubspec.yaml').read_text(encoding='utf-8')
    return re.search(r'^name: (\S+)$', text, re.M).group(1)
