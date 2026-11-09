/// Google's official Python wheel the tests treat as ground truth on a host.
///
/// The reference tools run Google's own Python API from this wheel, and the
/// tests compare the family libraries with what it answered. Each receipt
/// records the wheel's and its C library's digests, which the tests check
/// against these pins. It is Google's `mediapipe-nightly` 1.1.0 release
/// candidate, a release older than the family libraries
/// (`familyRuntimeVersion`, Google's 1.2.2 release of November 2). Google
/// published 1.1.0 itself on October 6, 2026 and a 1.1.1 nightly on
/// October 13; the pins move with the next regeneration of every fixture,
/// once Google says whether the Metal output since 1.1.1 is intended.
typedef ReferenceWheel = ({
  String version,
  String url,
  String wheelSha256,
  String libraryName,
  String librarySha256,
});

/// Google's wheel for each host that generates references.
const referenceWheels = <String, ReferenceWheel>{
  'macos/arm64': (
    version: '1.1.0rc20260925',
    url:
        'https://files.pythonhosted.org/packages/22/e7/'
        '4ab757489c2a167e7e84ff627389e7476c12e4b4998a332a7189d8b98eb0/'
        'mediapipe_nightly-1.1.0rc20260925-py3-none-macosx_11_0_arm64.whl',
    wheelSha256:
        '357a587c9ecfe73150a955cefd3715d01c1b5b58d70f9b09b1a80cb7f8761b2c',
    libraryName: 'libmediapipe.dylib',
    librarySha256:
        'a9d0e783f1aef73aae4a0e2df46154ced7d3dcb9ccd36989c092592921afcad6',
  ),
  'linux/x64': (
    version: '1.1.0rc20260925',
    url:
        'https://files.pythonhosted.org/packages/eb/ec/'
        '2caa83a45c295839e03a3dcbc3f2c883d5e07e128b1975a109420420b829/'
        'mediapipe_nightly-1.1.0rc20260925-py3-none-manylinux_2_28_x86_64.whl',
    wheelSha256:
        '634184cef1c39beb1bf0d0997a20e564c952303afc4cb42d18f2050a549393a2',
    libraryName: 'libmediapipe.so',
    librarySha256:
        '273e2ea1757c0e88e580c64829160f7711fdcd89ac2673a8fbbcab3058926087',
  ),
  'windows/x64': (
    version: '1.1.0rc20260925',
    url:
        'https://files.pythonhosted.org/packages/e4/e9/'
        '1fb04b4463213710ed62f1be71b22670d82a2d46316126cc6e8fb9b841c5/'
        'mediapipe_nightly-1.1.0rc20260925-py3-none-win_amd64.whl',
    wheelSha256:
        'b3ce6b3b4a3e870195930cbd96f626f49ad192ab591df0d9846a24302f64c0ff',
    libraryName: 'libmediapipe.dll',
    librarySha256:
        '67671f2f1bb5bf5ffcf6c1e7567859247f8fac7f111878b7b9b7e30f4bd8e103',
  ),
};

/// Google's wheel for the tasks whose 1.2.2 answers [referenceWheels]' 1.1.0
/// cannot give: the Audio Transcriber and Text to Speech, new in Google's
/// 1.2.2 C API, and the classic text tasks, whose Language Detector drops
/// low-probability languages since 1.1.0. It is Google's `mediapipe` 1.2.2
/// release, the release build of November 2 that the family libraries also
/// come from.
const releaseReferenceWheels = <String, ReferenceWheel>{
  'macos/arm64': (
    version: '1.2.2',
    url:
        'https://files.pythonhosted.org/packages/a3/5c/'
        'ce8750cfe2de42ab2433b2d6445f4a16225a63412d991b2970204b047d73/'
        'mediapipe-1.2.2-py3-none-macosx_11_0_arm64.whl',
    wheelSha256:
        'd3bb50923652182344ad31cfd2a09697e52952bd4bca2384ecabc90e21db9a5f',
    libraryName: 'libmediapipe.dylib',
    librarySha256:
        '6cb3aa2e19bce289939b617fb96c306db0449f757569ea22df7a4a9c14ac7c60',
  ),
  'linux/x64': (
    version: '1.2.2',
    url:
        'https://files.pythonhosted.org/packages/86/67/'
        '717b257855c5550a3449907e110954506a306bf3e127717f7ab45450f0da/'
        'mediapipe-1.2.2-py3-none-manylinux_2_28_x86_64.whl',
    wheelSha256:
        'c0b641bf1515dd186036da711df597a514466c0ba97a138f35b698ecc0411a61',
    libraryName: 'libmediapipe.so',
    librarySha256:
        '022f20f556e1148d6be05672475a483ba6358347fee8236e70ce8ef6a48aff72',
  ),
  'windows/x64': (
    version: '1.2.2',
    url:
        'https://files.pythonhosted.org/packages/6a/b0/'
        '6d1cb31a04f1726cdcd86cf0ea3eb1e9304e59de03bb083571dcab4ac227/'
        'mediapipe-1.2.2-py3-none-win_amd64.whl',
    wheelSha256:
        '71f44832fdd32b6270bc4379bcdd934287fb9eab974c3e74ef3fa76c7e79b54a',
    libraryName: 'libmediapipe.dll',
    librarySha256:
        '5def5b273a5acf0a90cdbf45cc12888dbddcf3323a1b0353331e40383db310d1',
  ),
};

/// The [referenceWheels] row for [target] (such as `macos/arm64`), or null
/// where no host generates references.
ReferenceWheel? referenceWheel(String target) => referenceWheels[target];

/// The [releaseReferenceWheels] row for [target], or null where no host
/// generates references with it.
ReferenceWheel? releaseReferenceWheel(String target) =>
    releaseReferenceWheels[target];
