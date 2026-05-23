# JUCE Adapter Boundary Example

This is an example boundary, not a product mandate.

## Good shape

```text
juce::AudioIODeviceCallback or juce::AudioProcessor::processBlock
  create stack-local AudioBlockView
  read prepared snapshot pointer
  drain fixed-capacity event queue up to max events
  call RealtimeAudioCore::process
  publish tiny MeterSnapshot
```

## Adapter rules

- JUCE owns device/plugin plumbing.
- The realtime core does not depend on JUCE types.
- Callback code does not call UI, AsyncUpdater, logging, file I/O, parser code, graph mutation, route discovery, or buffer resizing.
- `prepareToPlay` or equivalent prepares all core state before processing.
- Variable block sizes are accepted.
