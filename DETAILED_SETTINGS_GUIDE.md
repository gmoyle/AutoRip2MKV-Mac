# Settings Guide for Spindle

This guide covers every setting in Spindle v2.1. Settings are saved as soon as
you click **OK** and are stored in macOS user defaults.

Open the Settings window with **Settings…** in the main window. It has three tabs:
**Output & Routing**, **Encoding**, and **Advanced**. **Restore Defaults** resets all
of them.

> **Re-ripping after a settings change**: the app remembers which settings each disc
> was ripped with. If you change a setting that affects the output (codec, quality,
> bonus features, and so on), a disc you've already ripped is ripped again the next
> time you insert it.

## Main window

These options are on the main window itself, not in Settings.

| Option | Default | What it does |
|--------|---------|--------------|
| **Output** (Browse) | Your Plex movie library if one is found | Where rips are written before routing |
| **Auto-rip inserted discs** | On | Start ripping as soon as a disc is detected |
| **Auto-eject after ripping** | On | Eject when the disc read finishes; encoding continues in the background |
| **Skip discs already ripped** | On | Skip and eject a disc already ripped with the current settings. Hold **⌥ Option** while inserting to rip it anyway |

A disc is ripped again, even with skipping on, if you deleted the folder its rip was
recorded in. A folder on a drive or NAS that isn't connected still counts as ripped.

## Output & Routing tab

### Content Routing (Plex libraries)

| Option | Default | What it does |
|--------|---------|--------------|
| **Sort rips into Movies / TV Shows folders by content** | On | After a rip, classify it from its title lengths (one long feature means a movie; several similar-length titles mean a TV season) and move it to the matching folder |
| **Auto-route confident guesses** | On | Move confident guesses straight away. Unsure rips wait under **Review Rips** in the main window, where you choose Movie or TV for each |
| **Movies Folder** | `~/Plex/Movies` | Library folder for movies |
| **TV Shows Folder** | `~/Plex/TVShows` | Library folder for TV seasons |

Library folders can be on a NAS. Moves to another volume copy each file under a hidden
name and rename it when complete, so Plex never picks up a partial file. Ripping the
same disc again replaces its files in the existing library folder; other files you
put there (posters, subtitles) are left alone.

### File Storage

**Directory Structure** decides the folder layout under the output folder:

| Choice | Layout |
|--------|--------|
| Flat | `<output>/Title (Year)/` |
| By Media Type (default) | `<output>/Movies/Title (Year)/` or `<output>/TV Shows/Title/` |
| By Year | `<output>/1985/Title (Year)/`; falls back to By Media Type when the year is unknown |
| By Genre | `<output>/Unknown/Title (Year)/`; genre isn't known at rip time |
| Custom | The **Movie Directory Format** and **TV Show Directory Format** templates below |

Custom templates (defaults `Movies/{title} ({year})` and `TV Shows/{series}`) support
`{title}` and `{year}`. A path segment that uses any other token is dropped.

Titles come from an OMDb lookup on the disc's name, giving Plex-style
`Movie (Year)/Movie (Year).mkv` names.

## Encoding tab

### Quality

| Option | Default | Notes |
|--------|---------|-------|
| **Video Codec** | H.264 | H.264 (x264), H.265 (x265/HEVC), VP9, AV1 |
| **Audio Codec** | AAC | AAC, AC3, DTS, FLAC |
| **Quality** | High | Low, Medium, High, Lossless |
| **Include subtitles** | On | Keep every subtitle track, labeled with its language |
| **Include chapter markers** | On | Keep the disc's chapters |
| **Rip bonus features** | Off | Off rips only the main movie. On also rips featurettes and extras |

Every audio track is kept, labeled with its language from the disc.

### Advanced Encoding Settings

| Option | Default | What it does |
|--------|---------|--------------|
| **Enable hardware acceleration** | Off (offered on first launch if supported) | Encode H.264 and HEVC with VideoToolbox. Much faster; files are somewhat larger at the same quality. Not used for VP9, AV1, or Lossless, or when only an Intel FFmpeg is available |
| **Auto-deinterlace interlaced video** | On | Deinterlace frames the disc flags as interlaced (typical of NTSC DVDs) |
| **Use MakeMKV for Blu-ray** | On | Rip Blu-ray and UHD discs with MakeMKV. Off uses the built-in libaacs path, which needs your own `~/.config/aacs/KEYDB.cfg` |
| **Also use MakeMKV for DVDs** | Off | Rip DVDs with MakeMKV too. The built-in reader is usually faster, because MakeMKV scans the whole disc first (up to 15 minutes on complex discs). The app falls back to the built-in reader if MakeMKV isn't installed |

## Advanced tab

| Option | What it does |
|--------|--------------|
| **Pre-processing Script** | Run before each rip starts |
| **Post-processing Script** | Run after each rip finishes |

Scripts must be executable. The post-processing script gets the finished files as
arguments. Both get `SPINDLE_HOOK`, `SPINDLE_JOB_ID`, `SPINDLE_MEDIA_TYPE`,
`SPINDLE_SOURCE_PATH`, and `SPINDLE_OUTPUT_DIR` in their environment.

## Tips

- **Keep the output on local storage or a NAS, not an iCloud-synced folder.** Encoding
  always happens in `~/Library/Caches/Spindle/encoding/` and finished files are
  moved into place, but routing works best when the output isn't synced.
- **Turn on hardware acceleration** for big libraries; leave it off for the smallest files.
- **Install Homebrew's FFmpeg** (`brew install ffmpeg`) on Apple Silicon so hardware
  encoding can be used.
