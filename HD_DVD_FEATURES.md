# HD DVD Feature Integration - AutoRip2MKV-Mac

## Advanced HD DVD Analysis (Phase 2)

### Supported Features
- **Multi-audio track detection**: Parses and reports all available audio tracks per title (language, codec, channels, sample rate).
- **Subtitle track detection**: Detects and logs subtitle tracks (language, format: PGS, VobSub, etc).
- **Bitrate estimation per title**: Estimates bitrate for each title based on simulated file size and disc structure.
- **Menu/title set simulation**: Reports menu set (e.g., MainMenu, ExtrasMenu) for each title.
- **Dual layer detection**: Uses disc size to determine dual layer status.
- **Volume label reporting**: Logs HD DVD volume label for analysis and reporting.
- **Error handling**: Robust error messages for missing/corrupt files, no titles found, invalid paths.

### Integration Points
- `HDDVDStructureParser.swift`: Core parser for HD DVD disc structure, titles, audio, subtitles, bitrate, and menu sets.
- `MediaRipper+Analysis.swift`: Analysis engine surfaces all HD DVD features in logs and quality assessment.

### Example Log Output
```
HD DVD Volume: HD_DVD, Main Title: Main Feature
Subtitle Tracks: en [PGS], fr [PGS]
Menu Set: MainMenu
Estimated Bitrate: 18000 kbps
Audio Tracks: 3
```

### Usage
- Analysis automatically detects and reports all advanced HD DVD features.
- Quality assessment includes all audio tracks, subtitle tracks, bitrate, and menu info.
- Backward compatible with previous DVD/Blu-ray analysis.

### Next Steps
- Expand test coverage for edge cases (multiple titles, missing tracks, corrupt files).
- Integrate with UI for user-facing reporting.
- Document feature usage in user guide and API docs.

---
*Last updated: January 31, 2026*
