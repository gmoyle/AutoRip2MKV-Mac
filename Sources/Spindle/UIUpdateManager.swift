import Foundation
import Cocoa

/// Protocol for managing UI state updates
/// This abstraction allows for better separation of concerns and testability
protocol UIUpdateManaging {
    /// Set weak reference to the UI components for updates
    var uiComponents: UIComponents? { get set }
    
    /// Update progress indicator
    func updateProgress(_ progress: Double, isIndeterminate: Bool)
    
    /// Update status text and log
    func updateStatus(_ status: String, appendToLog: Bool)
    
    /// Update button states
    func updateButtonStates(isRipping: Bool)
    
    /// Update drive selection dropdown
    func updateDriveSelection(drives: [OpticalDrive], selectedIndex: Int)
    
    /// Show progress indicator
    func showProgress()
    
    /// Hide progress indicator
    func hideProgress()
    
    /// Reset UI to initial state
    func resetToInitialState()
    
    /// Update UI for ripping completion
    func updateForRippingCompletion()
    
    /// Update UI for ripping failure
    func updateForRippingFailure(error: Error)
}

/// Container for UI component references
/// Using weak references to prevent retain cycles
class UIComponents {
    weak var progressIndicator: NSProgressIndicator?
    weak var ripButton: NSButton?
    weak var logTextView: NSTextView?
    weak var sourceDropDown: NSPopUpButton?
    weak var refreshDrivesButton: NSButton?
    weak var browseSourceButton: NSButton?
    weak var browseOutputButton: NSButton?
    
    init(progressIndicator: NSProgressIndicator?,
         ripButton: NSButton?,
         logTextView: NSTextView?,
         sourceDropDown: NSPopUpButton?,
         refreshDrivesButton: NSButton?,
         browseSourceButton: NSButton?,
         browseOutputButton: NSButton?) {
        self.progressIndicator = progressIndicator
        self.ripButton = ripButton
        self.logTextView = logTextView
        self.sourceDropDown = sourceDropDown
        self.refreshDrivesButton = refreshDrivesButton
        self.browseSourceButton = browseSourceButton
        self.browseOutputButton = browseOutputButton
    }
}

/// Manages UI state updates with proper async/await patterns and thread safety
/// Extracted from MainViewController to provide better separation of concerns
class UIUpdateManager: UIUpdateManaging, @unchecked Sendable {
    
    // MARK: - Properties
    
    weak var uiComponents: UIComponents?
    
    private let updateQueue = DispatchQueue(label: "UIUpdateManager.updates", qos: .userInitiated)
    private var pendingUpdates: [UIUpdate] = []
    private var isProcessingUpdates = false
    
    // MARK: - Initialization
    
    init(uiComponents: UIComponents? = nil) {
        self.uiComponents = uiComponents
    }
    
    // MARK: - UIUpdateManaging Implementation
    
    func updateProgress(_ progress: Double, isIndeterminate: Bool = false) {
        let update = UIUpdate.progress(progress, isIndeterminate)
        enqueueUpdate(update)
    }
    
    func updateStatus(_ status: String, appendToLog: Bool = true) {
        let update = UIUpdate.status(status, appendToLog)
        enqueueUpdate(update)
    }
    
    func updateButtonStates(isRipping: Bool) {
        let update = UIUpdate.buttonStates(isRipping)
        enqueueUpdate(update)
    }
    
    func updateDriveSelection(drives: [OpticalDrive], selectedIndex: Int) {
        let update = UIUpdate.driveSelection(drives, selectedIndex)
        enqueueUpdate(update)
    }
    
    func showProgress() {
        let update = UIUpdate.showProgress
        enqueueUpdate(update)
    }
    
    func hideProgress() {
        let update = UIUpdate.hideProgress
        enqueueUpdate(update)
    }
    
    func resetToInitialState() {
        let update = UIUpdate.resetToInitial
        enqueueUpdate(update)
    }
    
    func updateForRippingCompletion() {
        let updates: [UIUpdate] = [
            .hideProgress,
            .buttonStates(false),
            .status("Ripping completed successfully!", true)
        ]
        enqueueUpdates(updates)
    }
    
    func updateForRippingFailure(error: Error) {
        let updates: [UIUpdate] = [
            .hideProgress,
            .buttonStates(false),
            .status("Ripping failed: \(error.localizedDescription)", true)
        ]
        enqueueUpdates(updates)
    }
    
    // MARK: - Private Implementation
    
    private func enqueueUpdate(_ update: UIUpdate) {
        updateQueue.async {
            self.pendingUpdates.append(update)
            self.processPendingUpdatesIfNeeded()
        }
    }
    
    private func enqueueUpdates(_ updates: [UIUpdate]) {
        updateQueue.async {
            self.pendingUpdates.append(contentsOf: updates)
            self.processPendingUpdatesIfNeeded()
        }
    }
    
