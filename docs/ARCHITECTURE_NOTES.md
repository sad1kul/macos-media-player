# Architecture Notes

## Strategy

This project extends VLC rather than wrapping libVLC in a separate desktop application.

That means the existing VLC media pipeline remains authoritative for:

- demuxing;
- decoding;
- subtitles;
- audio;
- network playback;
- hardware acceleration;
- rendering;
- playback state.

Our work should primarily extend the macOS application layer.

## macOS direction

Use existing VLC macOS/AppKit integration wherever practical.

The first major feature is an advanced floating player. The preferred design is to keep one playback session and move or reattach the existing video presentation surface when switching between the main and floating windows.

Avoid creating a second decoder/player solely for floating mode.

Conceptually:

```
Main window
    |
    | enter floating mode
    v
Floating window

Same playback session
Same media position
Same audio session
Same decoder
```

## Hardware acceleration

Preserve VLC's existing macOS hardware-decoding path.

Do not bypass native decoding by extracting frames into application-managed buffers unless a future feature specifically requires it and the performance cost is justified.

## Upstream compatibility

Prefer isolated macOS additions over broad core modifications.

If a feature can be implemented in the macOS interface layer without changing VLC core behaviour, that is normally preferable.

## Decision records

When a future architectural choice materially affects upstream compatibility, performance or playback ownership, add a short record under:

`docs/decisions/`

Keep records concise and factual.
