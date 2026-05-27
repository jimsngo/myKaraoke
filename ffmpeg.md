# FFmpeg Overview

FFmpeg is a powerful open-source multimedia framework used to record, convert, stream, and process audio and video files. It supports a wide range of formats and codecs, making it a popular tool for media manipulation.

## Key Features
- Convert between different audio and video formats
- Extract audio from video files
- Resize, crop, and overlay videos
- Stream media over networks
- Apply filters and effects
- Combine multiple media files

## Common Usage Examples
### 1. Convert Video Format
```
ffmpeg -i input.mp4 output.avi
```

### 2. Extract Audio from Video
```
ffmpeg -i input.mp4 -q:a 0 -map a output.mp3
```

### 3. Overlay Image on Video
```
ffmpeg -i background.mp4 -i overlay.png -filter_complex "[0:v][1:v] overlay=0:0" output.mp4
```

### 4. Resize Video
```
ffmpeg -i input.mp4 -vf scale=1280:720 output.mp4
```

## Installation on macOS
The easiest way to install FFmpeg on macOS is using Homebrew:
```
brew install ffmpeg
```

## Documentation & Resources
- [Official FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [FFmpeg Wiki](https://trac.ffmpeg.org/wiki)
- [FFmpeg Examples](https://ffmpeg.org/ffmpeg.html)

## Basic Command Structure
```
ffmpeg [options] -i input_file [options] output_file
```

## Useful Links
- [FFmpeg GitHub](https://github.com/FFmpeg/FFmpeg)
- [FFmpeg Filters Documentation](https://ffmpeg.org/ffmpeg-filters.html)

---
FFmpeg is a command-line tool, but it can be integrated into scripts and applications for automated media processing.