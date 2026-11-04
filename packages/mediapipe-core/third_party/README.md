# Google's notices

`LICENSE` and `NOTICE` are the files Google ships with its MediaPipe 1.2.0
nightly build of October 18, 2026 (byte for byte those of its October 9
build), the build whose libraries every family bundles (`lib/src/native_assets/family_runtimes.dart`). Google's delivery has
the same two files for every family, so core carries them once, unmodified.
An app that bundles any family's library redistributes them with it.

`NOTICE` opens with Google's MediaPipe Tasks privacy notice; the repository's
`doc/privacy_and_licenses.md` describes the usage logging it covers.

To update, replace both files with the ones from the build the hooks pin.
