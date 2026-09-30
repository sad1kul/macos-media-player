# Project Direction

## Purpose

This repository is a macOS-focused fork of VLC media player. The goal is to preserve VLC's mature playback capabilities while improving the macOS desktop experience.

The project is independently maintained and is not an official VideoLAN product.

## Upstream

- Upstream project: VideoLAN VLC
- GitHub mirror: https://github.com/videolan/vlc
- Canonical project: https://code.videolan.org/videolan/vlc
- Local development should keep the original VLC repository configured as the `upstream` remote.

## Product priorities

1. Preserve VLC playback compatibility and stability.
2. Keep hardware-accelerated playback working on Apple Silicon.
3. Build a first-class macOS floating player / PiP-style experience.
4. Improve macOS windowing, multi-monitor, Spaces, keyboard and trackpad behaviour.
5. Add practical quality-of-life features such as persistent bookmarks, resume, better subtitle workflows and playback diagnostics.
6. Keep changes easy to reconcile with upstream VLC.

## Non-goals for the first development cycle

- Rewriting VLC's media engine.
- Large directory reorganisations.
- Broad cross-platform redesigns.
- AI features.
- Cloud accounts or sync.
- Replacing stable upstream code without a concrete reason.

## First release target

The first usable alpha should:

- build and run on Apple Silicon macOS;
- preserve normal VLC playback;
- support H.264 and HEVC playback with existing hardware acceleration;
- support subtitles and multiple audio tracks;
- provide an always-on-top floating player;
- move between the main window and floating player without restarting playback;
- behave correctly across multiple monitors and macOS Spaces where the platform permits.
