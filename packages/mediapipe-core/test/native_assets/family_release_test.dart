import 'dart:io';

import 'package:mediapipe_core/src/native_assets/family_runtimes.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('family-release-'));
  tearDown(() => root.deleteSync(recursive: true));

  /// A package directory under [root] at [path], with [version] in its
  /// pubspec, or no `version:` line when null.
  Uri package(String path, String? version) {
    final directory = Directory('${root.path}/$path')
      ..createSync(recursive: true);
    File('${directory.path}/pubspec.yaml').writeAsStringSync(
      'name: mediapipe_vision\n'
      '${version == null ? '' : 'version: $version\n'}',
    );
    return directory.uri;
  }

  /// A core checkout at [version], for the version the failure names.
  Uri core(String version) =>
      package('flutter-mediapipe/packages/mediapipe-core', version);

  /// A pub.dev release of mediapipe_vision, as pub lays out its cache.
  Uri hosted(String version) =>
      package('Pub/Cache/hosted/pub.dev/mediapipe_vision-$version', version);

  test('a pub.dev release before 0.3.0 stops the build, naming both '
      'packages, the versions found and the fix', () {
    for (final old in ['0.2.1', '0.2.0', '0.1.4', '0.2.1+1', '0.2.1-dev.3']) {
      expect(
        () => checkFamilyRelease(
          'mediapipe_vision',
          hosted(old),
          coreRoot: core('0.3.0'),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith(
                'mediapipe_vision $old does not work with mediapipe_core '
                '0.3.0, ',
              ),
              contains("Google's MediaPipe $familyRuntimeVersion"),
              contains('Upgrade mediapipe_vision to 0.3.0 or later'),
              contains('flutter pub upgrade mediapipe_vision'),
            ),
          ),
        ),
        reason: old,
      );
    }
  });

  test('without a core version to name, the failure still names the '
      "family's", () {
    expect(
      () => checkFamilyRelease(
        'mediapipe_vision',
        hosted('0.2.1'),
        coreRoot: root.uri.resolve('no-core/'),
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          allOf(
            startsWith(
              'mediapipe_vision 0.2.1 does not work with this mediapipe_core, ',
            ),
            contains('Upgrade mediapipe_vision to 0.3.0 or later'),
          ),
        ),
      ),
    );
  });

  test('a pub.dev release from 0.3.0 builds', () {
    for (final version in ['0.3.0', '0.3.1', '0.4.0', '1.0.0', '0.3.0-dev.1']) {
      expect(
        () => checkFamilyRelease('mediapipe_vision', hosted(version)),
        returnsNormally,
        reason: version,
      );
    }
  });

  test('path and git checkouts build whatever their pubspec says', () {
    for (final checkout in [
      // A path dependency, such as this repository's own packages.
      package('flutter-mediapipe/packages/mediapipe-task-vision', '0.2.1'),
      // A git dependency, as pub checks it out.
      package(
        'Pub/Cache/git/flutter-mediapipe-0123abcd/packages/'
            'mediapipe-task-vision',
        '0.2.1',
      ),
      // No version, or not a plain one.
      package('Pub/Cache/hosted/pub.dev/mediapipe_vision-0.2.1', null),
      package('Pub/Cache/hosted/pub.dev/mediapipe_vision-main', 'main'),
      // A hosted-looking folder named for another version than its pubspec.
      package('Pub/Cache/hosted/pub.dev/mediapipe_vision-0.3.0', '0.2.1'),
    ]) {
      expect(
        () => checkFamilyRelease('mediapipe_vision', checkout),
        returnsNormally,
        reason: checkout.toString(),
      );
    }
  });

  test('a missing package folder builds', () {
    expect(
      () => checkFamilyRelease(
        'mediapipe_vision',
        root.uri.resolve('Pub/Cache/hosted/pub.dev/mediapipe_vision-0.2.1/'),
      ),
      returnsNormally,
    );
  });
}
