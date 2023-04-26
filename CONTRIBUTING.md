# Contributing guidelines

## How to become a contributor and submit your own code

### Contributor License Agreements

We'd love to accept your patches! Before we can take them, we have to jump a couple of legal hurdles.

Please fill out either the individual or corporate Contributor License Agreement (CLA).

  * If you are an individual writing original source code and you're sure you own the intellectual property, then you'll need to sign an [individual CLA](https://code.google.com/legal/individual-cla-v1.0.html).
  * If you work for a company that wants to allow you to contribute your work, then you'll need to sign a [corporate CLA](https://code.google.com/legal/corporate-cla-v1.0.html).

Follow either of the two links above to access the appropriate CLA and instructions for how to sign and return it. Once we receive it, we'll be able to accept your pull requests.

***NOTE***: Only original source code from you and other people that have signed the CLA can be accepted into the main repository.

### Contributing code

If you have improvements to MediaPipe, send us your pull requests! For those
just getting started, Github has a [howto](https://help.github.com/articles/using-pull-requests/).

MediaPipe team members will be assigned to review your pull requests. Once the pull requests are approved and pass continuous integration checks, we will merge the pull requests.
For some pull requests, we will apply the patch for each pull request to our internal version control system first, and export the change out as a new commit later, at which point the original pull request will be closed. The commits in the pull request will be squashed into a single commit with the pull request creator as the author. These pull requests will be labeled as pending merge internally.

### Contribution guidelines and standards

Before sending your pull request for
[review](https://github.com/google/flutter-mediapipe/pulls),
make sure your changes are consistent with the guidelines and follow the
MediaPipe coding style.

#### General guidelines and philosophy for contribution

* Include unit tests when you contribute new features, as they help to
  a) prove that your code works correctly, and b) guard against future breaking
  changes to lower the maintenance cost.
* Bug fixes also generally require unit tests, because the presence of bugs
  usually indicates insufficient test coverage.
* When you contribute a new feature to MediaPipe, the maintenance burden is (by
  default) transferred to the MediaPipe team. This means that benefit of the
  contribution must be compared against the cost of maintaining the feature.

#### License

Include a license at the top of new files.

TODO: Examples

#### Coding styles for various languages

* [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html).
* [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
* [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
* [Google JavaScript Style Guide](https://google.github.io/styleguide/jsguide.html)
* [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml)
* [Google Objective-C Style Guide](https://google.github.io/styleguide/objcguide.html)
