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

Include the Flutter license at the top of each new file you create.

## Developing the plugins

### Non-Dart code pre-work

> Note: For now, because `google/flutter-mediapipe` uses a Flutter experiment, and
> Flutter experiments are only available on the `master` channel, development or
> use of any plugins found in this repository is only possible on the `master`
> channel. This restriction will be listed when the `native-assets` experiment
> is added to the stable channel.

As described above, switch to the `master` channel to work on or use the various
`flutter-mediapipe` plugins:

```sh
$ flutter channel master
$ flutter doctor
```

#### Checking out the `google/mediapipe` repository

Some of `google/flutter-mediapipe` repository's tooling requires a local checkout
of the `google/mediapipe` repository. By default, this tooling assumes both
repositories are colocated within the same directory, but if you prefer to
checkout the `google/mediapipe` repository elsewhere, then you can specify its
absolute path on your machine via the `--source` or `-s` flag.

#### Updating header files

The reason a local checkout of `google/mediapipe` is required is that 
`google/flutter-mediapipe` uses copies of header files found in the former. To
sync the latest versions of all header files from `google/mediapipe` to
`google/flutter-mediapipe`, run the `sync_headers` command found in the `tool`
directory like so:

```sh
$ cd tool/builder && dart bin/main.dart headers
```

Alternatively, users of POSIX systems can use the shortcut found in the `Makefile`:

```sh
$ make headers
```

#### Adding new header files

If you are adding new tasks, it is highly likely you will need to include new headers
in the sweep executed by the `sync_headers` command. To do this, open
`tool/builder/lib/sync_headers.dart` and review the directives collected in the 
`headerPaths` variable. Add any new paths you need to collect, and then modify any
relative import paths using the `relativeIncludes` method if necessary. It is also
possible that `relativeIncludes` is not sufficient for all scenarios that the
MediaPipe library will ever encounter, so do not hesitate to modify `relativeIncludes`
or add a new function if necessary.

Once you have modified this script, re-run the headers command to pull your new files
out of `google/mediapipe` and into `google/flutter-mediapipe`. Pre-existing header
files should not have any changes, but your new files should appear.

If pre-existing header files do change because they have genuinely evolved within
`google/mediapipe` since anyone else last ran the command, those changes should be
resolved within their own PR.

#### Running ffigen

Any time the header file definitions change, `ffigen` must be re-run for that plugin.
To do this, open the `ffigen.yaml` file within a given plugin and ensure list of
blob paths at `headers/entry-points` includes any new header files you have added.
Then, re-run `ffigen` like so:

```sh
$ cd packages/<pkg-name> && dart run ffigen --config=ffigen.yaml
```

Alternatively, users of POSIX systems can use the shortcut found in the `Makefile`:

```sh
$ make generate_<pkg-suffix>
```

Consult the `Makefile` for the appropriate command for your plugin, or add one
if you are contributing the first header files for a given plugin.

#### Updating the MediaPipe SDKs

> Note: This task can only be run from a Googler's corp laptop with LIST read
> permissions on the MediaPipe bucket in Google Cloud Storage. Non-Googlers should
> not encounter a need to run the command, but if you believe you have, file an issue.

Flutter collects MediaPipe artifacts at build time and compiles them into your
binary using the experimental new feature, named "Native Assets".

> Note: As described above, this feature is only available on the `master` channel
> (as experiments in general are only available on the `master` channel).

The locations of the latest MediaPipe SDK binaries for each task are stored in the
`sdk_downloads.dart` manifest files for each package. If you need to test against 
different versions of an SDK but cannot run the command, you can manually edit the
`sdk_downloads.dart` file, though these manual edits should not be committed.

Finally, if you are a Googler and able to run the command, you can update each
plugin's manifest file in one maneuver by running the command:

```sh
$ cd tool/builder && dart bin/main.dart sdks
```

Alternatively, users of POSIX systems can use the shortcut found in the `Makefile`:

```sh
$ make sdks
```

You do not need to take any manual steps to download or include an SDK at build-
time, as the `$ flutter run|build` command handles that for you.

### Write your Dart code

It is finally time to write some Dart code!

#### Adding a new task

##### Adding the IO implementation

If you are contributing a new task, you should have added new header files to the
`sync_headers.dart` script and run the command yourself. This should have copied
those specified headers out of `google/mediapipe` and into your git clone of 
`google/flutter-mediapipe`. To begin implementing your new MediaPipe task, add
a new folder to the appropriate `<pkg_name>/lib/src/interface/tasks/` directory and
add apporpriate exports to the `tasks.dart` barrel file. Then add abstract
definitions for any structs newly introduced to the repository through the new
task you are adding. For reference on how these interface definitions should look,
consult existing interface definitions from other tasks, or from `mediapipe_core`.

Next, add concrete implementations for this task by adding an appropriate folder
to the `<pkg_name>/lib/src/io/tasks/` directory and appropriate exports to the 
`tasks.dart` barrel file. Your task's `Options` class will typically originate
from Dart code, and so should know how to allocate itself into native memory and
then later deallocate that memory. Most other classes originate within native
memory itself and are returned to Dart by calling the task's methods. These classes
should have `.native()` factory constructors which accept a pointer. They should
also have direct constructors which accept pure Dart values, set private fields,
and are only suitable for testing. Reference other tasks' implementations for
inspiration on how to handle this memory management.

##### Adding the web implementation

Next, if your task has a web folder with contents, add a web implementation. As
of this writing, no web implementations yet exist.

##### Adding the sample

New task implementations should include a new screen in the example app. Add a
new element to the `PageView` widget's children, then add your sample within that
new widget. For reference on how to initialize the MediaPipe SDK for your task,
consult existing examples. It is recommended that you use this example as the
primary way of proving to yourself that your new task implementation works as intended
(along with tests, of course).

#### Improving an existing task

If you are improving an existing task, either by adding overlooked functionality
or fixing a bug, your job should be much simpler than that of adding an entirely
new task. If you get stuck, open a PR with everything you have accomplished and 
request assistance from Craig Labenz.

#### Adding tests

All new PRs should include tests that demonstrate correctness. Integration tests
exist in the `mediapipe_text` plugin, but as of this writing, are not yet
implemented in the `mediapipe_genai` plugin.