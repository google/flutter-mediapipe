@TestOn('browser')
library;

import 'package:test/test.dart';

import '../support/stream_suite.dart';

/// The audio stream's contract on a fake backend in a browser, compiled to
/// JavaScript and to WebAssembly: the emulation is what browsers run, and
/// its clock must hold with JavaScript numbers.
void main() => streamSuite();
