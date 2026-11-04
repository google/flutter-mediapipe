// MediaPipe fixture camera: a Media Foundation custom media source that shows
// the licensed test portrait, so a hosted Windows runner has a real capture
// device for the gallery's real-camera test.
//
// Adapted from Microsoft's VirtualCamera sample, commit
// c1bd9e099f15c2ecf735216c7dd065cdb02a803f of
// https://github.com/microsoft/Windows-Camera, files
// Samples/VirtualCamera/VirtualCameraMediaSource/{SimpleMediaSource,
// SimpleMediaStream,SimpleFrameGenerator,VirtualCameraMediaSourceActivate}.
// Copyright (C) Microsoft Corporation. Licensed under the MIT License; see
// LICENSE-Microsoft.txt next to this file.
//
// Changes from the sample: one stream showing a still portrait instead of a
// moving gradient, RGB32 offered before NV12, frames paced at the declared
// rate, no custom KS property, no camera wrapping, and C++/WinRT and WIL
// replaced with WRL so it builds with the Windows SDK alone.

#include <unknwn.h>
#include <windows.h>
#include <propvarutil.h>
#include <ole2.h>
#include <initguid.h>
#include <ks.h>
#include <ksproxy.h>
#include <ksmedia.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfobjects.h>
#include <mferror.h>
#include <mfvirtualcamera.h>
#include <wrl/client.h>
#include <wrl/implements.h>

#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include "vcam.h"

