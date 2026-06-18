import Cocoa

// MARK: - DVDRipperDelegate

extension MainViewController: DVDRipperDelegate {

    func ripperDidStart() {
        DispatchQueue.main.async {
            self.appendToLog("DVD ripper started")
        }
    }

    func ripperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.appendToLog(status)
        }
    }

    func ripperDidUpdateProgress(_ progress: Double, currentTitle: DVDTitle?, totalTitles: Int) {
        DispatchQueue.main.async {
            self.progressIndicator.doubleValue = progress * 100.0

            if let title = currentTitle {
                self.appendToLog("Processing title \(title.number) - \(Int(progress * 100))% complete")
            }
        }
    }

    func ripperDidComplete() {
        DispatchQueue.main.async {
            self.appendToLog("DVD ripping completed successfully!")
            self.activeMediaRipper = nil
            self.resetRipUI()

            // Show completion notification
            self.showCompletionNotification()

            // Automatically eject if enabled
            if self.settingsManager.autoEjectEnabled {
                self.appendToLog("Auto-ejecting disc...")
                self.ejectCurrentDisk()
            } else {
                self.appendToLog("Ripping complete. Disc ready for manual ejection.")
            }
        }
    }

    func ripperDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.appendToLog("Error: \(error.localizedDescription)")
            self.activeMediaRipper = nil
            self.resetRipUI()

            // Show error notification
            self.showErrorNotification("Ripping failed: \(error.localizedDescription)")

            self.showAlert(title: "Ripping Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - MediaRipperDelegate

extension MainViewController: MediaRipperDelegate {

    func mediaRipperDidStart() {
        DispatchQueue.main.async {
            self.appendToLog("Media ripper started")
        }
    }
    
    func mediaRipperDidUpdateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.appendToLog(status)
            // Capture total size from extraction status: "Reading N sectors for title X via libdvdcss..."
            if status.contains("sectors for title") && status.contains("via libdvdcss") {
                let parts = status.components(separatedBy: " ")
                if let idx = parts.firstIndex(of: "Reading"), idx + 1 < parts.count,
                   let sectors = Int64(parts[idx + 1]) {
                    self.totalRipSizeBytes = sectors * 2048
                }
            }
        }
    }

    func mediaRipperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        DispatchQueue.main.async {
            let pct = min(max(progress, 0), 1)
            self.progressIndicator.doubleValue = pct * 100.0

            if self.totalRipSizeBytes > 0 {
                let done = Int64(Double(self.totalRipSizeBytes) * pct)
                let doneStr = self.formatBytes(done)
                let totalStr = self.formatBytes(self.totalRipSizeBytes)
                self.progressStatusLabel.stringValue = "\(doneStr) / \(totalStr)  (\(Int(pct * 100))%)"
            } else if pct > 0 {
                self.progressStatusLabel.stringValue = "\(Int(pct * 100))%"
            }
        }
    }

    internal func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    func mediaRipperDidComplete() {
        DispatchQueue.main.async {
            self.appendToLog("Media ripping completed successfully!")
            self.activeMediaRipper = nil
            self.resetRipUI()
            
            // Show completion notification
            self.showCompletionNotification()
            
            // Automatically eject if enabled
            if self.settingsManager.autoEjectEnabled {
                self.appendToLog("Auto-ejecting disc...")
                self.ejectCurrentDisk()
            } else {
                self.appendToLog("Ripping complete. Disc ready for manual ejection.")
            }
        }
    }
    
    func mediaRipperDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.appendToLog("Error: \(error.localizedDescription)")
            self.activeMediaRipper = nil
            self.resetRipUI()
            
            // Show error notification
            self.showErrorNotification("Ripping failed: \(error.localizedDescription)")
            
            self.showAlert(title: "Ripping Failed", message: error.localizedDescription)
        }
    }
}
