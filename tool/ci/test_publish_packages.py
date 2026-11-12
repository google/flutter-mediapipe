"""Unit tests for the release publisher:
python3 -B -m unittest tool/ci/test_publish_packages.py
"""
import functools
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parent))
import publish_packages  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
WORKFLOW = REPO / '.github/workflows/release.yaml'


class PublishPackagesTest(unittest.TestCase):
    def test_resolve_packages_keeps_core_first(self):
        # Even if a family is named before core, mediapipe-core comes first.
        resolved = publish_packages.resolve_packages(
            ['mediapipe_vision,mediapipe_core', 'mediapipe-task-audio'])
        self.assertEqual(resolved, [
            'mediapipe-core',
            'mediapipe-task-audio',
            'mediapipe-task-vision',
        ])

    def test_resolve_packages_all_returns_every_package_core_first(self):
        resolved = publish_packages.resolve_packages(['all'])
        self.assertEqual(resolved[0], 'mediapipe-core')
        self.assertEqual(len(resolved), 6)

    def test_resolve_packages_rejects_unknown_package(self):
        with self.assertRaises(SystemExit):
            publish_packages.resolve_packages(['mediapipe_unknown'])

    def test_target_version_from_tag_and_explicit_input(self):
        self.assertEqual(
            publish_packages.target_version_from('refs/tags/v0.2.0'),
            '0.2.0')
        self.assertEqual(
            publish_packages.target_version_from('refs/heads/main', 'v0.3.1'),
            '0.3.1')
        self.assertIsNone(
            publish_packages.target_version_from('refs/heads/main', ''))
        with self.assertRaises(SystemExit):
            publish_packages.target_version_from('refs/tags/0.2.0')
        with self.assertRaises(SystemExit):
            publish_packages.target_version_from('refs/heads/main', 'not-a-semver')

    def test_prepare_release_version_bumps_pubspecs_changelogs_and_readmes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            packages = root / 'packages'
            folders = ['mediapipe-core', 'mediapipe-task-vision']
            (packages / 'mediapipe-core').mkdir(parents=True)
            (packages / 'mediapipe-task-vision').mkdir(parents=True)
            (packages / 'mediapipe-core/pubspec.yaml').write_text(
                'name: mediapipe_core\nversion: 0.1.0\n', encoding='utf-8')
            (packages / 'mediapipe-core/CHANGELOG.md').write_text(
                '## 0.1.0\n\nInitial release.\n', encoding='utf-8')
            (packages / 'mediapipe-task-vision/pubspec.yaml').write_text(
                'name: mediapipe_vision\nversion: 0.1.0\ndependencies:\n'
                '  mediapipe_core: ^0.1.0\n', encoding='utf-8')
            (packages / 'mediapipe-task-vision/CHANGELOG.md').write_text(
                '## 0.1.0\n\nInitial release.\n', encoding='utf-8')
            (packages / 'mediapipe-task-vision/README.md').write_text(
                'dependencies:\n  mediapipe_vision: ^0.1.0\n', encoding='utf-8')
            (root / 'README.md').write_text(
                'dependencies:\n  mediapipe_vision: ^0.1.0\n', encoding='utf-8')

            changed = publish_packages.prepare_release_version(
                '0.2.0', release_notes='- Added new feature.',
                repo_root=root, packages_dir=packages, folders=folders)
            self.assertTrue(changed)
            self.assertIn(
                'version: 0.2.0',
                (packages / 'mediapipe-core/pubspec.yaml').read_text(encoding='utf-8'))
            vision_pubspec = (packages / 'mediapipe-task-vision/pubspec.yaml').read_text(
                encoding='utf-8')
            self.assertIn('version: 0.2.0', vision_pubspec)
            self.assertIn('mediapipe_core: ^0.2.0', vision_pubspec)
            vision_changelog = (packages / 'mediapipe-task-vision/CHANGELOG.md').read_text(
                encoding='utf-8')
            self.assertTrue(vision_changelog.startswith(
                '## 0.2.0\n\n- Added new feature.\n\n## 0.1.0'))
            self.assertIn(
                'mediapipe_vision: ^0.2.0',
                (packages / 'mediapipe-task-vision/README.md').read_text(encoding='utf-8'))
            self.assertIn(
                'mediapipe_vision: ^0.2.0',
                (root / 'README.md').read_text(encoding='utf-8'))

            # Running a second time with the same target version is a no-op.
            self.assertFalse(publish_packages.prepare_release_version(
                '0.2.0', release_notes='- Added new feature.',
                repo_root=root, packages_dir=packages, folders=folders))

    def test_verify_versions_and_tag_accepts_matching_tag(self):
        _, current = publish_packages.read_pubspec_versions()
        version = publish_packages.verify_versions_and_tag(
            f'refs/tags/v{current}', dry_run=False)
        self.assertEqual(version, current)

    def test_verify_versions_and_tag_rejects_mismatched_tag_even_in_dry_run(self):
        with self.assertRaises(SystemExit):
            publish_packages.verify_versions_and_tag(
                'refs/tags/v99.99.99', dry_run=True)

    def test_verify_versions_and_tag_rejects_branch_ref_without_explicit_version(self):
        _, current = publish_packages.read_pubspec_versions()
        with self.assertRaises(SystemExit):
            publish_packages.verify_versions_and_tag(
                'refs/heads/main', dry_run=False)
        self.assertEqual(
            publish_packages.verify_versions_and_tag(
                'refs/heads/main', dry_run=False, explicit_version=current),
            current)
        self.assertEqual(
            publish_packages.verify_versions_and_tag('refs/heads/main', dry_run=True),
            current)

    def test_commit_and_tag_release_commits_and_pushes_tag(self):
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            if cmd[:2] == ['git', 'status']:
                return subprocess.CompletedProcess(cmd, 0, ' M packages/mediapipe-core/pubspec.yaml\n', '')
            return subprocess.CompletedProcess(cmd, 0, '', '')

        with mock.patch.object(publish_packages.subprocess, 'run', side_effect=fake_run):
            publish_packages.commit_and_tag_release('0.2.0', target_branch='main')

        self.assertIn(['git', 'commit', '-am', 'chore(release): v0.2.0'], calls)
        self.assertIn(['git', 'push', 'origin', 'HEAD:refs/heads/main'], calls)
        self.assertIn(['git', 'tag', '-f', 'v0.2.0', 'HEAD'], calls)
        self.assertIn(['git', 'push', '--force', 'origin', 'refs/tags/v0.2.0'], calls)

    def test_fetch_oidc_token_requests_pub_dev_audience(self):
        response_bytes = json.dumps({'value': 'oidc-jwt-token'}).encode('utf-8')
        fake_response = mock.MagicMock()
        fake_response.__enter__.return_value.read.return_value = response_bytes
        env = {
            'ACTIONS_ID_TOKEN_REQUEST_URL': 'https://token.actions.example/id?foo=1',
            'ACTIONS_ID_TOKEN_REQUEST_TOKEN': 'req-secret',
            'GITHUB_ACTIONS': 'true',
        }
        with mock.patch('urllib.request.urlopen', return_value=fake_response) as urlopen:
            with mock.patch('sys.stdout', new_callable=io.StringIO) as stdout:
                token = publish_packages.fetch_oidc_token(environ=env)
        self.assertEqual(token, 'oidc-jwt-token')
        request = urlopen.call_args[0][0]
        self.assertEqual(
            request.full_url,
            'https://token.actions.example/id?foo=1&audience=https%3A%2F%2Fpub.dev')
        self.assertEqual(request.get_header('Authorization'), 'bearer req-secret')
        self.assertIn('::add-mask::oidc-jwt-token', stdout.getvalue())

    def test_is_version_published_handles_existing_and_404(self):
        payload = json.dumps({'versions': [{'version': '0.0.1'}, {'version': '0.1.0'}]}).encode()
        fake_response = mock.MagicMock()
        fake_response.__enter__.return_value.read.return_value = payload
        with mock.patch('urllib.request.urlopen', return_value=fake_response):
            self.assertTrue(publish_packages.is_version_published('mediapipe_core', '0.1.0'))
            self.assertFalse(publish_packages.is_version_published('mediapipe_core', '0.2.0'))

        not_found = urllib.error.HTTPError(
            url='https://pub.dev/api/packages/mediapipe_vision',
            code=404, msg='Not Found', hdrs=None, fp=None)
        with mock.patch('urllib.request.urlopen', side_effect=not_found):
            self.assertFalse(publish_packages.is_version_published('mediapipe_vision', '0.1.0'))

    def test_run_publish_publishes_core_then_waits_before_families(self):
        events = []

        def fake_prepare(folder, root):
            (root / folder).mkdir(parents=True, exist_ok=True)

        def fake_validate(root, selected):
            events.append(('validate', list(selected)))

        def fake_commit_and_tag(version, target_branch='main'):
            events.append(('commit_and_tag', version, target_branch))

        def fake_is_published(name, version, pub_host=publish_packages.PUB_HOST):
            # Simulate mediapipe_audio already published on a prior attempt,
            # and mediapipe_core becoming visible once wait_for_version polls.
            if name == 'mediapipe_audio':
                return True
            if name == 'mediapipe_core':
                return ('publish', 'mediapipe-core') in events
            return False

        def fake_run(cmd, **kwargs):
            events.append(('token_add', cmd[-1]))
            return subprocess.CompletedProcess(cmd, 0, '', '')

        def fake_publish(root, folder, token):
            events.append(('publish', folder))

        _, current = publish_packages.read_pubspec_versions()
        selected = ['mediapipe-core', 'mediapipe-task-audio', 'mediapipe-task-vision']
        with tempfile.TemporaryDirectory() as tmp:
            # The release bump rewrites the files it reads, so it runs on a
            # copy of every package's version files, never on the checkout.
            copy = Path(tmp)
            for folder in publish_packages.package_folders():
                (copy / 'packages' / folder).mkdir(parents=True)
                for name in ('pubspec.yaml', 'CHANGELOG.md', 'README.md'):
                    source = publish_packages.PACKAGES / folder / name
                    if source.is_file():
                        shutil.copy(source, copy / 'packages' / folder / name)
            bump = functools.partial(publish_packages.prepare_release_version,
                                     repo_root=copy, packages_dir=copy / 'packages')
            verify = functools.partial(publish_packages.verify_versions_and_tag,
                                       packages_dir=copy / 'packages')
            with mock.patch.object(publish_packages, 'prepare_release_version', side_effect=bump), \
                    mock.patch.object(publish_packages, 'verify_versions_and_tag', side_effect=verify), \
                    mock.patch.object(publish_packages, 'prepare', side_effect=fake_prepare), \
                    mock.patch.object(publish_packages, 'validate_staged', side_effect=fake_validate), \
                    mock.patch.object(publish_packages, 'commit_and_tag_release', side_effect=fake_commit_and_tag), \
                    mock.patch.object(publish_packages, 'is_version_published', side_effect=fake_is_published), \
                    mock.patch.object(publish_packages, 'fetch_oidc_token', return_value='jwt'), \
                    mock.patch.object(publish_packages.subprocess, 'run', side_effect=fake_run), \
                    mock.patch.object(publish_packages, 'publish_package', side_effect=fake_publish):
                publish_packages.run_publish(selected, f'refs/tags/v{current}', dry_run=False)

        self.assertEqual(events, [
            ('validate', ['mediapipe-core', 'mediapipe-task-audio', 'mediapipe-task-vision']),
            ('commit_and_tag', current, 'main'),
            ('token_add', 'PUB_TOKEN'),
            ('publish', 'mediapipe-core'),
            ('publish', 'mediapipe-task-vision'),
        ])

    def test_release_workflow_pins_actions_and_gates_publish(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        self.assertIn('id-token: write', text)
        self.assertIn('contents: write', text)
        self.assertIn('needs: [validate, archives]', text)
        self.assertIn('tags:', text)
        self.assertIn('workflow_dispatch:', text)
        self.assertNotRegex(text, r'(?m)^\s*branches:')
        self.assertNotRegex(text, r'(?m)^\s*pull_request:')
        for ref in re.findall(r'uses:\s*(\S+)', text):
            if not ref.startswith('./'):
                self.assertRegex(ref, r'^[^@]+@[0-9a-f]{40}$')


if __name__ == '__main__':
    unittest.main()
