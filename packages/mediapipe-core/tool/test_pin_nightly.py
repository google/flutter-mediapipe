"""Unit tests for the nightly pin, offline:
python3 -B -m unittest packages/mediapipe-core/tool/test_pin_nightly.py"""
import email.message
import errno
import http.client
import io
import json
from pathlib import Path
import re
import socket
import ssl
import sys
import tempfile
import types
import unittest
from unittest import mock
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pin_nightly  # noqa: E402


def pinned_digests(source):
    """`{path: (sha256, size)}` as `familyRuntimes` pins them."""
    return {path: (sha256, int(size)) for path, sha256, size in re.findall(
        r"FamilyRuntime\(\s*'([^']+)',\s*'([0-9a-f]{64})',\s*(\d+),\s*\)", source)}


class Bucket:
    """Stands in for Fetcher: `{stamp: version}`, None for a folder with no
    BUILD_INFO."""

    def __init__(self, builds):
        self.builds = builds

    def json(self, _):
        return {'prefixes': [f'{pin_nightly.PREFIX}{name}/' for name in [*self.builds, '1.2.1']]}

    def text(self, url):
        version = self.builds[url.split('/')[-2]]
        return version and f'build_date=x\nmediapipe_version={version}\n'


class VersionStopTest(unittest.TestCase):
    def since(self, builds, stamp='20261106', version='1.2.0'):
        return pin_nightly.version_stop_since(Bucket(builds), stamp, version, '20261018')

    def test_starts_at_the_first_build_after_the_pinned_version(self):
        self.assertEqual(self.since({'20261029': '1.2.0', '20261030': '1.2.1',
                                     '20261105': '1.2.2', '20261106': '1.2.2'}), '20261030')

    def test_only_the_run_ending_at_the_picked_build_counts(self):
        self.assertEqual(self.since({'20261001': '1.2.2', '20261002': '1.2.0',
                                     '20261105': '1.2.2', '20261106': '1.2.2'}), '20261105')

    def test_a_newer_build_that_was_not_picked_is_left_out(self):
        self.assertEqual(self.since({'20261104': '1.2.0', '20261105': '1.2.2',
                                     '20261106': '1.2.2', '20261107': '1.2.0'}), '20261105')

    def test_a_folder_with_no_build_info_is_passed_over(self):
        self.assertEqual(self.since({'20261029': '1.2.0', '20261030': '1.2.1',
                                     '20261031': None, '20261106': '1.2.2'}), '20261030')
        self.assertEqual(self.since({'20261029': '1.2.0', '20261030': None,
                                     '20261031': '1.2.1', '20261106': '1.2.2'}), '20261031')

    def test_with_the_pinned_version_pruned_it_starts_at_the_pinned_build(self):
        self.assertEqual(self.since({'20261030': '1.2.1', '20261106': '1.2.2'}), '20261018')

    def stop_in_report(self, **since):
        """main's version_stop, its failure's text alongside."""
        old = pin_nightly.current_pins()
        info = f"build_date=20261106\nmediapipe_version={old['version']}.new\n"
        archive = types.SimpleNamespace(url='u', generation='1', size=1)
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory, 'report.json')
            argv = ['pin_nightly.py', '--nightly', 'newest', '--report', str(report)]
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch.object(pin_nightly, 'pick_build',
                                      return_value=('20261106', info, archive)), \
                    mock.patch.object(pin_nightly, 'version_stop_since', **since), \
                    mock.patch('sys.stdout', io.StringIO()), \
                    self.assertRaises(SystemExit) as caught:
                pin_nightly.main()
            stop = json.loads(report.read_text(encoding='utf-8'))['version_stop']
        self.assertEqual((stop['version'], stop['pinned']),
                         (f"{old['version']}.new", old['version']))
        return stop['since'], str(caught.exception)

    def test_the_report_dates_the_stop_and_the_exit_stays_nonzero(self):
        since, failure = self.stop_in_report(return_value='20261030')
        self.assertEqual(since, '20261030')
        self.assertIn('move it by hand', failure)

    def test_a_network_failure_leaves_the_date_unknown(self):
        for error in (urllib.error.URLError(socket.gaierror(-2, 'x')), TimeoutError(),
                      ConnectionResetError(),
                      urllib.error.HTTPError('u', 503, 'down', None, None),
                      http.client.IncompleteRead(b'')):
            since, failure = self.stop_in_report(side_effect=error)
            self.assertIsNone(since, error)
            self.assertIn('move it by hand', failure)


