import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../live/operation_queue.dart';
import '../live/still_image.dart' show pickStillImage;
import 'components.dart';
import 'design.dart';

/// The photos Google's Image Embedding demo offers for either image, with
/// the labels its chips show.
const embedSamples = [
  (label: 'Dog', file: 'dog.jpg'),
  (label: 'Cat', file: 'cat.png'),
  (label: 'Elephant', file: 'elephant.png'),
];

/// One image a similarity page compares: a sample or an upload, as the
/// encoded bytes on screen and, decoded from them, what the task embeds.
final class SimilaritySlot<I> {
  SimilaritySlot({this.sample});

  /// The chosen sample's file, or null for an upload.
  String? sample;

  /// The encoded image on screen.
  Uint8List? bytes;

  /// What the task embeds, once decoded.
  I? input;

  /// Bumped per choice, so a slow decode never replaces a newer choice.
  int _choice = 0;
}

/// What one comparison found: the cosine similarity, the embeddings' length,
/// and the delegate that ran it, as the status line names it.
typedef Comparison = ({double similarity, int? dimensions, String? ranOn});

/// A page that compares two inputs by the cosine similarity of their
/// embeddings. It chooses, uploads and decodes the images, keeps the task
/// open between comparisons, runs them one at a time and shows the result.
mixin SimilarityState<T extends StatefulWidget, I, E extends Object>
    on State<T> {
  /// The prefix of the page's keys and semantics identifiers.
  String get id;

  /// Lets device tests upload a fixture through the real Upload buttons.
  Future<XFile?> Function()? get imagePicker;

  /// Decodes an image's bytes into what the task embeds.
  Future<I> decodeImage(Uint8List bytes);

  /// Opens the task with the current model, delegate and settings.
  Future<E> openEmbedder();

  /// Releases an open task.
  Future<void> disposeEmbedder(E embedder);

  /// Runs once a chosen or uploaded image is on screen and decoded; a page
  /// that compares as soon as both images are there overrides it.
  void imageShown() {}

  /// The open task, kept between comparisons and rebuilt when the model, the
  /// delegate or a setting changes.
  E? embedder;

  /// Whether a comparison is running.
  bool busy = false;

  /// The last comparison's similarity, or null before one or after a failure.
  double? similarity;

  /// How long the last comparison's embeddings took.
  double? milliseconds;

  /// Opening, comparing and closing the task, one at a time in order.
  final _operations = OperationQueue();

  /// Bumped per comparison, so only the newest one reports.
  int _comparison = 0;
  int? _dimensions;
  String? _ranOn;
  String? _error;

  /// Shows [sample], one of [embedSamples], in [slot].
  Future<void> chooseSample(SimilaritySlot<I> slot, String sample) async {
    if (slot.sample == sample && slot.input != null) return;
    final choice = ++slot._choice;
    // The chip follows the tap at once; the picture follows once decoded.
    setState(() => slot.sample = sample);
    try {
      final data = await rootBundle.load('assets/samples/$sample');
      await _show(
        slot,
        choice,
        sample,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } on Object catch (error) {
      if (mounted && choice == slot._choice) {
        setState(() => _error = '$error');
      }
    }
  }

  /// Shows an image of the user's own in [slot].
  Future<void> uploadImage(SimilaritySlot<I> slot) async {
    try {
      final file = await (imagePicker?.call() ?? pickStillImage());
      if (file == null) return;
      final choice = ++slot._choice;
      await _show(slot, choice, null, await file.readAsBytes());
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _show(
    SimilaritySlot<I> slot,
    int choice,
    String? sample,
    Uint8List bytes,
  ) async {
    final input = await decodeImage(bytes);
    if (!mounted || choice != slot._choice) return;
    setState(() {
      slot.sample = sample;
      slot.bytes = bytes;
      slot.input = input;
    });
    imageShown();
  }

  /// Opens the task if need be, times [measure] on it and shows what it
  /// found. A newer comparison, or a page gone meanwhile, discards the result.
  void compare(Future<Comparison> Function(E embedder) measure) {
    final comparison = ++_comparison;
    setState(() {
      busy = true;
      _error = null;
    });
    unawaited(
      _operations.add(() async {
        if (!mounted || comparison != _comparison) return;
        try {
          final open = embedder ??= await openEmbedder();
          final clock = Stopwatch()..start();
          final found = await measure(open);
          clock.stop();
          if (!mounted || comparison != _comparison) return;
          setState(() {
            similarity = found.similarity;
            _dimensions = found.dimensions;
            _ranOn = found.ranOn;
            milliseconds = clock.elapsedMicroseconds / 1000;
            _error = null;
            busy = false;
          });
        } on Object catch (error) {
          if (!mounted || comparison != _comparison) return;
          setState(() {
            similarity = null;
            _ranOn = null;
            _error = '$error';
            busy = false;
          });
        }
      }),
    );
  }

  /// Releases the task once whatever is running has finished, so the next
  /// comparison opens it with the current model, delegate and settings.
  void closeEmbedder() {
    unawaited(
      _operations.add(() async {
        final open = embedder;
        embedder = null;
        try {
          if (open != null) await disposeEmbedder(open);
        } on Object catch (error) {
          if (mounted) setState(() => _error = '$error');
        }
      }),
    );
  }

  @override
  void dispose() {
    _comparison++;
    closeEmbedder();
    super.dispose();
  }

  /// Image [number]'s sample chips, its Upload button and the picture,
  /// [height] tall.
  Widget imageSlot(
    BuildContext context, {
    required int number,
    required SimilaritySlot<I> slot,
    required double height,
  }) {
    final c = GalleryColors.of(context);
    final bytes = slot.bytes;
    final label = embedSamples
        .where((sample) => sample.file == slot.sample)
        .firstOrNull
        ?.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                // A narrow column shrinks the chips rather than wrapping.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Segmented<String>(
                    semanticsIdentifier: '$id-$number-samples',
                    segments: [
                      for (final sample in embedSamples)
                        (
                          value: sample.file,
                          label: sample.label,
                          icon: null,
                          key: ValueKey(
                            '$id-$number-${sample.label.toLowerCase()}',
                          ),
                        ),
                    ],
                    selected: slot.sample,
                    onChanged: (sample) =>
                        unawaited(chooseSample(slot, sample)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              identifier: '$id-$number-upload',
              container: true,
              child: OutlineButton(
                key: ValueKey('$id-$number-upload'),
                icon: LucideIcons.upload,
                label: 'Upload',
                tooltip: 'Upload image $number',
                onPressed: () => unawaited(uploadImage(slot)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF090B0B),
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(Sizes.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes == null
              ? const Center(child: CircularProgressIndicator())
              : Image.memory(
                  bytes,
                  key: ValueKey('$id-$number-image'),
                  fit: BoxFit.contain,
                  // Keeps the last picture up while the next one decodes.
                  gaplessPlayback: true,
                  semanticLabel: 'Image $number: ${label ?? 'uploaded'}',
                ),
        ),
      ],
    );
  }

  /// The status line, what went wrong if anything, and Google's result card:
  /// the similarity, large, under its label.
  List<Widget> similarityResults(BuildContext context) {
    final c = GalleryColors.of(context);
    final ms = milliseconds;
    final value = similarity?.toStringAsFixed(4);
    return [
      FeedStatus(
        parts: [
          if (_dimensions case final dimensions?) '$dimensions dimensions',
          if (ms != null) 'Inference ${ms.toStringAsFixed(1)} ms',
        ],
        delegate: _ranOn,
      ),
      if (_error case final error?)
        Semantics(
          identifier: '$id-error',
          container: true,
          child: Padding(
            key: ValueKey('$id-error'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: Sizes.sm,
              ),
            ),
          ),
        ),
      Semantics(
        identifier: '$id-similarity',
        container: true,
        label: 'Cosine similarity ${value ?? '--'}',
        excludeSemantics: true,
        child: SurfaceCard(
          key: ValueKey('$id-similarity'),
          child: Column(
            children: [
              const Eyebrow('Cosine similarity'),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: Center(
                  child: value == null && busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      // A comparison in progress dims the value it replaces.
                      : AnimatedOpacity(
                          opacity: busy ? .4 : 1,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            value ?? '--',
                            key: ValueKey('$id-similarity-value'),
                            style: TextStyle(
                              color: c.teal,
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