namespace {

using Microsoft::WRL::ChainInterfaces;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::MakeAndInitialize;
using Microsoft::WRL::RuntimeClass;
using Microsoft::WRL::RuntimeClassFlags;

HMODULE g_module = nullptr;
LONG g_objects = 0;
LONG g_locks = 0;

constexpr LONGLONG kFrameDuration = 10'000'000LL / kFixtureFps;

// Counts live COM objects so DllCanUnloadNow can answer.
struct ObjectCount {
  ObjectCount() { InterlockedIncrement(&g_objects); }
  ~ObjectCount() { InterlockedDecrement(&g_objects); }
  ObjectCount(const ObjectCount&) = delete;
  ObjectCount& operator=(const ObjectCount&) = delete;
};

// The portrait letterboxed into the frame, top-down BGRX. A missing or
// mis-sized resource falls back to a grey ramp, so the camera still streams
// and a face test fails on the picture rather than here.
const std::vector<BYTE>& FixturePixels() {
  static const std::vector<BYTE> pixels = [] {
    std::vector<BYTE> out(size_t(kFixtureWidth) * kFixtureHeight * 4);
    HRSRC resource = FindResourceW(
        g_module, MAKEINTRESOURCEW(MEDIAPIPE_FIXTURE_RESOURCE), RT_RCDATA);
    HGLOBAL loaded = resource ? LoadResource(g_module, resource) : nullptr;
    const void* bytes = loaded ? LockResource(loaded) : nullptr;
    if (bytes && SizeofResource(g_module, resource) == out.size()) {
      std::memcpy(out.data(), bytes, out.size());
    } else {
      for (unsigned y = 0; y < kFixtureHeight; y++) {
        std::memset(out.data() + size_t(y) * kFixtureWidth * 4,
                    int(y * 255 / kFixtureHeight), size_t(kFixtureWidth) * 4);
      }
    }
    return out;
  }();
  return pixels;
}

// Writes one fixture frame into a locked buffer whose top row is `scan0`;
// `pitch` is negative for a bottom-up RGB buffer. NV12 uses the BT.601
// studio-range coefficients of the sample's SimpleFrameGenerator.
HRESULT WriteFrame(const GUID& subtype, BYTE* scan0, LONG pitch,
                   DWORD length) {
  const std::vector<BYTE>& bgrx = FixturePixels();
  const size_t row = size_t(kFixtureWidth) * 4;
  if (subtype == MFVideoFormat_RGB32) {
    if (length < size_t(std::labs(pitch)) * kFixtureHeight) {
      return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
    }
    for (unsigned y = 0; y < kFixtureHeight; y++) {
      std::memcpy(scan0 + ptrdiff_t(y) * pitch, bgrx.data() + y * row, row);
    }
    return S_OK;
  }
  if (subtype != MFVideoFormat_NV12) return MF_E_UNSUPPORTED_FORMAT;
  if (pitch <= 0 || length < size_t(pitch) * kFixtureHeight * 3 / 2) {
    return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
  }
  for (unsigned y = 0; y < kFixtureHeight; y++) {
    const BYTE* source = bgrx.data() + y * row;
    BYTE* luma = scan0 + ptrdiff_t(y) * pitch;
    for (unsigned x = 0; x < kFixtureWidth; x++) {
      const int b = source[x * 4], g = source[x * 4 + 1], r = source[x * 4 + 2];
      luma[x] = BYTE(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
    }
  }
  BYTE* chroma = scan0 + ptrdiff_t(kFixtureHeight) * pitch;
  for (unsigned y = 0; y < kFixtureHeight; y += 2) {
    const BYTE* source = bgrx.data() + y * row;
    BYTE* uv = chroma + ptrdiff_t(y / 2) * pitch;
    for (unsigned x = 0; x < kFixtureWidth; x += 2) {
      const int b = source[x * 4], g = source[x * 4 + 1], r = source[x * 4 + 2];
      uv[x] = BYTE(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
      uv[x + 1] = BYTE(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
    }
  }
  return S_OK;
}

HRESULT CreateVideoType(const GUID& subtype, UINT32 bitsPerPixel,
                        IMFMediaType** type) {
  ComPtr<IMFMediaType> created;
  HRESULT hr = MFCreateMediaType(&created);
  if (SUCCEEDED(hr)) hr = created->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (SUCCEEDED(hr)) hr = created->SetGUID(MF_MT_SUBTYPE, subtype);
  if (SUCCEEDED(hr)) {
    hr = created->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  }
  if (SUCCEEDED(hr)) hr = created->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE);
  if (SUCCEEDED(hr)) {
    hr = MFSetAttributeSize(created.Get(), MF_MT_FRAME_SIZE, kFixtureWidth,
                            kFixtureHeight);
  }
  if (SUCCEEDED(hr)) {
    hr = MFSetAttributeRatio(created.Get(), MF_MT_FRAME_RATE, kFixtureFps, 1);
  }
  if (SUCCEEDED(hr)) {
    hr = MFSetAttributeRatio(created.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
  }
  if (SUCCEEDED(hr)) {
    hr = created->SetUINT32(
        MF_MT_AVG_BITRATE,
        kFixtureWidth * kFixtureHeight * bitsPerPixel * kFixtureFps);
  }
  // Positive default stride: the RGB32 frames are top-down.
  if (SUCCEEDED(hr) && subtype == MFVideoFormat_RGB32) {
    hr = created->SetUINT32(MF_MT_DEFAULT_STRIDE, kFixtureWidth * 4);
  }
  if (SUCCEEDED(hr)) *type = created.Detach();
  return hr;
}

// The attributes Frame Server reads from a capture stream, set on both the
// stream and its descriptor as the sample does.
HRESULT SetDeviceStreamAttributes(IMFAttributes* attributes, DWORD id) {
  HRESULT hr =
      attributes->SetGUID(MF_DEVICESTREAM_STREAM_CATEGORY, PINNAME_VIDEO_CAPTURE);
  if (SUCCEEDED(hr)) hr = attributes->SetUINT32(MF_DEVICESTREAM_STREAM_ID, id);
  if (SUCCEEDED(hr)) {
    hr = attributes->SetUINT32(MF_DEVICESTREAM_FRAMESERVER_SHARED, 1);
  }
  if (SUCCEEDED(hr)) {
    hr = attributes->SetUINT32(MF_DEVICESTREAM_ATTRIBUTE_FRAMESOURCE_TYPES,
                               MFFrameSourceTypes_Color);
  }
  return hr;
}

class FixtureStream final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                          ChainInterfaces<IMFMediaStream2, IMFMediaStream,
                                          IMFMediaEventGenerator>> {
 public:
  HRESULT RuntimeClassInitialize(IMFMediaSource* parent, DWORD id) {
    std::lock_guard<std::mutex> lock(lock_);
    parent_ = parent;
    id_ = id;
    ComPtr<IMFMediaType> rgb32, nv12;
    HRESULT hr = CreateVideoType(MFVideoFormat_RGB32, 32, &rgb32);
    if (SUCCEEDED(hr)) hr = CreateVideoType(MFVideoFormat_NV12, 12, &nv12);
    if (SUCCEEDED(hr)) hr = MFCreateAttributes(&attributes_, 4);
    if (SUCCEEDED(hr)) hr = SetDeviceStreamAttributes(attributes_.Get(), id_);
    if (SUCCEEDED(hr)) hr = MFCreateEventQueue(&events_);
    // camera_desktop keeps the first of equally sized types, so RGB32 is
    // listed first and reaches its ARGB32 preview sink unconverted.
    IMFMediaType* types[] = {rgb32.Get(), nv12.Get()};
    if (SUCCEEDED(hr)) hr = MFCreateStreamDescriptor(id_, 2, types, &descriptor_);
    ComPtr<IMFMediaTypeHandler> handler;
    if (SUCCEEDED(hr)) hr = descriptor_->GetMediaTypeHandler(&handler);
    if (SUCCEEDED(hr)) hr = handler->SetCurrentMediaType(rgb32.Get());
    if (SUCCEEDED(hr)) hr = SetDeviceStreamAttributes(descriptor_.Get(), id_);
    return hr;
  }

  // IMFMediaEventGenerator
  IFACEMETHODIMP BeginGetEvent(IMFAsyncCallback* callback,
                               IUnknown* state) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : events_->BeginGetEvent(callback, state);
  }

  IFACEMETHODIMP EndGetEvent(IMFAsyncResult* result,
                             IMFMediaEvent** event) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : events_->EndGetEvent(result, event);
  }

  IFACEMETHODIMP GetEvent(DWORD flags, IMFMediaEvent** event) override {
    // GetEvent can block, so it must not hold the lock.
    ComPtr<IMFMediaEventQueue> events;
    {
      std::lock_guard<std::mutex> lock(lock_);
      HRESULT hr = CheckShutdown();
      if (FAILED(hr)) return hr;
      events = events_;
    }
    return events->GetEvent(flags, event);
  }

  IFACEMETHODIMP QueueEvent(MediaEventType type, REFGUID extended,
                            HRESULT status, const PROPVARIANT* value) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr
                      : events_->QueueEventParamVar(type, extended, status, value);
  }

  // IMFMediaStream
  IFACEMETHODIMP GetMediaSource(IMFMediaSource** source) override {
    if (!source) return E_POINTER;
    *source = nullptr;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : parent_.CopyTo(source);
  }

  IFACEMETHODIMP GetStreamDescriptor(
      IMFStreamDescriptor** descriptor) override {
    if (!descriptor) return E_POINTER;
    *descriptor = nullptr;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : descriptor_.CopyTo(descriptor);
  }

  // Frame Server pulls samples. A sensor would pace the pulls, so each
  // request waits for its slot at the declared rate instead of answering as
  // fast as it is asked.
  IFACEMETHODIMP RequestSample(IUnknown* token) override {
    LONGLONG wait = 0;
    {
      std::lock_guard<std::mutex> lock(lock_);
      HRESULT hr = CheckShutdown();
      if (FAILED(hr)) return hr;
      if (state_ != MF_STREAM_STATE_RUNNING) return MF_E_INVALIDREQUEST;
      const LONGLONG now = MFGetSystemTime();
      if (next_frame_ < now) next_frame_ = now;
      wait = next_frame_ - now;
      next_frame_ += kFrameDuration;
    }
    if (wait > 0) Sleep(DWORD(wait / 10'000));

    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (state_ != MF_STREAM_STATE_RUNNING) return MF_E_INVALIDREQUEST;
    ComPtr<IMFSample> sample;
    ComPtr<IMFMediaBuffer> buffer;
    ComPtr<IMF2DBuffer2> buffer2d;
    hr = allocator_->AllocateSample(&sample);
    if (SUCCEEDED(hr)) hr = sample->GetBufferByIndex(0, &buffer);
    if (SUCCEEDED(hr)) hr = buffer.As(&buffer2d);
    BYTE* scan0 = nullptr;
    BYTE* start = nullptr;
    LONG pitch = 0;
    DWORD length = 0;
    if (SUCCEEDED(hr)) {
      hr = buffer2d->Lock2DSize(MF2DBuffer_LockFlags_Write, &scan0, &pitch,
                                &start, &length);
      if (SUCCEEDED(hr)) {
        hr = WriteFrame(subtype_, scan0, pitch, length);
        buffer2d->Unlock2D();
      }
    }
    if (SUCCEEDED(hr)) hr = sample->SetSampleTime(MFGetSystemTime());
    if (SUCCEEDED(hr)) hr = sample->SetSampleDuration(kFrameDuration);
    if (SUCCEEDED(hr) && token) {
      hr = sample->SetUnknown(MFSampleExtension_Token, token);
    }
    if (SUCCEEDED(hr)) {
      hr = events_->QueueEventParamUnk(MEMediaSample, GUID_NULL, S_OK,
                                       sample.Get());
    }
    return hr;
  }

  // IMFMediaStream2
  IFACEMETHODIMP SetStreamState(MF_STREAM_STATE state) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr) || state_ == state) return hr;
    switch (state) {
      case MF_STREAM_STATE_PAUSED:
        if (state_ != MF_STREAM_STATE_RUNNING) {
          return MF_E_INVALID_STATE_TRANSITION;
        }
        state_ = MF_STREAM_STATE_PAUSED;
        return S_OK;
      case MF_STREAM_STATE_RUNNING:
        return StartLocked(false, nullptr);
      case MF_STREAM_STATE_STOPPED:
        return StopLocked(false);
      default:
        return MF_E_INVALID_STATE_TRANSITION;
    }
  }