class ChoosingABuildTest(unittest.TestCase):
    """main up to the chosen build, on the real Fetcher, with `urlopen` replaced."""
    STAMPS = ('20261105', '20261106')

    @classmethod
    def setUpClass(cls):
        cls.pins = pin_nightly.current_pins()
        cls.domains = ' '.join(pin_nightly.families(cls.pins['paths']))

    def answer(self, request, timeout):
        """Google's bucket, or what `self.broken` gives for a URL with its key in."""
        url = request.full_url
        self.urls.append(url)
        for part, broken in self.broken.items():
            if part in url:
                if isinstance(broken, Exception):
                    raise broken
                return broken if isinstance(broken, Body) else Body(broken)
        if 'delimiter' in url:
            return Body(json.dumps({'prefixes': [f'{pin_nightly.PREFIX}{stamp}/'
                                                 for stamp in self.STAMPS]}).encode())
        if url.startswith(pin_nightly.LISTING):
            stamp = re.search(r'\d{8}', url).group()
            return Body(json.dumps({'items': [
                {'name': f'{pin_nightly.PREFIX}{stamp}/BUILD_INFO'},
                {'name': f'{pin_nightly.PREFIX}{stamp}/mediapipe_tasks_c_{stamp}.zip'}]}).encode())
        stamp = url.split('/')[-2]
        return Body(f"build_date={stamp}\nmediapipe_version={self.pins['version']}\n"
                    f'domains={self.domains}\n'.encode())

    def run_main(self, **broken):
        """The failure main raises and the report it wrote, None if it wrote none."""
        self.broken, self.urls = broken, []
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory, 'report.json')
            argv = ['pin_nightly.py', '--nightly', self.nightly, '--report', str(report)]
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch.object(pin_nightly.urllib.request, 'urlopen', self.answer), \
                    mock.patch.object(pin_nightly.time, 'sleep'), \
                    mock.patch('sys.stdout', io.StringIO()), \
                    self.assertRaises(BaseException) as caught:
                pin_nightly.main()
            written = report.exists() and json.loads(report.read_text(encoding='utf-8'))
        return caught.exception, written or None

    nightly = 'newest'
    FOLDERS, ONE_FOLDER = 'delimiter', 'prefix=prebuilts%2Fmediapipe_tasks_c%2F20261106'
    BUILD_INFO, ZIP = '20261106/BUILD_INFO', '20261106/mediapipe_tasks_c'
    STAGES = (FOLDERS, ONE_FOLDER, BUILD_INFO, ZIP)
    NETWORK = (lambda: urllib.error.URLError(socket.gaierror(-2, 'Name or service not known')),
               lambda: urllib.error.URLError(ConnectionRefusedError(111, 'refused')),
               lambda: urllib.error.URLError(TimeoutError('timed out')),
               lambda: urllib.error.URLError(OSError(errno.ENETUNREACH, 'unreachable')),
               lambda: urllib.error.URLError(OSError(errno.EHOSTUNREACH, 'unreachable')),
               lambda: urllib.error.URLError(OSError(errno.ENETDOWN, 'down')),
               lambda: urllib.error.URLError(ssl.SSLEOFError(8, 'EOF')),
               lambda: ConnectionResetError(104, 'reset'),
               lambda: http.client.RemoteDisconnected('closed'),
               lambda: TimeoutError('timed out'),
               *(lambda code=code: urllib.error.HTTPError('u', code, 'busy', None, None)
                 for code in (408, 429, 500, 502, 503, 504)))

    def test_a_network_failure_at_any_stage_is_reported_after_three_tries(self):
        for stage in self.STAGES:
            for make in self.NETWORK:
                error = make()
                failure, report = self.run_main(**{stage: error})
                self.assertIsInstance(failure, SystemExit, (stage, error))
                self.assertEqual(report, {
                    'network_failure': f'{type(error).__name__}: {error}'}, (stage, error))
                self.assertIn(report['network_failure'], str(failure))
                self.assertEqual(sum(stage in url for url in self.urls), 3, (stage, error))

    def test_a_connection_lost_in_a_body_is_a_network_failure(self):
        for lost in http.client.IncompleteRead(b''), ConnectionResetError(), TimeoutError(), \
                ssl.SSLEOFError():
            failure, report = self.run_main(delimiter=Body(lost))
            self.assertEqual(report, {'network_failure': f'{type(lost).__name__}: {lost}'})
            self.assertIsInstance(failure, SystemExit)

    def test_a_network_failure_on_the_newest_archive_does_not_settle_for_an_older_build(self):
        _, report = self.run_main(**{self.ZIP: urllib.error.HTTPError('u', 503, 'x', None, None)})
        self.assertIn('network_failure', report)
        self.assertFalse([url for url in self.urls if '20261105' in url])

    def test_a_night_asked_for_by_name_reports_it_the_same(self):
        self.nightly = '20261106'
        _, report = self.run_main(delimiter=urllib.error.URLError(socket.gaierror(-2, 'x')))
        self.assertIn('network_failure', report)

    def test_a_definite_answer_while_listing_stays_a_failure(self):
        for stage in self.FOLDERS, self.ONE_FOLDER:
            for code in 400, 401, 403, 404, 410:
                error = urllib.error.HTTPError('u', code, 'no', None, None)
                failure, report = self.run_main(**{stage: error})
                self.assertIs(failure, error)
                self.assertIsNone(report)
                self.assertEqual(sum(stage in url for url in self.urls), 1)

    def test_a_forbidden_build_info_stays_a_failure(self):
        error = urllib.error.HTTPError('u', 403, 'no', None, None)
        failure, report = self.run_main(**{self.BUILD_INFO: error})
        self.assertIs(failure, error)
        self.assertIsNone(report)

    def test_no_readable_build_stays_a_failure(self):
        missing = urllib.error.HTTPError('u', 404, 'no', None, None)
        forbidden = urllib.error.HTTPError('u', 403, 'no', None, None)
        for broken in ({'/BUILD_INFO': missing}, {'/BUILD_INFO': b'<html>'},
                       {'mediapipe_tasks_c_2': missing}, {'mediapipe_tasks_c_2': forbidden},
                       {'mediapipe_tasks_c_2': b'not a zip'}):
            failure, report = self.run_main(**broken)
            self.assertIsInstance(failure, SystemExit, broken)
            self.assertEqual(str(failure), 'No complete build.', broken)
            self.assertIsNone(report)

    def test_an_unparseable_listing_stays_a_failure(self):
        for body in b'<html>captive</html>', b'{"prefixes": [', b'\xff\xfe':
            failure, report = self.run_main(delimiter=body)
            self.assertIsInstance(failure, ValueError)
            self.assertIsNone(report)

    def test_an_empty_listing_stays_a_failure(self):
        failure, report = self.run_main(delimiter=b'{}')
        self.assertEqual(str(failure), 'No complete build.')
        self.assertIsNone(report)

    def test_an_error_that_is_not_the_network_stays_a_failure(self):
        for error in (urllib.error.URLError(ssl.SSLCertVerificationError(1, 'bad certificate')),
                      urllib.error.URLError(ssl.SSLError(1, 'wrong version')),
                      urllib.error.URLError('unknown url type'),
                      http.client.BadStatusLine('junk'),
                      FileNotFoundError(2, 'gone'), PermissionError(13, 'no'),
                      OSError(errno.ENOSPC, 'full'), KeyError('x'), TypeError('x')):
            failure, report = self.run_main(delimiter=error)
            self.assertIs(failure, error)
            self.assertIsNone(report)

    def test_a_code_error_in_the_pick_stays_a_failure(self):
        with mock.patch.object(pin_nightly, 'pick_build', side_effect=AttributeError('x')):
            failure, report = self.run_main()
        self.assertIsInstance(failure, AttributeError)
        self.assertIsNone(report)

    def test_a_digest_mismatch_after_the_pick_stays_a_failure(self):
        old = pin_nightly.current_pins()
        archive = mock.Mock(url='u', generation='1', size=1)
        archive.read.side_effect = SystemExit('u: BUILD_INFO inflated to 1 bytes, CRC 0')
        info = f"build_date=20261106\nmediapipe_version={old['version']}\n"
        with mock.patch.object(pin_nightly, 'pick_build',
                               return_value=('20261106', info, archive)):
            failure, report = self.run_main()
        self.assertIn('CRC', str(failure))
        self.assertIsNone(report)

    def run_walk(self, **broken):
        """run_main with the newest build on a new version, so that main dates
        the stop, and `broken` only reached by that walk."""
        info = f"build_date=20261106\nmediapipe_version={self.pins['version']}.new\n"
        archive = types.SimpleNamespace(url='u', generation='1', size=1)
        with mock.patch.object(pin_nightly, 'pick_build',
                               return_value=('20261106', info, archive)):
            return self.run_main(**broken)

    def assert_dated(self, walked, since):
        failure, report = walked
        self.assertIsInstance(failure, SystemExit)
        self.assertIn('move it by hand', str(failure))
        self.assertEqual(report['version_stop']['since'], since)

    def test_the_walk_dates_the_stop_when_nothing_fails(self):
        self.assert_dated(self.run_walk(), '20261106')

    def test_a_network_failure_in_the_walk_leaves_the_date_unknown(self):
        for stage in self.FOLDERS, self.BUILD_INFO:
            for make in self.NETWORK:
                error = make()
                self.assert_dated(self.run_walk(**{stage: error}), None)
                self.assertEqual(sum(stage in url for url in self.urls), 3, (stage, error))

    def test_a_connection_lost_in_a_body_in_the_walk_leaves_the_date_unknown(self):
        for stage in self.FOLDERS, self.BUILD_INFO:
            for lost in http.client.IncompleteRead(b''), ConnectionResetError(), TimeoutError(), \
                    ssl.SSLEOFError():
                self.assert_dated(self.run_walk(**{stage: Body(lost)}), None)

    def test_a_definite_answer_in_the_walk_stays_a_failure(self):
        for stage, codes in (self.FOLDERS, (400, 401, 403, 404, 410)), \
                (self.BUILD_INFO, (400, 401, 403, 410)):
            for code in codes:
                error = urllib.error.HTTPError('u', code, 'no', None, None)
                failure, report = self.run_walk(**{stage: error})
                self.assertIs(failure, error)
                self.assertIsNone(report)
                self.assertEqual(sum(stage in url for url in self.urls), 1)

    def test_an_unparseable_answer_in_the_walk_stays_a_failure(self):
        for stage, bodies in (self.FOLDERS, (b'<html>captive</html>', b'{"prefixes": [', b'\xff')), \
                (self.BUILD_INFO, (b'\xff\xfe',)):
            for body in bodies:
                failure, report = self.run_walk(**{stage: body})
                self.assertIsInstance(failure, ValueError, body)
                self.assertIsNone(report)

    def test_an_error_that_is_not_the_network_in_the_walk_stays_a_failure(self):
        for stage in self.FOLDERS, self.BUILD_INFO:
            for error in (urllib.error.URLError(ssl.SSLCertVerificationError(1, 'bad certificate')),
                          urllib.error.URLError(ssl.SSLError(1, 'wrong version')),
                          ssl.SSLError(1, 'wrong version'),
                          urllib.error.URLError('unknown url type'),
                          http.client.BadStatusLine('junk'),
                          PermissionError(13, 'no'), OSError(errno.ENOSPC, 'full'),
                          KeyError('x'), TypeError('x')):
                failure, report = self.run_walk(**{stage: error})
                self.assertIs(failure, error)
                self.assertIsNone(report)

    def test_a_code_error_in_the_walk_stays_a_failure(self):
        with mock.patch.object(pin_nightly, 'parse_build_info', side_effect=AttributeError('x')):
            failure, report = self.run_walk()
        self.assertIsInstance(failure, AttributeError)
        self.assertIsNone(report)

    def test_a_404_on_one_build_info_in_the_walk_passes_over_that_night(self):
        missing = urllib.error.HTTPError('u', 404, 'no', None, None)
        self.assert_dated(self.run_walk(**{self.BUILD_INFO: missing}), '20261106')
        self.assertEqual(sum(self.BUILD_INFO in url for url in self.urls), 1)
        self.assertTrue([url for url in self.urls if '20261105/BUILD_INFO' in url])

    def test_with_no_build_of_the_pinned_version_left_the_stop_dates_from_the_pin(self):
        missing = urllib.error.HTTPError('u', 404, 'no', None, None)
        for broken in {'/BUILD_INFO': missing}, {'/BUILD_INFO': b'<html>'}, {self.FOLDERS: b'{}'}:
            self.assert_dated(self.run_walk(**broken), self.pins['stamp'])


