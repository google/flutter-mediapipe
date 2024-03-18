// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;
import 'package:logging/logging.dart';

final log = Logger('TextTask');

void initLogging() {
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.listen((record) {
    io.stdout.writeln('${record.level.name} [${record.loggerName}]'
        '['
        '${record.time.hour.toString()}:'
        '${record.time.minute.toString().padLeft(2, "0")}:'
        '${record.time.second.toString().padLeft(2, "0")}.'
        '${record.time.millisecond.toString().padRight(3, "0")}'
        '] ${record.message}');
  });
}
