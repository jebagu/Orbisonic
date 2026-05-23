# Native Backend Adapter Boundary Example

This is an example boundary, not a product mandate.

## Good shape

```text
Core Audio / ASIO / JACK / WASAPI / ALSA callback
  normalize buffer pointers to AudioBlockView
  normalize stream time
  read prepared route/render snapshot
  drain fixed-capacity event queue
  call RealtimeAudioCore::process
  publish tiny MeterSnapshot
```

## Adapter rules

- Native device APIs may be used for maximum control.
- Direct device access does not weaken callback doctrine.
- Device enumeration and route validation happen before arming.
- Device loss and recovery happen outside realtime.
- Callback code does not allocate, lock, wait, log, call UI, parse, or discover devices.
