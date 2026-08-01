# LyricSub

A lightweight, headless background extension for VLC Media Player that automatically fetches synchronized lyrics from LRCLIB and injects them as subtitles in real time.

Uses **LRCLIB (https://lrclib.net/)**, a free and open source database for plain and synchronized song lyrics.

## Installation

1. Download the `lyricsub.lua` file from this repository.
2. Place it into your VLC extensions directory:
   - **Windows (All Users):** `C:\Program Files\VideoLAN\VLC\lua\extensions\`
   - **Windows (Current User):** `%APPDATA%\vlc\lua\extensions\`
   - **Linux:** `~/.local/share/vlc/lua/extensions/` or `/usr/share/vlc/lua/extensions/`
   - **macOS:** `/Applications/VLC.app/Contents/MacOS/share/lua/extensions/`
3. Restart VLC Media Player.

## Usage

1. In the header, open **View** dropdown.
2. Enable **LyricSub**.

and you're ready to jam!

### Note:

Due to the limitations of VLC, subtitles are not visible with audio files. A workaround for this is to enable Visualizations for audio files.

1. In the header, go to **Audio** -> **Visualizations**.
2. Choose any visualization (eg. `Spectrometer`).

The extension supports Intelligent Matching, i.e., it can use the embedded ID3 tags in audio file (like an `.mp3` or `.flac`) to fetch the artist and title. If the file lacks metadata or tag, it fallbacks to filename search. The format of filename should follow:

#### `<Artist> - <Title>.<ext>` (Example: `Linkin Park - Numb.mp3`)
