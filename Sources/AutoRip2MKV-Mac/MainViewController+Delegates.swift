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
            self.progressIndicator.isHidden = true
            self.ripButton.isEnabled = true
            self.ripButton.title = "Start Ripping"
            
            // Eject the disk after successful completion
            self.ejectCurrentDisk()
        }
    }
    
    func ripperDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.appendToLog("Error: \(error.localizedDescription)")
            self.progressIndicator.isHidden = true
            self.ripButton.isEnabled = true
            self.ripButton.title = "Start Ripping"
            
            self.showAlert(title: "Ripping Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - MediaRipperDelegate

extension MainViewController: MediaRipperDelegate {
    
    func ripperDidUpdateProgress(_ progress: Double, currentItem: MediaRipper.MediaItem?, totalItems: Int) {
        DispatchQueue.main.async {
            self.progressIndicator.doubleValue = progress * 100.0
            
            if let item = currentItem {
                switch item {
                case .dvdTitle(let title):
                    self.appendToLog("Processing DVD title \(title.number) - \(Int(progress * 100))% complete")
                case .blurayPlaylist(let playlist):
                    self.appendToLog(
                        "Processing Blu-ray playlist \(playlist.number) - \(Int(progress * 100))% complete"
                    )
                }
            }
        }
    }
}