  IFACEMETHODIMP GetStreamState(MF_STREAM_STATE* state) override {
    if (!state) return E_POINTER;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (SUCCEEDED(hr)) *state = state_;
    return hr;
  }

  // The source's Start selected this stream with `type`.
  HRESULT Start(IMFMediaType* type) {
    if (!type) return E_INVALIDARG;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : StartLocked(true, type);
  }

  HRESULT Stop(bool sendEvent) {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : StopLocked(sendEvent);
  }

  void Shutdown() {
    std::lock_guard<std::mutex> lock(lock_);
    shutdown_ = true;
    parent_.Reset();
    if (events_) {
      events_->Shutdown();
      events_.Reset();
    }
    attributes_.Reset();
    descriptor_.Reset();
    allocator_.Reset();
    type_.Reset();
    state_ = MF_STREAM_STATE_STOPPED;
  }

  HRESULT SetAllocator(IMFVideoSampleAllocator* allocator) {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (state_ == MF_STREAM_STATE_RUNNING) return MF_E_INVALIDREQUEST;
    allocator_ = allocator;
    return S_OK;
  }

  HRESULT GetAttributes(IMFAttributes** attributes) {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : attributes_.CopyTo(attributes);
  }

  DWORD Id() const { return id_; }

 private:
  HRESULT CheckShutdown() const {
    if (shutdown_) return MF_E_SHUTDOWN;
    return events_ ? S_OK : E_UNEXPECTED;
  }

