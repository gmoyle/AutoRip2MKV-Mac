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

// MARK: - ConversionQueueDelegate (main-window live status for queue-driven rips)

extension MainViewController: ConversionQueueDelegate {

    func queueDidUpdateJobs(_ jobs: [ConversionQueue.ConversionJob]) {
        queueJobs = jobs
        queueTableView.reloadData()
    }

    func queueDidStartExtraction(jobId: UUID) {
        queueEncodePhase = false
        progressIndicator.isHidden = false
        progressIndicator.doubleValue = 0
        progressStatusLabel.isHidden = false
        progressStatusLabel.stringValue = "Reading disc..."
        totalRipSizeBytes = 0
        ripButton.isEnabled = false
        ripButton.title = "Ripping..."
    }

    func queueDidCompleteExtraction(jobId: UUID) {
        appendToLog("Disc read complete — safe to eject. Encoding continues in background.")
        progressStatusLabel.isHidden = false
        progressStatusLabel.stringValue = "Disc read complete — encoding in background..."
    }

    func queueDidFailExtraction(jobId: UUID, error: Error) {
        appendToLog("Rip failed: \(error.localizedDescription)")
        showErrorNotification("Ripping failed: \(error.localizedDescription)")
        resetRipUI()
    }

    func queueDidStartConversion(jobId: UUID) {
        queueEncodePhase = true
        progressIndicator.doubleValue = 0
        progressStatusLabel.isHidden = false
        progressStatusLabel.stringValue = "Encoding to MKV..."
    }

    func queueDidCompleteConversion(jobId: UUID, outputFiles: [String]) {
        for file in outputFiles {
            appendToLog("Finished: \(file)")
        }
        showCompletionNotification()
        resetRipUI()
    }

    func queueDidFailConversion(jobId: UUID, error: Error) {
        appendToLog("Encoding failed: \(error.localizedDescription)")
        showErrorNotification("Encoding failed: \(error.localizedDescription)")
        resetRipUI()
    }

    func queueDidUpdateConversionStatus(jobId: UUID, status: String) {
        // Reuses the ripper status handler: logs the line and captures total rip size.
        mediaRipperDidUpdateStatus(status)
    }

    func queueDidUpdateConversionProgress(jobId: UUID, progress: Double) {
        if progressIndicator.isHidden {
            progressIndicator.isHidden = false
            progressStatusLabel.isHidden = false
        }
        if queueEncodePhase {
            // Encode progress: a percentage of the title's runtime, not disc bytes
            let pct = min(max(progress, 0), 1)
            progressIndicator.doubleValue = pct * 100.0
            progressStatusLabel.stringValue = "Encoding to MKV... \(Int(pct * 100))%"
        } else {
            mediaRipperDidUpdateProgress(progress, currentItem: nil, totalItems: 0)
        }
    }
}
