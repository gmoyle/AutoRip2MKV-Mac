# AutoRip2MKV-Mac User Guide

This guide covers AutoRip2MKV v2.1: how a rip works, the main window, the Plex
library workflow, MakeMKV for Blu-ray, and troubleshooting. Every setting is
described in the [Settings Guide](DETAILED_SETTINGS_GUIDE.md); installation is in
the [Installation Guide](INSTALLATION.md).

## Contents

1. [How a rip works](#how-a-rip-works)
2. [Main window](#main-window)
3. [Already-ripped discs](#already-ripped-discs)
4. [Plex libraries and routing](#plex-libraries-and-routing)
5. [DVDs](#dvds)
6. [Blu-ray and MakeMKV](#blu-ray-and-makemkv)
7. [Encoding](#encoding)
8. [Scripts](#scripts)
9. [Troubleshooting](#troubleshooting)

---

## How a rip works

With the default settings you only insert discs:

1. **Detect.** The app notices the disc as soon as macOS mounts it.
2. **Identify.** It looks up the disc's name on OMDb to get the movie's title and
   year, and checks whether this disc has already been ripped.
3. **Read.** The main movie (and bonus features, if you turned them on) is read
   from the disc at full drive speed into a local cache folder.
4. **Eject.** The disc ejects as soon as the read finishes, so you can insert the
   next one.
5. **Encode.** FFmpeg converts each title to MKV in the background, while the next
   disc reads.
6. **File.** Finished files move into the output folder and then, with content
   routing on, into your Movies or TV Shows library.

The Mac won't idle-sleep while a job is running, because sleep cuts power to USB
drives in the middle of a read.

## Main window

- **Source**: the drive dropdown lists optical drives (**Refresh** rescans);
  **Browse** picks a disc folder or image instead.
- **Output**: where rips are written before routing.
- **Auto-rip inserted discs**, **Auto-eject after ripping**, **Skip discs already
  ripped**: see [Settings Guide → Main window](DETAILED_SETTINGS_GUIDE.md#main-window).
- **Settings…**: the Settings window.
- **Review Rips**: appears when rips are waiting for a Movie or TV decision.
- **Start Ripping**: rip the current disc now, even if it was ripped before. While
  a rip runs, it cancels.
- **Queue**: each job shows its phase (reading, then encoding) and progress.
  Right-click a job to **Cancel**, **Retry**, **Reveal in Finder**, or **Remove from List**.
- **Log**: live status and errors. **Hide Log** collapses it.

## Already-ripped discs

The app keeps a record of each disc it has ripped, by a fingerprint of the disc's
contents (not just its name), in
`~/Library/Application Support/AutoRip2MKV-Mac/rip_history.json`. With **Skip discs
already ripped** on, a known disc is ejected without ripping, unless:

- you hold **⌥ Option** while inserting it, or click **Start Ripping**;
- you've changed a setting that affects the output since it was ripped;
- you deleted the folder the rip went to (a folder on a disconnected drive or NAS
  still counts as ripped);
- the disc's rip is still waiting under **Review Rips** (then it's skipped, not
  ripped twice).

## Plex libraries and routing

Rips are named `Movie (Year)/Movie (Year).mkv`. With **Sort rips into Movies / TV
Shows folders** on (Settings → Output & Routing), each finished rip is classified
by its title lengths:

- one long feature → **movie**, moved to the Movies folder;
- several titles of similar length → **TV season**, moved to the TV Shows folder;
- unclear → waits under **Review Rips**, pre-set to the app's guess, for you to
  confirm or switch. **Accept All Guesses** routes everything waiting.

Ripping never waits on a routing decision, and the review queue survives restarts.

Library folders can be on a NAS. Files are copied under a hidden name and renamed
once complete, so Plex never sees a partial file. Ripping a disc again replaces its
files in the same library folder instead of creating "Movie (Year) (2)"; anything
else you added to that folder stays.

## DVDs

DVDs need nothing beyond the app. Decryption uses libdvdcss.

- **Main movie by default.** Bonus features are ripped only if **Rip bonus features**
  is on.
- **All tracks.** Every audio and subtitle track is kept and labeled with its
  language from the disc.
- **Multi-version discs.** Some DVDs store several cuts of the movie in interleaved
  pieces ("seamless branching"). The app follows the disc's own navigation, as a
  DVD player does, so you get one clean copy of the movie, not every version back
  to back.
- **Scratched discs.** Unreadable sectors are retried one at a time, then skipped
  (up to a limit per title) so a small scratch doesn't fail the whole rip.
- **Interlaced video** (most NTSC DVDs) is deinterlaced automatically.

You can switch DVDs to MakeMKV with **Also use MakeMKV for DVDs**. It's usually
slower, because MakeMKV scans the entire disc before it starts.

## Blu-ray and MakeMKV

Blu-ray copy protection is handled by [MakeMKV](https://www.makemkv.com/), which
must be installed at `/Applications/MakeMKV.app`. AutoRip2MKV runs it in the
background and names and files the results the same way as DVDs.

**When MakeMKV stops working:** its free beta builds expire. The app then shows a
dialog:

- **Download & Install** downloads the current MakeMKV from makemkv.com and
  replaces the old copy. Then click **Rip Now**.
- **Open Download Page** opens makemkv.com.
- **Enter Key…** registers MakeMKV with a key you have.

MakeMKV needs the drive to itself. Close MakeMKV's own window and DVD Player before
inserting a Blu-ray.

## Encoding

Choose the codec and quality in Settings → Encoding. The defaults (H.264, AAC, High)
play everywhere.

**Hardware acceleration** uses Apple's VideoToolbox for H.264 and HEVC. It's much
faster, at the cost of somewhat larger files. It needs a native Apple Silicon
FFmpeg: install one with `brew install ffmpeg`. If the app only has the
Intel FFmpeg it downloads itself, it encodes in software.

All encoding happens in `~/Library/Caches/AutoRip2MKV/encoding/`. Only finished files
are moved to your output folder.

## Scripts

Settings → Advanced can run a script before each rip and another after it. See
[Settings Guide → Advanced](DETAILED_SETTINGS_GUIDE.md#advanced-tab) for what the
scripts receive.

## Troubleshooting

**A disc isn't detected.** In System Settings → Privacy & Security → Files and
Folders, make sure AutoRip2MKV can access **Removable Volumes**. Quit DVD Player if
it opened on its own; it holds the drive.

**A disc was skipped.** It's already in the rip history. Hold **⌥ Option** while
inserting it, or click **Start Ripping**.

**Encoding fails right away.** Check the log for which FFmpeg was found. Install
Homebrew's (`brew install ffmpeg`) if the downloaded one won't run.

**A Blu-ray fails with a licensing message.** Use **Download & Install** in the
MakeMKV dialog.

**A Blu-ray fails with "Failed to open disc".** Something else is using the drive.
Close other disc apps and reinsert the disc.

**A movie ends up under Review Rips.** The app couldn't tell from the title lengths
whether it's a movie or a TV season. Pick one there.

**A rip stopped when the Mac slept.** Older versions let the Mac sleep mid-rip; v2.1
prevents idle sleep while a job runs. Closing the lid still sleeps the Mac.

Still stuck? Open an issue at
https://github.com/gmoyle/AutoRip2MKV-Mac/issues with your macOS version, the disc,
and the log.