  HRESULT StartLocked(bool sendEvent, IMFMediaType* type) {
    bool changed = false;
    if (type) {
      BOOL same = FALSE;
      if (type_) type_->Compare(type, MF_ATTRIBUTES_MATCH_ALL_ITEMS, &same);
      if (!same) {
        type_ = type;
        changed = true;
      }
    }
    if (!type_) return MF_E_INVALIDREQUEST;
    if (state_ != MF_STREAM_STATE_RUNNING || changed) {
      HRESULT hr = S_OK;
      // Frame Server hands over its allocator (UsesProvidedAllocator); an
      // in-process client that does not gets one of ours.
      if (!allocator_) hr = MFCreateVideoSampleAllocatorEx(IID_PPV_ARGS(&allocator_));
      if (SUCCEEDED(hr)) hr = allocator_->InitializeSampleAllocator(10, type_.Get());
      if (SUCCEEDED(hr)) hr = type_->GetGUID(MF_MT_SUBTYPE, &subtype_);
      if (FAILED(hr)) return hr;
    }
    if (sendEvent) {
      HRESULT hr =
          events_->QueueEventParamVar(MEStreamStarted, GUID_NULL, S_OK, nullptr);
      if (FAILED(hr)) return hr;
    }
    state_ = MF_STREAM_STATE_RUNNING;
    next_frame_ = 0;
    return S_OK;
  }

  HRESULT StopLocked(bool sendEvent) {
    state_ = MF_STREAM_STATE_STOPPED;
    return sendEvent ? events_->QueueEventParamVar(MEStreamStopped, GUID_NULL,
                                                   S_OK, nullptr)
                     : S_OK;
  }

  ObjectCount count_;
  std::mutex lock_;
  ComPtr<IMFMediaSource> parent_;
  ComPtr<IMFMediaEventQueue> events_;
  ComPtr<IMFAttributes> attributes_;
  ComPtr<IMFStreamDescriptor> descriptor_;
  ComPtr<IMFVideoSampleAllocator> allocator_;
  ComPtr<IMFMediaType> type_;
  GUID subtype_ = GUID_NULL;
  MF_STREAM_STATE state_ = MF_STREAM_STATE_STOPPED;
  LONGLONG next_frame_ = 0;
  DWORD id_ = 0;
  bool shutdown_ = false;
};

