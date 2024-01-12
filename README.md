# Flutter-MediaPipe

This repository will be home to the source code for the mediapipe_task_vision, mediapipe_task_audio, and mediapipe_task_text plugins for Flutter.

## Releasing

### Updating MediaPipe SDKs

Anytime MediaPipe releases new versions of their SDKs, this package will need to be updated to incorporate those latest builds. SDK versions are pinned in the `sdk_downloads.json` files in each package, which are updated by running the following command from the root of the repository:

```
$ make sdks
```

The Google Cloud Storage bucket in question only gives read-list access to a specific list of Googlers' accounts, so this command must be run from such a Googler's corp machines.

After this, create and merge a PR with the changes and then proceed to `Releasing to pub.dev`.

### Releasing to pub.dev

TODO