    private func processPendingUpdatesIfNeeded() {
        guard !isProcessingUpdates && !pendingUpdates.isEmpty else { return }
        isProcessingUpdates = true
        
        // Batch updates and execute on main queue
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        DispatchQueue.main.async {
            self.executeUpdates(updates)
            
            self.updateQueue.async {
                self.isProcessingUpdates = false
                self.processPendingUpdatesIfNeeded() // Process any updates that arrived while we were busy
            }
        }
    }
    
    private func executeUpdates(_ updates: [UIUpdate]) {
        // Execute all updates on the main thread
        for update in updates {
            executeUpdate(update)
        }
    }
    
    private func executeUpdate(_ update: UIUpdate) {
        switch update {
        case .progress(let progress, let isIndeterminate):
            updateProgressIndicator(progress: progress, isIndeterminate: isIndeterminate)
            
        case .status(let status, let shouldAppendToLog):
            if shouldAppendToLog {
                appendToLogMessage(status)
            }
            
        case .buttonStates(let isRipping):
            updateButtonStatesInternal(isRipping: isRipping)
            
        case .driveSelection(let drives, let selectedIndex):
            updateDriveSelectionInternal(drives: drives, selectedIndex: selectedIndex)
            
        case .showProgress:
            showProgressIndicator()
            
        case .hideProgress:
            hideProgressIndicator()
            
        case .resetToInitial:
            resetToInitialStateInternal()
        }
    }
    
    // MARK: - UI Update Methods (Main Thread Only)
    
    private func updateProgressIndicator(progress: Double, isIndeterminate: Bool) {
        guard let progressIndicator = uiComponents?.progressIndicator else { return }
        
        if isIndeterminate {
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = progress * 100.0
        }
    }
    
    private func appendToLogMessage(_ message: String) {
        guard let logTextView = uiComponents?.logTextView else { return }
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        let currentText = logTextView.string
        let newText = currentText + logMessage
        logTextView.string = newText
        
        // Auto-scroll to bottom
        let textRange = NSRange(location: newText.count, length: 0)
        logTextView.scrollRangeToVisible(textRange)
    }
    
    private func updateButtonStatesInternal(isRipping: Bool) {
        uiComponents?.ripButton?.isEnabled = !isRipping
        uiComponents?.ripButton?.title = isRipping ? "Ripping..." : "Start Ripping"
        uiComponents?.refreshDrivesButton?.isEnabled = !isRipping
        uiComponents?.browseSourceButton?.isEnabled = !isRipping
        uiComponents?.browseOutputButton?.isEnabled = !isRipping
    }
    
    private func updateDriveSelectionInternal(drives: [OpticalDrive], selectedIndex: Int) {
        guard let dropdown = uiComponents?.sourceDropDown else { return }
        
        dropdown.removeAllItems()
        
        if drives.isEmpty {
            dropdown.addItem(withTitle: "No drives detected")
            dropdown.isEnabled = false
        } else {
            for (index, drive) in drives.enumerated() {
                let displayName = "\(drive.name) - \(drive.type == .dvd ? "DVD" : "Blu-ray")"
                dropdown.addItem(withTitle: displayName)
                
                // Set additional info as tooltip
                let item = dropdown.item(at: index)
                item?.toolTip = "Device: \(drive.devicePath)\nMount Point: \(drive.mountPoint)"
            }
            
            dropdown.isEnabled = true
            
            if selectedIndex >= 0 && selectedIndex < drives.count {
                dropdown.selectItem(at: selectedIndex)
            }
        }
    }
    
    private func showProgressIndicator() {
        guard let progressIndicator = uiComponents?.progressIndicator else { return }
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
    }
    
    private func hideProgressIndicator() {
        guard let progressIndicator = uiComponents?.progressIndicator else { return }
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
    }
    
    private func resetToInitialStateInternal() {
        hideProgressIndicator()
        updateButtonStatesInternal(isRipping: false)
        updateProgressIndicator(progress: 0.0, isIndeterminate: false)
    }
}

// MARK: - Internal Update Types

private enum UIUpdate {
    case progress(Double, Bool)  // progress, isIndeterminate
    case status(String, Bool)    // status, appendToLog
    case buttonStates(Bool)      // isRipping
    case driveSelection([OpticalDrive], Int)  // drives, selectedIndex
    case showProgress
    case hideProgress
    case resetToInitial
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Error Types

enum UIUpdateManagerError: Error, LocalizedError {
    case noUIComponentsSet
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .noUIComponentsSet:
            return "No UI components have been set"
        case .updateFailed:
            return "UI update operation failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noUIComponentsSet:
            return "Set UI components using the uiComponents property"
        case .updateFailed:
            return "Check that all UI components are valid and accessible"
        }
    }
}