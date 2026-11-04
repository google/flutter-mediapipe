import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_frames/video_frames.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('video_frames');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<Map<String, Object?>?> frames;
  late Map<String, Object?> info;

  setUp(() {
    calls = [];
    info = {'id': 7, 'rotation': 90, 'durationUs': 2000000, 'frameRate': 30};
    frames = [
      {
        'timestampUs': 33367,
        'width': 2,
        'height': 1,
        'layout': 'yuv420',
        'planes': [
          [
            Uint8List.fromList([1, 2, 0, 0]),
            4,
            1,
          ],
          [
            Uint8List.fromList([3]),
            1,
            2,
          ],
          [
            Uint8List.fromList([4]),
            1,
            2,
          ],
        ],
      },
      null,
    ];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'open' => info,
        'next' => frames.removeAt(0),
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('open reports the file and next returns frames, then null', () async {
    final reader = await VideoFileReader.open('/clips/a.mp4');
    expect(calls.single.arguments, {'path': '/clips/a.mp4'});
    expect(reader.rotationDegrees, 90);
    expect(reader.duration, const Duration(seconds: 2));
    // An integer rate from the channel still reads as a double.
    expect(reader.frameRate, 30.0);

    final frame = (await reader.next())!;
    expect(calls.last.arguments, {'id': 7});
    expect(frame.timestampMicroseconds, 33367);
    expect((frame.width, frame.height), (2, 1));
    expect(frame.layout, VideoPixelLayout.yuv420);
    expect(frame.planes, hasLength(3));
    expect(frame.planes[0].bytes, [1, 2, 0, 0]);
    expect(frame.planes[0].bytesPerRow, 4);
    expect(frame.planes[1].bytesPerPixel, 2);
    expect(await reader.next(), isNull);
  });

  test('a file that declares no length or rate reports null', () async {
    info = {...info, 'durationUs': 0, 'frameRate': 0.0};
    final reader = await VideoFileReader.open('/clips/a.mp4');
    expect(reader.duration, isNull);
    expect(reader.frameRate, isNull);
  });

  test('close releases the decoder once and ends the reader', () async {
    final reader = await VideoFileReader.open('/clips/a.mp4');
    await reader.close();
    await reader.close();
    expect(calls.where((call) => call.method == 'close').single.arguments, {
      'id': 7,
    });
    expect(reader.next, throwsStateError);
  });

  test('a decoder failure reaches the caller', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'open', message: 'No video track.');
    });
    await expectLater(
      VideoFileReader.open('/clips/audio.m4a'),
      throwsA(isA<PlatformException>()),
    );
  });
}
