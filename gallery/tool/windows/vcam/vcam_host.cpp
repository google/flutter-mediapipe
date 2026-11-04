// Hosts the MediaPipe fixture camera for a CI job, and inspects it.
//
//   vcam_host start [--all-users] [--system] | start --auto
//       Creates and starts the virtual camera, then keeps it alive until the
//       process ends (session lifetime) or the named event
//       Local\MediaPipeFixtureCameraStop is set. --auto tries current-user
//       session, all-users session and all-users system scopes in turn. CI
//       runs plain `start` and ends the process; the flags and the stop event
//       serve a contributor's own machine.
//   vcam_host list
//       Prints every video capture device; exits 0 only when the fixture
//       camera is among them.
//   vcam_host smoke [frames] [frame.bmp]
//       Opens the fixture camera the way camera_desktop does
//       (MFCreateDeviceSource on its symbolic link), reads frames through a
//       source reader, compares the last one with the embedded fixture, and
//       optionally saves it as a bitmap.
//
// The virtual camera API is documented at
// https://learn.microsoft.com/windows/win32/api/mfvirtualcamera/.

#include <windows.h>
#include <initguid.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mfvirtualcamera.h>
#include <wrl/client.h>

#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <vector>

#include "vcam.h"

using Microsoft::WRL::ComPtr;