class FixtureSource final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                          ChainInterfaces<IMFMediaSourceEx, IMFMediaSource,
                                          IMFMediaEventGenerator>,
                          IMFGetService, IKsControl, IMFSampleAllocatorControl> {
 public:
  HRESULT RuntimeClassInitialize(IMFAttributes* activation) {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CreateSourceAttributes(activation);
    if (SUCCEEDED(hr)) hr = MFCreateEventQueue(&events_);
    if (SUCCEEDED(hr)) hr = MakeAndInitialize<FixtureStream>(&stream_, this, 0);
    ComPtr<IMFStreamDescriptor> descriptor;
    if (SUCCEEDED(hr)) hr = stream_->GetStreamDescriptor(&descriptor);
    IMFStreamDescriptor* descriptors[] = {descriptor.Get()};
    if (SUCCEEDED(hr)) {
      hr = MFCreatePresentationDescriptor(1, descriptors, &presentation_);
    }
    if (SUCCEEDED(hr)) state_ = State::Stopped;
    return hr;
  }

  // IMFMediaEventGenerator
  IFACEMETHODIMP BeginGetEvent(IMFAsyncCallback* callback,
                               IUnknown* state) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : events_->BeginGetEvent(callback, state);
  }

  IFACEMETHODIMP EndGetEvent(IMFAsyncResult* result,
                             IMFMediaEvent** event) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : events_->EndGetEvent(result, event);
  }

  IFACEMETHODIMP GetEvent(DWORD flags, IMFMediaEvent** event) override {
    ComPtr<IMFMediaEventQueue> events;
    {
      std::lock_guard<std::mutex> lock(lock_);
      HRESULT hr = CheckShutdown();
      if (FAILED(hr)) return hr;
      events = events_;
    }
    return events->GetEvent(flags, event);
  }

  IFACEMETHODIMP QueueEvent(MediaEventType type, REFGUID extended,
                            HRESULT status, const PROPVARIANT* value) override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr
                      : events_->QueueEventParamVar(type, extended, status, value);
  }

  // IMFMediaSource
  IFACEMETHODIMP CreatePresentationDescriptor(
      IMFPresentationDescriptor** descriptor) override {
    if (!descriptor) return E_POINTER;
    *descriptor = nullptr;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    return FAILED(hr) ? hr : presentation_->Clone(descriptor);
  }

  IFACEMETHODIMP GetCharacteristics(DWORD* characteristics) override {
    if (!characteristics) return E_POINTER;
    *characteristics = 0;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (SUCCEEDED(hr)) *characteristics = MFMEDIASOURCE_IS_LIVE;
    return hr;
  }

  IFACEMETHODIMP Pause() override { return MF_E_INVALID_STATE_TRANSITION; }

  IFACEMETHODIMP Shutdown() override {
    std::lock_guard<std::mutex> lock(lock_);
    state_ = State::Shutdown;
    attributes_.Reset();
    presentation_.Reset();
    if (events_) {
      events_->Shutdown();
      events_.Reset();
    }
    if (stream_) {
      stream_->Shutdown();
      stream_.Reset();
    }
    return S_OK;
  }

  IFACEMETHODIMP Start(IMFPresentationDescriptor* descriptor,
                       const GUID* timeFormat,
                       const PROPVARIANT* startPosition) override {
    if (!descriptor || !startPosition) return E_INVALIDARG;
    if (timeFormat && *timeFormat != GUID_NULL) {
      return MF_E_UNSUPPORTED_TIME_FORMAT;
    }
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (state_ == State::Invalid) return MF_E_INVALID_STATE_TRANSITION;
    DWORD count = 0;
    hr = descriptor->GetStreamDescriptorCount(&count);
    if (FAILED(hr)) return hr;
    if (count != 1) return E_INVALIDARG;
    BOOL selected = FALSE;
    ComPtr<IMFStreamDescriptor> requested;
    hr = descriptor->GetStreamDescriptorByIndex(0, &selected, &requested);
    DWORD id = 0;
    if (SUCCEEDED(hr)) hr = requested->GetStreamIdentifier(&id);
    if (SUCCEEDED(hr) && id != stream_->Id()) hr = MF_E_NOT_FOUND;
    BOOL wasSelected = FALSE;
    ComPtr<IMFStreamDescriptor> ours;
    if (SUCCEEDED(hr)) {
      hr = presentation_->GetStreamDescriptorByIndex(0, &wasSelected, &ours);
    }
    if (FAILED(hr)) return hr;
    if (selected) {
      // Announce the stream, then start it, which sends MEStreamStarted.
      ComPtr<IMFMediaTypeHandler> handler;
      ComPtr<IMFMediaType> type;
      ComPtr<IUnknown> stream;
      hr = presentation_->SelectStream(0);
      if (SUCCEEDED(hr)) hr = requested->GetMediaTypeHandler(&handler);
      if (SUCCEEDED(hr)) hr = handler->GetCurrentMediaType(&type);
      if (SUCCEEDED(hr)) hr = stream_.As(&stream);
      if (SUCCEEDED(hr)) {
        hr = events_->QueueEventParamUnk(wasSelected ? MEUpdatedStream
                                                     : MENewStream,
                                         GUID_NULL, S_OK, stream.Get());
      }
      if (SUCCEEDED(hr)) hr = stream_->Start(type.Get());
    } else if (wasSelected) {
      hr = presentation_->DeselectStream(0);
      if (SUCCEEDED(hr)) hr = stream_->Stop(false);
    }
    PROPVARIANT time;
    if (SUCCEEDED(hr)) hr = InitPropVariantFromInt64(MFGetSystemTime(), &time);
    if (SUCCEEDED(hr)) {
      hr = events_->QueueEventParamVar(MESourceStarted, GUID_NULL, S_OK, &time);
      PropVariantClear(&time);
    }
    if (SUCCEEDED(hr)) state_ = State::Started;
    return hr;
  }

  IFACEMETHODIMP Stop() override {
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (state_ != State::Started) return MF_E_INVALID_STATE_TRANSITION;
    state_ = State::Stopped;
    hr = stream_->Stop(true);
    if (SUCCEEDED(hr)) hr = presentation_->DeselectStream(0);
    PROPVARIANT time;
    if (SUCCEEDED(hr)) hr = InitPropVariantFromInt64(MFGetSystemTime(), &time);
    if (SUCCEEDED(hr)) {
      hr = events_->QueueEventParamVar(MESourceStopped, GUID_NULL, S_OK, &time);
      PropVariantClear(&time);
    }
    return hr;
  }

  // IMFMediaSourceEx
  IFACEMETHODIMP GetSourceAttributes(IMFAttributes** attributes) override {
    if (!attributes) return E_POINTER;
    *attributes = nullptr;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    // A capture source hands out its own store, not a copy.
    return FAILED(hr) ? hr : attributes_.CopyTo(attributes);
  }

  IFACEMETHODIMP GetStreamAttributes(DWORD id,
                                     IMFAttributes** attributes) override {
    if (!attributes) return E_POINTER;
    *attributes = nullptr;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (id != stream_->Id()) return MF_E_NOT_FOUND;
    return stream_->GetAttributes(attributes);
  }

  // Media Foundation ignores the result; frames are always in system memory.
  IFACEMETHODIMP SetD3DManager(IUnknown*) override { return E_NOTIMPL; }

  // IMFGetService
  IFACEMETHODIMP GetService(REFGUID, REFIID, void** object) override {
    if (!object) return E_POINTER;
    *object = nullptr;
    return MF_E_UNSUPPORTED_SERVICE;
  }

  // IKsControl: no controls, answered the way a driver without handlers is.
  IFACEMETHODIMP KsProperty(PKSPROPERTY property, ULONG propertyLength, LPVOID,
                            ULONG, ULONG* bytesReturned) override {
    if (!property || propertyLength < sizeof(KSPROPERTY)) return E_INVALIDARG;
    if (bytesReturned) *bytesReturned = 0;
    return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND);
  }

  IFACEMETHODIMP KsMethod(PKSMETHOD, ULONG, LPVOID, ULONG, ULONG*) override {
    return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND);
  }

  IFACEMETHODIMP KsEvent(PKSEVENT, ULONG, LPVOID, ULONG, ULONG*) override {
    return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND);
  }

  // IMFSampleAllocatorControl
  IFACEMETHODIMP SetDefaultAllocator(DWORD id, IUnknown* allocator) override {
    if (!allocator) return E_POINTER;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (id != stream_->Id()) return MF_E_NOT_FOUND;
    ComPtr<IMFVideoSampleAllocator> video;
    hr = allocator->QueryInterface(IID_PPV_ARGS(&video));
    return FAILED(hr) ? hr : stream_->SetAllocator(video.Get());
  }

  IFACEMETHODIMP GetAllocatorUsage(DWORD id, DWORD* inputStream,
                                   MFSampleAllocatorUsage* usage) override {
    if (!inputStream || !usage) return E_POINTER;
    std::lock_guard<std::mutex> lock(lock_);
    HRESULT hr = CheckShutdown();
    if (FAILED(hr)) return hr;
    if (id != stream_->Id()) return MF_E_NOT_FOUND;
    *inputStream = id;
    *usage = MFSampleAllocatorUsage_UsesProvidedAllocator;
    return S_OK;
  }

 private:
  enum class State { Invalid, Stopped, Started, Shutdown };

  HRESULT CheckShutdown() const {
    if (state_ == State::Shutdown) return MF_E_SHUTDOWN;
    return events_ && stream_ ? S_OK : E_UNEXPECTED;
  }

  HRESULT CreateSourceAttributes(IMFAttributes* activation) {
    HRESULT hr = MFCreateAttributes(&attributes_, 4);
    if (SUCCEEDED(hr) && activation) hr = activation->CopyAllItems(attributes_.Get());
    // The legacy profile is mandatory, so profile-unaware apps still work;
    // the high-frame-rate one is kept from the sample.
    ComPtr<IMFSensorProfileCollection> profiles;
    ComPtr<IMFSensorProfile> profile;
    if (SUCCEEDED(hr)) hr = MFCreateSensorProfileCollection(&profiles);
    if (SUCCEEDED(hr)) {
      hr = MFCreateSensorProfile(KSCAMERAPROFILE_Legacy, 0, nullptr, &profile);
    }
    if (SUCCEEDED(hr)) hr = profile->AddProfileFilter(0, L"((RES==;FRT<=30,1;SUT==))");
    if (SUCCEEDED(hr)) hr = profiles->AddProfile(profile.Get());
    if (SUCCEEDED(hr)) {
      profile.Reset();
      hr = MFCreateSensorProfile(KSCAMERAPROFILE_HighFrameRate, 0, nullptr,
                                 &profile);
    }
    if (SUCCEEDED(hr)) hr = profile->AddProfileFilter(0, L"((RES==;FRT>=60,1;SUT==))");
    if (SUCCEEDED(hr)) hr = profiles->AddProfile(profile.Get());
    if (SUCCEEDED(hr)) {
      hr = attributes_->SetUnknown(MF_DEVICEMFT_SENSORPROFILE_COLLECTION,
                                   profiles.Get());
    }
    return hr;
  }

  ObjectCount count_;
  std::mutex lock_;
  State state_ = State::Invalid;
  ComPtr<IMFMediaEventQueue> events_;
  ComPtr<IMFPresentationDescriptor> presentation_;
  ComPtr<IMFAttributes> attributes_;
  ComPtr<FixtureStream> stream_;
};

