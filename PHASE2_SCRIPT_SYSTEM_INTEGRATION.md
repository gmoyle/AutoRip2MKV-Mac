# Phase 2 Task 4: Script System Integration

**Version:** v1.4.3-alpha  
**Status:** ✅ Complete  
**Tests:** ScriptRunnerTests.swift (unit tests for env + interpreter resolution)

## Overview

This task adds event-driven script hooks that run before ripping and after conversion completes. Scripts can be written in Python, Ruby, JavaScript, or shell, and they receive job metadata via environment variables.

## Implementation Summary

### ScriptRunner
New class: `ScriptRunner.swift`

**Supported script types:**
- Python (`.py`) via `/usr/bin/env python3`
- Ruby (`.rb`) via `/usr/bin/env ruby`
- JavaScript (`.js`) via `/usr/bin/env node`
- Shell (`.sh`) via `/bin/bash`
- Executable files with no extension

**Execution behavior:**
- Runs asynchronously on a utility queue
- Uses job output directory as the working directory
- Adds output file paths as command-line arguments for post-processing scripts

### Script Hooks
Added hooks at two key points:

1. **Pre-processing** (before extraction starts)
2. **Post-processing** (after conversion completes or fails)

Integration points:
- `ConversionQueue.performExtraction()` → pre-processing hook
- `ConversionQueue.performConversion()` → post-processing hook

### Output File Resolution
If the conversion pipeline does not return output paths, the queue scans the output directory for `.mkv` files modified after the job start time.

### Settings Integration
New UserDefaults key:
- `preProcessingScript`

Existing key reused:
- `postProcessingScript`

Both are available in the Detailed Settings UI.

## Environment Variables

Scripts receive metadata via environment variables:

| Variable | Description |
|----------|-------------|
| `AUTORIP_HOOK` | `pre_processing` or `post_processing` |
| `AUTORIP_JOB_ID` | Job UUID |
| `AUTORIP_MEDIA_TYPE` | Media type folder name (DVD/Blu-ray/etc.) |
| `AUTORIP_SOURCE_PATH` | Source disc path |
| `AUTORIP_OUTPUT_DIR` | Output directory |
| `AUTORIP_DISC_TITLE` | Disc title |
| `AUTORIP_PRIORITY` | Queue priority string |
| `AUTORIP_STATUS` | `success` or `failed` |
| `AUTORIP_OUTPUT_COUNT` | Count of output files |
| `AUTORIP_OUTPUT_FILES` | Semicolon-separated output paths |
| `AUTORIP_START_TIME` | ISO 8601 job start time |
| `AUTORIP_END_TIME` | ISO 8601 job end time |
| `AUTORIP_ERROR` | Error description (only on failure) |

## Example Scripts

### Python (post-processing)
```python
import os
import sys

output_files = sys.argv[1:]
print("Hook:", os.environ.get("AUTORIP_HOOK"))
print("Title:", os.environ.get("AUTORIP_DISC_TITLE"))
print("Outputs:", output_files)
```

### Ruby (pre-processing)
```ruby
puts "Hook: #{ENV['AUTORIP_HOOK']}"
puts "Disc: #{ENV['AUTORIP_DISC_TITLE']}"
```

### Node.js (post-processing)
```js
console.log("Status:", process.env.AUTORIP_STATUS);
console.log("Output count:", process.env.AUTORIP_OUTPUT_COUNT);
console.log("Files:", process.argv.slice(2));
```

## Files Modified/Created

### New Files
- `Sources/AutoRip2MKV-Mac/ScriptRunner.swift`
- `Tests/AutoRip2MKV-MacTests/ScriptRunnerTests.swift`
- `PHASE2_SCRIPT_SYSTEM_INTEGRATION.md`

### Modified Files
- `Sources/AutoRip2MKV-Mac/ConversionQueue.swift`
  - Added pre/post hook execution
  - Added output file discovery

- `Sources/AutoRip2MKV-Mac/SettingsManager.swift`
  - Added `preProcessingScript` key and accessor

- `Sources/AutoRip2MKV-Mac/DetailedSettingsWindowController.swift`
  - Added pre-processing script field and browse button
  - Updated load/save/defaults for script settings

## Tests

- `ScriptRunnerTests.swift` validates:
  - Environment variable generation
  - Interpreter resolution for `.py`, `.rb`, `.js`, `.sh`
  - Direct executable script handling

## Next Task

**Phase 2 Task 5: Cloud/NAS Upload Integration**
- SFTP/SCP upload after conversion
- Cloud providers (S3, Dropbox, etc.)
- Progress tracking and retry logic