namespace {

void Log(const wchar_t* format, ...) {
  va_list arguments;
  va_start(arguments, format);
  vfwprintf(stdout, format, arguments);
  va_end(arguments);
  fputwc(L'\n', stdout);
  fflush(stdout);
}

struct Device {
  std::wstring name;
  std::wstring link;
};

std::vector<Device> VideoDevices() {
  std::vector<Device> devices;
  ComPtr<IMFAttributes> query;
  IMFActivate** found = nullptr;
  UINT32 count = 0;
  HRESULT hr = MFCreateAttributes(&query, 1);
  if (SUCCEEDED(hr)) {
    hr = query->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  }
  if (SUCCEEDED(hr)) hr = MFEnumDeviceSources(query.Get(), &found, &count);
  if (FAILED(hr)) {
    Log(L"MFEnumDeviceSources: 0x%08X", hr);
    return devices;
  }
  for (UINT32 i = 0; i < count; i++) {
    wchar_t* name = nullptr;
    wchar_t* link = nullptr;
    UINT32 length = 0;
    found[i]->GetAllocatedString(MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME, &name,
                                 &length);
    found[i]->GetAllocatedString(
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK, &link, &length);
    devices.push_back({name ? name : L"", link ? link : L""});
    CoTaskMemFree(name);
    CoTaskMemFree(link);
    found[i]->Release();
  }
  CoTaskMemFree(found);
  return devices;
}

// The pipeline appends " (Windows Virtual Camera)" to the friendly name.
bool IsFixture(const Device& device) {
  return device.name.rfind(MEDIAPIPE_FIXTURE_CAMERA_NAME, 0) == 0;
}

int List() {
  bool present = false;
  for (const Device& device : VideoDevices()) {
    Log(L"device: %s | %s", device.name.c_str(), device.link.c_str());
    present = present || IsFixture(device);
  }
  Log(present ? L"fixture camera: present" : L"fixture camera: ABSENT");
  return present ? 0 : 2;
}

struct Scope {
  bool allUsers;
  bool system;
};

// Creates and starts the camera for `scope`; null when either step fails.
ComPtr<IMFVirtualCamera> Create(Scope scope) {
  Log(L"creating %s: access=%s lifetime=%s source=%s",
      MEDIAPIPE_FIXTURE_CAMERA_NAME,
      scope.allUsers ? L"all-users" : L"current-user",
      scope.system ? L"system" : L"session", MEDIAPIPE_FIXTURE_CAMERA_CLSID);
  ComPtr<IMFVirtualCamera> camera;
  HRESULT hr = MFCreateVirtualCamera(
      MFVirtualCameraType_SoftwareCameraSource,
      scope.system ? MFVirtualCameraLifetime_System
                   : MFVirtualCameraLifetime_Session,
      scope.allUsers ? MFVirtualCameraAccess_AllUsers
                     : MFVirtualCameraAccess_CurrentUser,
      MEDIAPIPE_FIXTURE_CAMERA_NAME, MEDIAPIPE_FIXTURE_CAMERA_CLSID, nullptr, 0,
      &camera);
  Log(L"MFCreateVirtualCamera: 0x%08X", hr);
  if (FAILED(hr)) return nullptr;
  hr = camera->Start(nullptr);
  Log(L"IMFVirtualCamera::Start: 0x%08X", hr);
  if (FAILED(hr)) {
    camera->Shutdown();
    return nullptr;
  }
  return camera;
}

// With `scopes` holding more than one entry, tries each in turn and keeps the
// first camera that starts.
int Start(const std::vector<Scope>& scopes) {
  ComPtr<IMFVirtualCamera> camera;
  for (const Scope& scope : scopes) {
    camera = Create(scope);
    if (camera) break;
  }
  if (!camera) return 4;
  List();
  Log(L"VCAM_READY");
  HANDLE stop =
      CreateEventW(nullptr, TRUE, FALSE, L"Local\\MediaPipeFixtureCameraStop");
  // A heartbeat, so the log shows how long the camera stayed up.
  for (int seconds = 30; WaitForSingleObject(stop, 30'000) == WAIT_TIMEOUT;
       seconds += 30) {
    Log(L"alive %d s", seconds);
  }
  Log(L"stopping: 0x%08X", camera->Stop());
  Log(L"removing: 0x%08X", camera->Remove());
  camera->Shutdown();
  return 0;
}

std::wstring SubtypeName(const GUID& subtype) {
  if (subtype == MFVideoFormat_RGB32) return L"RGB32";
  if (subtype == MFVideoFormat_ARGB32) return L"ARGB32";
  if (subtype == MFVideoFormat_NV12) return L"NV12";
  if (subtype == MFVideoFormat_YUY2) return L"YUY2";
  if (subtype == MFVideoFormat_MJPG) return L"MJPG";
  wchar_t text[16];
  swprintf_s(text, L"0x%08lX", subtype.Data1);
  return text;
}

std::vector<BYTE> EmbeddedFixture() {
  HMODULE module = GetModuleHandleW(nullptr);
  HRSRC resource = FindResourceW(
      module, MAKEINTRESOURCEW(MEDIAPIPE_FIXTURE_RESOURCE), RT_RCDATA);
  HGLOBAL loaded = resource ? LoadResource(module, resource) : nullptr;
  const BYTE* bytes =
      loaded ? static_cast<const BYTE*>(LockResource(loaded)) : nullptr;
  if (!bytes) return {};
  return std::vector<BYTE>(bytes, bytes + SizeofResource(module, resource));
}

// Copies a delivered frame into top-down BGRX, honouring a negative stride.
HRESULT CopyFrame(IMFSample* sample, LONG defaultStride, std::vector<BYTE>& out) {
  const size_t row = size_t(kFixtureWidth) * 4;
  out.assign(row * kFixtureHeight, 0);
  ComPtr<IMFMediaBuffer> buffer;
  HRESULT hr = sample->GetBufferByIndex(0, &buffer);
  if (FAILED(hr)) return hr;
  ComPtr<IMF2DBuffer> buffer2d;
  BYTE* scan0 = nullptr;
  LONG pitch = 0;
  if (SUCCEEDED(buffer.As(&buffer2d)) &&
      SUCCEEDED(buffer2d->Lock2D(&scan0, &pitch))) {
    for (unsigned y = 0; y < kFixtureHeight; y++) {
      memcpy(out.data() + y * row, scan0 + ptrdiff_t(y) * pitch, row);
    }
    buffer2d->Unlock2D();
    return S_OK;
  }
  BYTE* data = nullptr;
  DWORD capacity = 0, length = 0;
  hr = buffer->Lock(&data, &capacity, &length);
  if (FAILED(hr)) return hr;
  const LONG stride = defaultStride ? defaultStride : LONG(row);
  const size_t needed = size_t(labs(stride)) * kFixtureHeight;
  if (length < needed) {
    buffer->Unlock();
    return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
  }
  BYTE* top = stride < 0 ? data + ptrdiff_t(kFixtureHeight - 1) * -stride : data;
  for (unsigned y = 0; y < kFixtureHeight; y++) {
    memcpy(out.data() + y * row, top + ptrdiff_t(y) * stride, row);
  }
  buffer->Unlock();
  return S_OK;
}

// Mean absolute difference per colour channel, with the fixture optionally
// mirrored left to right or flipped top to bottom.
double Difference(const std::vector<BYTE>& frame,
                  const std::vector<BYTE>& fixture, bool mirror, bool flip) {
  double total = 0;
  for (unsigned y = 0; y < kFixtureHeight; y++) {
    for (unsigned x = 0; x < kFixtureWidth; x++) {
      const unsigned fx = mirror ? kFixtureWidth - 1 - x : x;
      const unsigned fy = flip ? kFixtureHeight - 1 - y : y;
      const BYTE* a = &frame[(size_t(y) * kFixtureWidth + x) * 4];
      const BYTE* b = &fixture[(size_t(fy) * kFixtureWidth + fx) * 4];
      total += abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]);
    }
  }
  return total / (double(kFixtureWidth) * kFixtureHeight * 3);
}

