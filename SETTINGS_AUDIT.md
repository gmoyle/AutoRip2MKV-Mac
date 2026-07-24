# Settings Tabs Audit — Wired vs. Dead Controls

Audit of `DetailedSettingsWindowController` (the multi-tab Settings window).
Method: for each control, trace whether its persisted value is **read by the rip
/ organize / naming / script pipeline** (real) or only written to UserDefaults
and never consumed (dead).

Legend: ✅ real (consumed) · ❌ dead (write-only, no consumer)

Key structural finding: **`SettingsUtilities` is never instantiated and none of
its functions are ever called.** The real file organization + naming happens in
`MediaRipper+Organization.swift` (`createOrganizedOutputDirectory`,
`extractMovieName`, `plexBaseName`), which does NOT read any of the
Organization/Naming-tab settings. So every control whose only consumer is
`SettingsUtilities` is effectively dead.

---

## Tab: Encoding  — CLEANED UP (this session)

### Removed (dead)
- ❌ **Encoding Speed** popup (`encodingSpeed`) — never read
- ❌ **Bitrate Control** popup (`bitrateControl`) — never read
- ❌ **Target Bitrate (Mbps)** field (`targetBitrate`) — never read
- ❌ **Use two-pass encoding** checkbox (`twoPassEncoding`) — never read
- ❌ **Custom FFmpeg Arguments** field (`customFFmpegArgs`) — never read
- ❌ Entire **"Additional Quality Presets"** box: Quality Preset popup
  (`selectedQualityPreset`), Custom Preset Name (`customPresetName`), Save/Delete
  Preset buttons (`saveCustomPreset`/`deleteCustomPreset`). Wrote per-name preset
  blobs to UserDefaults that nothing ever loaded. Note: a separate, real preset
  model exists in `CodecPresets.swift` but was never wired to this UI.

### Kept (real)
- ✅ **Quality** popup → `settingsManager.quality` (the ONE quality control the
  ripper reads; 10+ consumers)
- ✅ **Video Codec** → `settingsManager.videoCodec`
- ✅ **Audio Codec** → `settingsManager.audioCodec`
- ✅ **Include subtitles** → `settingsManager.includeSubtitles`
- ✅ **Include chapter markers** → `settingsManager.includeChapters`
- ✅ **Enable hardware acceleration** → `settingsManager.hardwareAcceleration`
- ✅ **Auto-deinterlace** → `settingsManager.autoDeinterlace`
- ✅ **Use MakeMKV for Blu-ray** → `settingsManager.useMakeMKVForBluRay`

---

## Tab: Output & Routing  — PENDING DECISION

Section `setupOutputDirectorySection` + `setupFileStorageSection`.