// What Frame Server creates from the registered CLSID: an attribute store it
// fills with the virtual camera's attributes, and ActivateObject for the
// source.
class FixtureActivate final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>,
                          ChainInterfaces<IMFActivate, IMFAttributes>> {
 public:
  HRESULT RuntimeClassInitialize() { return MFCreateAttributes(&attributes_, 4); }

  // IMFActivate
  IFACEMETHODIMP ActivateObject(REFIID riid, void** object) override {
    if (!object) return E_POINTER;
    *object = nullptr;
    ComPtr<FixtureSource> source;
    HRESULT hr = MakeAndInitialize<FixtureSource>(&source, attributes_.Get());
    if (SUCCEEDED(hr)) hr = source.CopyTo(riid, object);
    if (SUCCEEDED(hr)) source_ = source;
    return hr;
  }

  IFACEMETHODIMP ShutdownObject() override { return S_OK; }

  IFACEMETHODIMP DetachObject() override {
    source_.Reset();
    return S_OK;
  }

  // IMFAttributes, delegated to the store.
  IFACEMETHODIMP GetItem(REFGUID key, PROPVARIANT* value) override {
    return attributes_->GetItem(key, value);
  }
  IFACEMETHODIMP GetItemType(REFGUID key, MF_ATTRIBUTE_TYPE* type) override {
    return attributes_->GetItemType(key, type);
  }
  IFACEMETHODIMP CompareItem(REFGUID key, REFPROPVARIANT value,
                             BOOL* result) override {
    return attributes_->CompareItem(key, value, result);
  }
  IFACEMETHODIMP Compare(IMFAttributes* theirs, MF_ATTRIBUTES_MATCH_TYPE type,
                         BOOL* result) override {
    return attributes_->Compare(theirs, type, result);
  }
  IFACEMETHODIMP GetUINT32(REFGUID key, UINT32* value) override {
    return attributes_->GetUINT32(key, value);
  }
  IFACEMETHODIMP GetUINT64(REFGUID key, UINT64* value) override {
    return attributes_->GetUINT64(key, value);
  }
  IFACEMETHODIMP GetDouble(REFGUID key, double* value) override {
    return attributes_->GetDouble(key, value);
  }
  IFACEMETHODIMP GetGUID(REFGUID key, GUID* value) override {
    return attributes_->GetGUID(key, value);
  }
  IFACEMETHODIMP GetStringLength(REFGUID key, UINT32* length) override {
    return attributes_->GetStringLength(key, length);
  }
  IFACEMETHODIMP GetString(REFGUID key, LPWSTR value, UINT32 size,
                           UINT32* length) override {
    return attributes_->GetString(key, value, size, length);
  }
  IFACEMETHODIMP GetAllocatedString(REFGUID key, LPWSTR* value,
                                    UINT32* length) override {
    return attributes_->GetAllocatedString(key, value, length);
  }
  IFACEMETHODIMP GetBlobSize(REFGUID key, UINT32* size) override {
    return attributes_->GetBlobSize(key, size);
  }
  IFACEMETHODIMP GetBlob(REFGUID key, UINT8* buffer, UINT32 size,
                         UINT32* written) override {
    return attributes_->GetBlob(key, buffer, size, written);
  }
  IFACEMETHODIMP GetAllocatedBlob(REFGUID key, UINT8** buffer,
                                  UINT32* size) override {
    return attributes_->GetAllocatedBlob(key, buffer, size);
  }
  IFACEMETHODIMP GetUnknown(REFGUID key, REFIID riid, LPVOID* object) override {
    return attributes_->GetUnknown(key, riid, object);
  }
  IFACEMETHODIMP SetItem(REFGUID key, REFPROPVARIANT value) override {
    return attributes_->SetItem(key, value);
  }
  IFACEMETHODIMP DeleteItem(REFGUID key) override {
    return attributes_->DeleteItem(key);
  }
  IFACEMETHODIMP DeleteAllItems() override { return attributes_->DeleteAllItems(); }
  IFACEMETHODIMP SetUINT32(REFGUID key, UINT32 value) override {
    return attributes_->SetUINT32(key, value);
  }
  IFACEMETHODIMP SetUINT64(REFGUID key, UINT64 value) override {
    return attributes_->SetUINT64(key, value);
  }
  IFACEMETHODIMP SetDouble(REFGUID key, double value) override {
    return attributes_->SetDouble(key, value);
  }
  IFACEMETHODIMP SetGUID(REFGUID key, REFGUID value) override {
    return attributes_->SetGUID(key, value);
  }
  IFACEMETHODIMP SetString(REFGUID key, LPCWSTR value) override {
    return attributes_->SetString(key, value);
  }
  IFACEMETHODIMP SetBlob(REFGUID key, const UINT8* buffer, UINT32 size) override {
    return attributes_->SetBlob(key, buffer, size);
  }
  IFACEMETHODIMP SetUnknown(REFGUID key, IUnknown* value) override {
    return attributes_->SetUnknown(key, value);
  }
  IFACEMETHODIMP LockStore() override { return attributes_->LockStore(); }
  IFACEMETHODIMP UnlockStore() override { return attributes_->UnlockStore(); }
  IFACEMETHODIMP GetCount(UINT32* count) override {
    return attributes_->GetCount(count);
  }
  IFACEMETHODIMP GetItemByIndex(UINT32 index, GUID* key,
                                PROPVARIANT* value) override {
    return attributes_->GetItemByIndex(index, key, value);
  }
  IFACEMETHODIMP CopyAllItems(IMFAttributes* destination) override {
    return attributes_->CopyAllItems(destination);
  }

 private:
  ObjectCount count_;
  ComPtr<IMFAttributes> attributes_;
  ComPtr<FixtureSource> source_;
};

