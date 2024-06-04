# Flutter-MediaPipe

This repository will be home to the source code for the `mediapipe_vision`, `mediapipe_audio`, `mediapipe_text`, and `mediapipe_genai` plugins for Flutter.

## Packages

| Package | Description | Version |
| --- | --- | --- |
| [mediapipe_core](packages/mediapipe-core/) | Shared logic and utilities required by other MediaPipe Task packages. | ![pub package](https://img.shields.io/pub/v/mediapipe_core) |
| [mediapipe_text](packages/mediapipe-task-text/) | An implementation of the MediaPipe Text APIs | ![pub package](https://img.shields.io/pub/v/mediapipe_text) |
| [mediapipe_genai](packages/mediapipe-task-genai/) | An implementation of the MediaPipe GenAI APIs | ![pub package](https://img.shields.io/pub/v/mediapipe_genai) |

## Supported Tasks

<table>
    <tr>
        <th>Task</th>
        <th>Android</th>
        <th>iOS</th>
        <th>Web</th>
        <th>Windows</th>
        <th>macOS</th>
        <th>Linux</th>
    </tr>
    <tr>
        <td colspan="7" align="center"><strong>Text</strong></td>
    </tr>
    <tr>
        <td>Classification</td>
        <td align="center">✅</td>
        <td align="center">✅</td>
        <td align="center">-</td>
        <td align="center">-</td>
        <td align="center">✅</td>
        <td align="center">-</td>
    </tr>
    <tr>
        <td>Embedding</td>
        <td align="center">✅</td>
        <td align="center">✅</td>
        <td align="center">-</td>
        <td align="center">-</td>
        <td align="center">✅</td>
        <td align="center">-</td>
    </tr>
    <tr>
        <td>Language Detection</td>
        <td align="center">✅</td>
        <td align="center">✅</td>
        <td align="center">-</td>
        <td align="center">-</td>
        <td align="center">✅</td>
        <td align="center">-</td>
    </tr>
    <tr>
        <td colspan="7" align="center"><strong>GenAI</strong></td>
    </tr>
    <tr>
        <td>Inference</td>
        <td align="center">✅</td>
        <td align="center">✅</td>
        <td align="center">-</td>
        <td align="center">-</td>
        <td align="center">✅</td>
        <td align="center">-</td>
    </tr>
    <tr>
        <td colspan="7" align="center"><strong>Audio</strong></td>
    </tr>
    <tr>
        <td colspan="7" align="center"><strong>Vision</strong></td>
    </tr>
</table>

## Releasing

### Updating MediaPipe SDKs

Anytime MediaPipe releases new versions of their SDKs, this package will need to be updated to incorporate those latest builds. SDK versions are pinned in the `sdk_downloads.dart` files in each package, which are updated by running the following command from the root of the repository:

```
$ make sdks
```

The Google Cloud Storage bucket in question only gives read-list access to a specific list of Googlers' accounts, so this command must be run from such a Googler's corp machines.

After this, create and merge a PR with the changes and then proceed to `Releasing to pub.dev`.

<!--
### Releasing to pub.dev

TODO
-->
