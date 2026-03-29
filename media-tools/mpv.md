# MPV Media Player Overview

mpv is a free, open-source, and lightweight media player that runs in the terminal and supports a wide range of audio and video formats. It is a fork of mplayer and mplayer2, offering improved performance, modern features, and active development.

## Key Features
- Plays almost any audio/video format
- Minimal dependencies and fast startup
- Terminal-based playback (no GUI required)
- Hardware acceleration support
- Scripting and configuration via config files
- Stream media from URLs

## Common Usage Examples
### 1. Play a Video File
```
mpv video.mp4
```

### 2. Play an Audio File
```
mpv song.mp3
```

### 3. Stream Online Video
```
mpv https://www.youtube.com/watch?v=example
```

### 4. Loop Playback
```
mpv --loop file.mp3
```

### 5. Play Without Video (Audio Only)
```
mpv --no-video file.mp4
```

## Installation on macOS
Install mpv using Homebrew:
```
brew install mpv
```

## Documentation & Resources
- [Official mpv Documentation](https://mpv.io/manual/stable/)
- [mpv GitHub](https://github.com/mpv-player/mpv)
- [mpv Wiki](https://wiki.archlinux.org/title/Mpv)

## Basic Command Structure
```
mpv [options] file
```

---
mpv is ideal for users who want a fast, simple, and scriptable media player for terminal use.