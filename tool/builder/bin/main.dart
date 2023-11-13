// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:builder/sync_headers.dart';

final runner = CommandRunner(
  'build',
  'Performs build operations for google/flutter-mediapipe that '
      'depend on contents in this repository',
)..addCommand(SyncHeadersCommand());

void main(List<String> arguments) => runner.run(arguments);
