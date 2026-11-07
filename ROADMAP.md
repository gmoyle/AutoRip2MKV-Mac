# Spindle Roadmap

Spindle (formerly AutoRip2MKV) is turning from a DVD/Blu-ray ripper into a media
library companion: insert any disc, and its contents land in the right library,
named and organized, with nothing to click.

Spindle works with Plex, Jellyfin and Emby folder layouts, but isn't tied to any of
them.

## Where it stands (v2.1)

- Hands-free DVD and Blu-ray ripping: auto-rip on insert, eject when the read
  finishes, background encoding, already-ripped discs skipped
- DVD seamless branching, damaged-sector recovery, MakeMKV for Blu-ray/UHD with
  in-app updates
- Movies / TV Shows routing by title structure, with a review queue

## Decisions

| Question | Decision |
|----------|----------|
| Name | **Spindle** (no media-server names in the product name) |
| Music format | **FLAC** |
| CD reading | Fast (macOS's own CD reading); verification such as AccurateRip later |
| Photo destination | **Ask the first time** a photo disc is inserted: a library folder, Apple Photos, or both |
| Phase order | 0 → 1 → 2 → 3 → 4 → 5 |

## Phase 0: Rename to Spindle

- Package, module, app name, bundle ID (`com.gmoyle.spindle`), window title,
  notifications, DMG and release workflow
- Settings, rip history and logs migrated on first launch from the old bundle ID
  and `~/Library/Application Support/AutoRip2MKV-Mac`
- Repository renamed to `gmoyle/Spindle`

## Phase 1: Groundwork

- **Disc kinds**: replace the video-only media type with a disc kind decided from
  the disc's contents: video DVD, Blu-ray, HD DVD, audio CD, photo disc,
  home-video disc, data disc
- **Importers**: one importer per disc kind behind a shared interface. The queue,
  retries, local staging, eject, sleep prevention and rip history stay shared
- **Libraries**: a library root per kind (Movies, TV Shows, Music, Photos, Home
  Videos, Imported Discs), each set in Settings
- **Metadata providers**: one interface for OMDb, TMDB and MusicBrainz

## Phase 2: Music CDs

- Read the AIFF tracks macOS exposes for a mounted audio CD; use `.TOC.plist`
  for the track layout
- Compute the MusicBrainz disc ID from the TOC; look up album, artist, year,
  track titles, disc number in a set
- Cover art from the Cover Art Archive
- Encode to FLAC with full tags and embedded art
- File as `Music/Artist/Album (Year)/01 - Title.flac`
  (`Disc 2/` folders for multi-disc sets)
- Unknown CDs: rip as `Unknown Artist/Unknown Album (date)` and add to the review
  queue

## Phase 3: TV series

- Switch movie and TV lookups to TMDB (keep OMDb as a fallback)
- Find the series and season; map the disc's titles to episodes by order and
  duration
- Remember series across discs, so disc 2 continues where disc 1 stopped
- Skip "play all" titles that join every episode
- File as `TV Shows/Show/Season 01/Show - S01E05.mkv`; unsure mappings go to
  the review queue with proposed episode numbers

## Phase 4: Photo, home-video and data discs

- **Photo discs** (JPEG/HEIC/RAW files, `DCIM`, Kodak Picture CD): copy with
  checksum verification, organize by photo date as `Photos/2004/2004-07-14/`,
  skip duplicates of photos already imported. Destination chosen the first time
  (folder, Apple Photos, or both)
- **Home-video discs** (camcorder or burned DVDs with no commercial title):
  rip to a Home Videos library, named by date
- **Other data discs**: copy as-is into `Imported Discs/<disc name>/`

## Phase 5: Companion features

- Ask the local media server to rescan the affected library after each import
  (Plex API with the server token; Jellyfin/Emby later)
- Activity view: an import history of what came in, where it went, and what
  needs review

## Later

- AccurateRip verification for audio CDs
- Secure (paranoia-style) CD reading for scratched discs
- Subtitles and artwork for TV episodes