bool WriteBitmap(const wchar_t* path, const std::vector<BYTE>& bgrx) {
  BITMAPINFOHEADER info = {};
  info.biSize = sizeof(info);
  info.biWidth = LONG(kFixtureWidth);
  info.biHeight = -LONG(kFixtureHeight);  // top-down
  info.biPlanes = 1;
  info.biBitCount = 32;
  info.biCompression = BI_RGB;
  BITMAPFILEHEADER header = {};
  header.bfType = 0x4D42;
  header.bfOffBits = sizeof(header) + sizeof(info);
  header.bfSize = header.bfOffBits + DWORD(bgrx.size());
  FILE* file = nullptr;
  if (_wfopen_s(&file, path, L"wb") != 0 || !file) return false;
  fwrite(&header, sizeof(header), 1, file);
  fwrite(&info, sizeof(info), 1, file);
  fwrite(bgrx.data(), 1, bgrx.size(), file);
  fclose(file);
  return true;
}

int Smoke(int frames, const wchar_t* bitmap) {
  std::wstring link;
  for (const Device& device : VideoDevices()) {
    if (IsFixture(device)) link = device.link;
  }
  if (link.empty()) {
    Log(L"smoke: the fixture camera is not enumerated");
    return 2;
  }
  // A source that never delivers blocks ReadSample; fail instead of hanging.
  std::thread([] {
    Sleep(60'000);
    Log(L"smoke: timed out after 60 s");
    ExitProcess(5);
  }).detach();

  ComPtr<IMFAttributes> attributes;
  ComPtr<IMFMediaSource> source;
  HRESULT hr = MFCreateAttributes(&attributes, 2);
  if (SUCCEEDED(hr)) {
    hr = attributes->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                             MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  }
  if (SUCCEEDED(hr)) {
    hr = attributes->SetString(
        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK, link.c_str());
  }
  if (SUCCEEDED(hr)) hr = MFCreateDeviceSource(attributes.Get(), &source);
  Log(L"MFCreateDeviceSource: 0x%08X", hr);
  if (FAILED(hr)) return 3;

  // The media types the device offers, as a capture engine sees them.
  ComPtr<IMFPresentationDescriptor> presentation;
  ComPtr<IMFStreamDescriptor> stream;
  ComPtr<IMFMediaTypeHandler> handler;
  BOOL selected = FALSE;
  DWORD types = 0;
  if (SUCCEEDED(source->CreatePresentationDescriptor(&presentation)) &&
      SUCCEEDED(presentation->GetStreamDescriptorByIndex(0, &selected, &stream)) &&
      SUCCEEDED(stream->GetMediaTypeHandler(&handler)) &&
      SUCCEEDED(handler->GetMediaTypeCount(&types))) {
    for (DWORD i = 0; i < types; i++) {
      ComPtr<IMFMediaType> type;
      GUID subtype = GUID_NULL;
      UINT32 width = 0, height = 0, numerator = 0, denominator = 1;
      if (FAILED(handler->GetMediaTypeByIndex(i, &type))) continue;
      type->GetGUID(MF_MT_SUBTYPE, &subtype);
      MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &width, &height);
      MFGetAttributeRatio(type.Get(), MF_MT_FRAME_RATE, &numerator, &denominator);
      Log(L"offered type %lu: %s %ux%u @ %u/%u", i, SubtypeName(subtype).c_str(),
          width, height, numerator, denominator);
    }
  }

  ComPtr<IMFAttributes> options;
  ComPtr<IMFSourceReader> reader;
  hr = MFCreateAttributes(&options, 1);
  if (SUCCEEDED(hr)) hr = options->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
  if (SUCCEEDED(hr)) {
    hr = MFCreateSourceReaderFromMediaSource(source.Get(), options.Get(), &reader);
  }
  ComPtr<IMFMediaType> requested, current;
  if (SUCCEEDED(hr)) hr = MFCreateMediaType(&requested);
  if (SUCCEEDED(hr)) hr = requested->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (SUCCEEDED(hr)) hr = requested->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
  if (SUCCEEDED(hr)) {
    hr = reader->SetCurrentMediaType(DWORD(MF_SOURCE_READER_FIRST_VIDEO_STREAM),
                                     nullptr, requested.Get());
  }
  if (SUCCEEDED(hr)) {
    hr = reader->GetCurrentMediaType(DWORD(MF_SOURCE_READER_FIRST_VIDEO_STREAM),
                                     &current);
  }
  Log(L"source reader RGB32 output: 0x%08X", hr);
  if (FAILED(hr)) return 4;
  UINT32 width = 0, height = 0;
  MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &width, &height);
  const LONG stride = LONG(MFGetAttributeUINT32(current.Get(), MF_MT_DEFAULT_STRIDE, 0));
  Log(L"reader output: %ux%u default stride %ld", width, height, stride);
  if (width != kFixtureWidth || height != kFixtureHeight) return 4;

  const auto begin = std::chrono::steady_clock::now();
  ComPtr<IMFSample> last;
  int delivered = 0;
  for (int attempt = 0; delivered < frames && attempt < frames * 4; attempt++) {
    DWORD index = 0, flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    hr = reader->ReadSample(DWORD(MF_SOURCE_READER_FIRST_VIDEO_STREAM), 0, &index,
                            &flags, &timestamp, &sample);
    if (FAILED(hr)) {
      Log(L"ReadSample: 0x%08X after %d frames", hr, delivered);
      return 4;
    }
    if (flags & MF_SOURCE_READERF_ENDOFSTREAM) break;
    if (sample) {
      last = sample;
      delivered++;
    }
  }
  const double seconds = std::chrono::duration<double>(
                             std::chrono::steady_clock::now() - begin)
                             .count();
  Log(L"smoke: %d frames in %.2f s (%.1f fps)", delivered, seconds,
      seconds > 0 ? delivered / seconds : 0.0);
  if (delivered < frames || !last) return 4;

  std::vector<BYTE> frame;
  hr = CopyFrame(last.Get(), stride, frame);
  if (FAILED(hr)) {
    Log(L"copying the last frame: 0x%08X", hr);
    return 4;
  }
  const std::vector<BYTE> fixture = EmbeddedFixture();
  if (fixture.size() == frame.size()) {
    Log(L"mean |frame - fixture| per channel: as sent %.2f, mirrored %.2f, "
        L"flipped %.2f",
        Difference(frame, fixture, false, false),
        Difference(frame, fixture, true, false),
        Difference(frame, fixture, false, true));
  } else {
    Log(L"no embedded fixture to compare with");
  }
  if (bitmap) Log(WriteBitmap(bitmap, frame) ? L"saved %s" : L"could not save %s", bitmap);
  source->Shutdown();
  return 0;
}

bool HasFlag(int argc, wchar_t** argv, const wchar_t* flag) {
  for (int i = 2; i < argc; i++) {
    if (wcscmp(argv[i], flag) == 0) return true;
  }
  return false;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc < 2) {
    Log(L"usage: vcam_host start [--all-users] [--system] | start --auto | "
        L"list | smoke [frames] [frame.bmp]");
    return 1;
  }
  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (SUCCEEDED(hr)) hr = MFStartup(MF_VERSION);
  if (FAILED(hr)) {
    Log(L"Media Foundation startup: 0x%08X", hr);
    return 1;
  }
  const std::wstring command = argv[1];
  int code = 1;
  if (command == L"start") {
    code = HasFlag(argc, argv, L"--auto")
               ? Start({{false, false}, {true, false}, {true, true}})
               : Start({{HasFlag(argc, argv, L"--all-users"),
                         HasFlag(argc, argv, L"--system")}});
  } else if (command == L"list") {
    code = List();
  } else if (command == L"smoke") {
    code = Smoke(argc > 2 ? _wtoi(argv[2]) : 30, argc > 3 ? argv[3] : nullptr);
  } else {
    Log(L"unknown command %s", command.c_str());
  }
  MFShutdown();
  CoUninitialize();
  return code;
}
