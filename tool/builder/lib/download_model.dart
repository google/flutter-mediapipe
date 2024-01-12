// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;
import 'package:args/command_runner.dart';
import 'package:builder/repo_finder.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _log = Logger('DownloadModelCommand');

enum Models {
  textclassification,
  languagedetection,
}

class DownloadModelCommand extends Command with RepoFinderMixin {
  @override
  String description = 'Downloads a given MediaPipe model and places it in '
      'the designated location.';
  @override
  String name = 'model';

  DownloadModelCommand() {
    argParser
      ..addOption(
        'model',
        abbr: 'm',
        allowed: [
          // Values will be added to this as the repository gets more
          // integration tests that require new models.
          Models.textclassification.name,
          Models.languagedetection.name,
        ],
        help: 'The desired model to download. Use this option if you want the '
            'standard model for a given task. Using this option also removes any '
            'need to use the `destination` option, as a value here implies a '
            'destination. However, you still can specify a destination to '
            'override the default location where the model is placed.\n'
            '\n'
            'Note: Either this or `custommodel` must be used. If both are '
            'supplied, `model` is used.',
      )
      ..addOption(
        'custommodel',
        abbr: 'c',
        help: 'The desired model to download. Use this option if you want to '
            'specify a specific and nonstandard model. Using this option means '
            'you *must* use the `destination` option.\n'
            '\n'
            'Note: Either this or `model` must be used. If both are supplied, '
            '`model` is used.',
      )
      ..addOption(
        'destination',
        abbr: 'd',
        help:
            'The location to place the downloaded model. This value is required '
            'if you use the `custommodel` option, but optional if you use the '
            '`model` option.',
      );
    addVerboseOption(argParser);
  }

  static final Map<String, String> _standardModelSources = {
    Models.textclassification.name:
        'https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/1/bert_classifier.tflite',
    Models.languagedetection.name:
        'https://storage.googleapis.com/mediapipe-models/language_detector/language_detector/float32/1/language_detector.tflite',
  };

  static final Map<String, String> _standardModelDestinations = {
    Models.textclassification.name:
        'packages/mediapipe-task-text/example/assets/',
    Models.languagedetection.name:
        'packages/mediapipe-task-text/example/assets/',
  };

  @override
  Future<void> run() async {
    setUpLogging();
    final io.Directory flutterMediaPipeDirectory = findFlutterMediaPipeRoot();

    late final String modelSource;
    late final String modelDestination;

    if (argResults!['model'] != null) {
      modelSource = _standardModelSources[argResults!['model']]!;
      modelDestination = (_isArgProvided(argResults!['destination']))
          ? argResults!['destination']
          : _standardModelDestinations[argResults!['model']]!;
    } else {
      if (argResults!['custommodel'] == null) {
        throw Exception(
          'You must use either the `model` or `custommodel` option.',
        );
      }
      if (argResults!['destination'] == null) {
        throw Exception(
          'If you do not use the `model` option, then you must supply a '
          '`destination`, as a "standard" destination cannot be used.',
        );
      }
      modelSource = argResults!['custommodel'];
      modelDestination = argResults!['destination'];
    }

    io.File destinationFile = io.File(
      path.joinAll([
        flutterMediaPipeDirectory.absolute.path,
        modelDestination,
        modelSource.split('/').last,
      ]),
    );
    ensureFolders(destinationFile);
    await downloadModel(modelSource, destinationFile);
  }

  Future<void> downloadModel(
    String modelSource,
    io.File destinationFile,
  ) async {
    _log.info('Downloading $modelSource');

    // TODO(craiglabenz): Convert to StreamedResponse
    final response = await http.get(Uri.parse(modelSource));

    if (response.statusCode != 200) {
      throw Exception('${response.statusCode} ${response.reasonPhrase} :: '
          '$modelSource');
    }

    if (!(await destinationFile.exists())) {
      _log.fine('Creating file at ${destinationFile.absolute.path}');
      await destinationFile.create();
    }

    _log.fine('Downloaded ${response.contentLength} bytes');
    _log.info('Saving to ${destinationFile.absolute.path}');
    await destinationFile.writeAsBytes(response.bodyBytes);
  }
}

bool _isArgProvided(String? val) => val != null && val != '';