### Dead
- ❌ **Default Output Directory** field (`defaultOutputPath`) — never read. (Real
  output dir comes from the main window's output field, not this.)
- ❌ **Create date-based subdirectories** (`createDateDirectories`) — never read
- ❌ **Output Path Template** field (`outputPathTemplate`) — never read
- ❌ **Directory Structure** popup (`outputStructureType`) — only consumer is
  `SettingsUtilities` (dead)
- ❌ **Create series directory** (`createSeriesDirectory`) — only `SettingsUtilities`
- ❌ **Create season directory** (`createSeasonDirectory`) — only `SettingsUtilities`
- ❌ **Movie Directory Format** (`movieDirectoryFormat`) — only `SettingsUtilities`
- ❌ **TV Show Directory Format** (`tvShowDirectoryFormat`) — only `SettingsUtilities`

### Real
- ✅ **Content Routing** enable → `settingsManager.contentRoutingEnabled`
- ✅ **Auto-route confident guesses** → `settingsManager.autoRouteHighConfidence`
- ✅ **Movies Folder** → `settingsManager.moviesRootDirectory`
- ✅ **TV Shows Folder** → `settingsManager.tvShowsRootDirectory`

---

## Tab: Organization  — PENDING DECISION (mostly dead)

Section `setupFileOrganizationSection` + `setupBonusContentSection`.

### Dead
- ❌ **Automatically rename files** (`autoRenameFiles`) — no consumer
- ❌ **Create year directories** (`createYearDirectories`) — no consumer
- ❌ **Create genre directories** (`createGenreDirectories`) — no consumer
- ❌ **Duplicate handling** popup (`duplicateHandling`) — no consumer
- ❌ **Minimum file size** field (`minimumFileSize`) — no consumer
- ❌ **Include bonus features** (`includeBonusFeatures`) — only `SettingsUtilities`
- ❌ **Include commentaries** (`includeCommentaries`) — only `SettingsUtilities`
- ❌ **Include deleted scenes** (`includeDeletedScenes`) — only `SettingsUtilities`
- ❌ **Include making-of** (`includeMakingOf`) — only `SettingsUtilities`
- ❌ **Include trailers** (`includeTrailers`) — only `SettingsUtilities`
- ❌ **Bonus content structure** (`bonusContentStructure`) — only `SettingsUtilities`
- ❌ **Bonus content directory** (`bonusContentDirectory`) — only `SettingsUtilities`

### Real
- (none found — this entire tab appears non-functional)

---

## Tab: Naming  — PENDING DECISION (entirely dead)

Section `setupFileNamingSection`. Real naming is `plexBaseName` /
`extractMovieName` in `MediaRipper+Organization.swift`, which ignores all of these.

### Dead
- ❌ **Movie File Format** (`movieFileFormat`) — only `SettingsUtilities`
- ❌ **TV Show File Format** (`tvShowFileFormat`) — only `SettingsUtilities`
- ❌ **Season/Episode Format** (`seasonEpisodeFormat`) — only `SettingsUtilities`
- ❌ **Include year in filename** (`includeYearInFilename`) — only `SettingsUtilities`
- ❌ **Include codec in filename** (`includeCodecInFilename`) — only `SettingsUtilities`
- ❌ **Include resolution in filename** (`includeResolutionInFilename`) — only `SettingsUtilities`

### Real
- (none found — this entire tab appears non-functional)

---

## Tab: Advanced  — PENDING DECISION (mixed)

Section `setupAdvancedSection`.

### Dead
- ❌ **Preserve original file timestamps** (`preserveOriginalTimestamps`) — no consumer
- ❌ **Create backup of original disc structure** (`createBackups`) — no consumer
- ❌ **Auto-retry on failure** (`autoRetryOnFailure`) — no consumer (note: ripper
  has its own hardcoded retry loop, not driven by this)
- ❌ **Max Retry Attempts** (`maxRetryAttempts`) — no consumer

### Real
- ✅ **Pre-processing Script** (`preProcessingScript`) → read by `ScriptRunner`,
  invoked from `ConversionQueue` (`.preProcessing` hook)
- ✅ **Post-processing Script** (`postProcessingScript`) → read by `ScriptRunner`,
  invoked from `ConversionQueue` (`.postProcessing` hook)

---

## Summary

| Tab | Real controls | Dead controls |
|-----|---------------|---------------|
| Encoding | 8 | 6 (removed) |
| Output & Routing | 4 (routing) | 8 |
| Organization | 0 | 12 |
| Naming | 0 | 6 |
| Advanced | 2 (scripts) | 4 |

Two tabs (Organization, Naming) are entirely non-functional. The dead controls in
the other tabs are the file-organization/naming/output-template settings whose
only consumer, `SettingsUtilities`, is never run.

## RESOLUTION (implemented)

Decision: **wire what the pipeline can actually feed; remove the rest.**

Wired up (now functional):
- **Directory Structure** (Flat / By Media Type / By Year / By Genre / Custom) —
  the new `OutputOrganizer` is the single choke point all three rippers
  (DVD/Blu-ray/HD DVD) route through. `{title}` and `{year}` resolve; unknown
  tokens ({season}/{genre}/…) are dropped rather than faked.
- **Movie / TV Directory Format** — used by the Custom structure.

Removed (never consumable with current data), tabs collapsed to three
(Output & Routing, Encoding, Advanced):
- `SettingsUtilities.swift` deleted (was never instantiated); its per-file naming
  and bonus-content logic had no data source.
- Organization tab (auto-rename, year/genre dirs, duplicate handling, min size,
  all bonus-content) — removed.
- Naming tab (all file-name templates, include-year/codec/resolution) — removed.
- Output & Routing: default-output-path, date-subdirs, output-path-template,
  create-series/season dirs — removed.
- Advanced: preserve-timestamps, create-backups, auto-retry, max-retries — removed.
- Quality: Preferred Language popup — removed (never persisted or consumed).

Kept & real: Content Routing (enable/auto-route/Movies+TV roots), Quality/Codecs
(video/audio codec, quality, subtitles, chapters), Encoding checkboxes (HW accel,
auto-deinterlace, MakeMKV), and pre/post-processing Scripts (run by ScriptRunner).

Not built (would need a metadata source like OMDb): season/episode/genre tokens
and any bonus-content extraction.