class ActivateFactory final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IClassFactory> {
 public:
  IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid,
                                void** object) override {
    if (!object) return E_POINTER;
    *object = nullptr;
    if (outer) return CLASS_E_NOAGGREGATION;
    ComPtr<FixtureActivate> activate;
    HRESULT hr = MakeAndInitialize<FixtureActivate>(&activate);
    return FAILED(hr) ? hr : activate.CopyTo(riid, object);
  }

  IFACEMETHODIMP LockServer(BOOL lock) override {
    if (lock) {
      InterlockedIncrement(&g_locks);
    } else {
      InterlockedDecrement(&g_locks);
    }
    return S_OK;
  }

 private:
  ObjectCount count_;
};

const std::wstring kClassKey =
    std::wstring(L"Software\\Classes\\CLSID\\") + MEDIAPIPE_FIXTURE_CAMERA_CLSID;

LSTATUS SetString(HKEY key, const wchar_t* name, const wchar_t* value) {
  return RegSetValueExW(key, name, 0, REG_SZ,
                        reinterpret_cast<const BYTE*>(value),
                        DWORD((wcslen(value) + 1) * sizeof(wchar_t)));
}

}  // namespace

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    g_module = module;
    DisableThreadLibraryCalls(module);
  }
  return TRUE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, LPVOID* object) {
  if (!object) return E_POINTER;
  *object = nullptr;
  if (clsid != CLSID_MediaPipeFixtureCamera) return CLASS_E_CLASSNOTAVAILABLE;
  ComPtr<ActivateFactory> factory = Microsoft::WRL::Make<ActivateFactory>();
  return factory ? factory.CopyTo(riid, object) : E_OUTOFMEMORY;
}

