"""Unit tests for the release publisher:
python3 -B -m unittest tool/ci/test_publish_packages.py
"""
import io
import json
from pathlib import Path
import re
import subprocess
import sys
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

    def test_verify_versions_and_tag_accepts_matching_tag(self):
        version = publish_packages.verify_versions_and_tag(
            'refs/tags/v0.1.0', dry_run=False)
        self.assertEqual(version, '0.1.0')

    def test_verify_versions_and_tag_rejects_mismatched_tag_even_in_dry_run(self):
        with self.assertRaises(SystemExit):
            publish_packages.verify_versions_and_tag(
                'refs/tags/v0.2.0', dry_run=True)

    def test_verify_versions_and_tag_rejects_branch_ref_when_publishing(self):
        with self.assertRaises(SystemExit):
            publish_packages.verify_versions_and_tag(
                'refs/heads/main', dry_run=False)
        # Dry run on a branch ref is allowed.
        self.assertEqual(
            publish_packages.verify_versions_and_tag('refs/heads/main', dry_run=True),
            '0.1.0')

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

        selected = ['mediapipe-core', 'mediapipe-task-audio', 'mediapipe-task-vision']
        with mock.patch.object(publish_packages, 'prepare', side_effect=fake_prepare), \
                mock.patch.object(publish_packages, 'validate_staged', side_effect=fake_validate), \
                mock.patch.object(publish_packages, 'is_version_published', side_effect=fake_is_published), \
                mock.patch.object(publish_packages, 'fetch_oidc_token', return_value='jwt'), \
                mock.patch.object(publish_packages.subprocess, 'run', side_effect=fake_run), \
                mock.patch.object(publish_packages, 'publish_package', side_effect=fake_publish):
            publish_packages.run_publish(selected, 'refs/tags/v0.1.0', dry_run=False)

        self.assertEqual(events, [
            ('validate', ['mediapipe-core', 'mediapipe-task-audio', 'mediapipe-task-vision']),
            ('token_add', 'PUB_TOKEN'),
            ('publish', 'mediapipe-core'),
            ('publish', 'mediapipe-task-vision'),
        ])

    def test_release_workflow_pins_actions_and_gates_publish(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        self.assertIn('id-token: write', text)
        self.assertIn('needs: [validate, archives]', text)
        for ref in re.findall(r'uses:\s*(\S+)', text):
            if not ref.startswith('./'):
                self.assertRegex(ref, r'^[^@]+@[0-9a-f]{40}$')


if __name__ == '__main__':
    unittest.main()
