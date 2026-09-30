# macOS Roadmap

## Phase 0 — Baseline

- Build the unmodified fork on Apple Silicon.
- Confirm normal VLC playback.
- Confirm subtitles and audio-track selection.
- Confirm H.264 and HEVC playback.
- Record the upstream commit used as the starting baseline.

Exit condition: upstream VLC builds and plays media correctly before project-specific changes.

## Phase 1 — macOS architecture study

Document:

- the existing macOS main-window controller;
- video rendering ownership;
- current mini-player / fullscreen paths;
- playback state flow;
- preference storage;
- hardware-decoding configuration;
- relevant AppKit window behaviour.

Exit condition: we can identify the smallest integration point for the floating player.

## Phase 2 — Floating player

Implement:

- always-on-top behaviour;
- borderless presentation;
- drag and resize;
- aspect-ratio preservation;
- edge/corner snapping;
- remembered position and size;
- hover controls;
- return to main player;
- multi-monitor behaviour;
- macOS Spaces behaviour.

The active playback session must continue without restarting media.

## Phase 3 — Playback diagnostics

Expose reliable information where available:

- codec;
- resolution;
- frame rate;
- decoder/backend;
- dropped frames;
- hardware acceleration status when it can be confirmed accurately.

Do not display guessed hardware-decoder status.

## Phase 4 — macOS quality-of-life

Candidate features:

- improved resume behaviour;
- persistent bookmarks;
- timestamped notes;
- cleaner subtitle/audio switching;
- configurable global shortcuts;
- trackpad-friendly seeking;
- improved recent-media behaviour;
- screenshot naming with media title and timestamp.

## Phase 5 — Advanced floating mode

Candidate features:

- opacity;
- click-through;
- size presets;
- automatic corner placement;
- compact audio-only mode;
- floating transcript/subtitle panel.

## Later

Only after the core player is stable:

- subtitle discovery;
- searchable subtitles/transcripts;
- clip/GIF export;
- automatic chapter tools;
- network-media UX improvements;
- optional AI-assisted features.
