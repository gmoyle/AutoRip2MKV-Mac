import Cocoa

// ffmpeg is fed through stdin pipes; if it exits mid-rip the next write would
// raise SIGPIPE and kill the whole app. Ignore it so the write fails with EPIPE.
signal(SIGPIPE, SIG_IGN)

// Settings and app data from before the rename to Spindle. Must run before
// anything reads settings or opens the log.
AppIdentity.migrateFromLegacyNameIfNeeded()

// Create the application
let app = NSApplication.shared

// Create the app delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the application
app.run()
