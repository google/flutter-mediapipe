// Shared by the fixture camera's media source DLL and its host executable.
#pragma once

#include <guiddef.h>

// The media source's COM class, registered under HKLM so the Frame Server
// services can load it. {40A27443-E72D-4A75-9ED4-0FCEFDA4D712}
DEFINE_GUID(CLSID_MediaPipeFixtureCamera, 0x40a27443, 0xe72d, 0x4a75, 0x9e,
            0xd4, 0x0f, 0xce, 0xfd, 0xa4, 0xd7, 0x12);

#define MEDIAPIPE_FIXTURE_CAMERA_CLSID L"{40A27443-E72D-4A75-9ED4-0FCEFDA4D712}"
#define MEDIAPIPE_FIXTURE_CAMERA_NAME L"MediaPipe Fixture"

// Frame geometry, matching the Linux job's v4l2loopback stream.
constexpr unsigned kFixtureWidth = 640;
constexpr unsigned kFixtureHeight = 480;
constexpr unsigned kFixtureFps = 30;

// RCDATA id of the letterboxed portrait (top-down BGRX, written by
// make_fixture.ps1).
#define MEDIAPIPE_FIXTURE_RESOURCE 101
