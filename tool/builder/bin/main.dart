// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;
import 'package:args/command_runner.dart';
import 'package:builder/download_model.dart';
import 'package:builder/sync_headers.dart';
import 'package:logging/logging.dart';

final runner = CommandRunner(
  'build',
  'Performs build operations for google/flutter-mediapipe that '
      'depend on contents in this repository',
)
  ..addCommand(SyncHeadersCommand())
  ..addCommand(DownloadModelCommand());

void main(List<String> arguments) {
  Logger.root.onRecord.listen((LogRecord record) {
    io.stdout
        .writeln('${record.level.name}: ${record.time}: ${record.message}');
  });
  runner.run(arguments);
}