class Body(io.BytesIO):
    """A response whose read gives `body`, or raises it if it is an exception."""

    def __init__(self, body):
        super().__init__(b'' if isinstance(body, Exception) else body)
        self.body = body
        self.headers, self.status = email.message.Message(), 200

    def read(self, *args):
        if isinstance(self.body, Exception):
            raise self.body
        return super().read(*args)


class PinNightlyTest(unittest.TestCase):
    def setUp(self):
        self.source = pin_nightly.FAMILY_RUNTIMES.read_text(encoding='utf-8')
        self.relative = str(pin_nightly.FAMILY_RUNTIMES.relative_to(pin_nightly.REPO))
        self.old = pin_nightly.current_pins()
        self.digests = pinned_digests(self.source)

    def rewrite(self, old, generation):
        return pin_nightly.rewritten_sources(
            old, old['stamp'], old['version'], generation, self.digests)

    def test_reads_every_pin(self):
        self.assertEqual(len(self.old['paths']), 40)
        self.assertEqual(set(self.old['paths']), set(self.digests))

    def test_the_same_build_rewrites_nothing(self):
        for relative, text in self.rewrite(self.old, None).items():
            self.assertEqual(text, (pin_nightly.REPO / relative).read_text(encoding='utf-8'),
                             relative)

    def test_a_generation_goes_on_its_own_line_and_comes_off_again(self):
        pinned = self.rewrite(self.old, '1792585037995595')[self.relative]
        stamp = self.old['stamp']
        self.assertIn(f"    'mediapipe_tasks_c/{stamp}/mediapipe_tasks_c_{stamp}.zip'\n"
                      "    '?generation=1792585037995595';\n", pinned)
        self.assertEqual(len(pinned.splitlines()), len(self.source.splitlines()) + 1)
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory, 'family_runtimes.dart')
            copy.write_text(pinned, encoding='utf-8')
            original, pin_nightly.FAMILY_RUNTIMES = pin_nightly.FAMILY_RUNTIMES, copy
            try:
                old = pin_nightly.current_pins()
            finally:
                pin_nightly.FAMILY_RUNTIMES = original
        self.assertEqual(old['generation'], '1792585037995595')
        self.assertEqual(self.old['generation'], None)
        # rewritten_sources reads the repository's files; give it the
        # generation-pinned one by its text.
        before = pin_nightly.render(pin_nightly.SENTENCES[self.relative][3],
                                    stamp, old['version'], old['generation'])
        after = pin_nightly.render(pin_nightly.SENTENCES[self.relative][3],
                                   stamp, old['version'])
        self.assertEqual(pinned.replace(before, after), self.source)

    def test_comments_are_not_the_api(self):
        header = '// Source revision: 1\nint mp_open(const char* path); /* a */\n'
        comments_moved = '// Source revision: 2\nint mp_open(const char* path);\n/* b */\n'
        self.assertEqual(pin_nightly.strip_comments(header),
                         pin_nightly.strip_comments(comments_moved))
        self.assertNotEqual(pin_nightly.strip_comments(header),
                            pin_nightly.strip_comments(header.replace('path', 'path, int n')))


if __name__ == '__main__':
    unittest.main()