STDAPI DllCanUnloadNow() {
  return g_objects == 0 && g_locks == 0 ? S_OK : S_FALSE;
}

// Registers under HKLM, where the Frame Server services look for it.
STDAPI DllRegisterServer() {
  wchar_t path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(g_module, path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) return HRESULT_FROM_WIN32(GetLastError());
  HKEY clsid = nullptr, server = nullptr;
  LSTATUS status = RegCreateKeyExW(HKEY_LOCAL_MACHINE, kClassKey.c_str(), 0,
                                   nullptr, 0, KEY_WRITE, nullptr, &clsid,
                                   nullptr);
  if (status == ERROR_SUCCESS) {
    status = SetString(clsid, nullptr, L"MediaPipe fixture camera media source");
  }
  if (status == ERROR_SUCCESS) {
    status = RegCreateKeyExW(clsid, L"InprocServer32", 0, nullptr, 0, KEY_WRITE,
                             nullptr, &server, nullptr);
  }
  if (status == ERROR_SUCCESS) status = SetString(server, nullptr, path);
  if (status == ERROR_SUCCESS) status = SetString(server, L"ThreadingModel", L"Both");
  if (server) RegCloseKey(server);
  if (clsid) RegCloseKey(clsid);
  return HRESULT_FROM_WIN32(status);
}

STDAPI DllUnregisterServer() {
  const LSTATUS status = RegDeleteTreeW(HKEY_LOCAL_MACHINE, kClassKey.c_str());
  return status == ERROR_FILE_NOT_FOUND ? S_OK : HRESULT_FROM_WIN32(status);
}
