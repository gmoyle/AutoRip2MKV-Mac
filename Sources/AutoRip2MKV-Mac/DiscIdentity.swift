import Foundation
import CryptoKit

/// Computes a stable identity for a physical disc, so re-inserting the same disc
/// is recognized while a different disc (even one sharing a generic volume label)
/// is not. Identity = volume label + a lightweight content fingerprint derived
/// from the disc's structure (title count + sizes), without reading the whole disc.
enum DiscIdentity {

    /// Compute the identity string for the disc mounted at `mountPath`.
    /// Format: "<volumeLabel>#<fingerprint>". Falls back to the label alone if
    /// the structure can't be read.
    static func compute(forDiscAt mountPath: String,
                        fileManager: FileManager = .default) -> String {
        let label = (mountPath as NSString).lastPathComponent
        if let fp = fingerprint(forDiscAt: mountPath, fileManager: fileManager) {
            return "\(label)#\(fp)"
        }
        return label
    }

    /// A short content fingerprint from the disc's video files: count and sizes of
    /// the main video payload (VIDEO_TS/*.VOB for DVD, BDMV/STREAM/*.m2ts for
    /// Blu-ray). Returns nil if no recognizable structure is found.
    static func fingerprint(forDiscAt mountPath: String,
                            fileManager: FileManager = .default) -> String? {
        let sizes = videoFileSizes(forDiscAt: mountPath, fileManager: fileManager)
        guard !sizes.isEmpty else { return nil }
        // Sort so ordering differences don't change the fingerprint. Use count,
        // total, and largest — coarse enough to survive trivial FS noise but
        // specific enough to distinguish different discs.
        let sorted = sizes.sorted()
        let total = sorted.reduce(0, +)
        let largest = sorted.last ?? 0
        let seed = "\(sorted.count)|\(total)|\(largest)"
        return String(sha256Hex(seed).prefix(16))
    }

    /// Sizes (bytes) of the disc's main video files, whichever structure applies.
    private static func videoFileSizes(forDiscAt mountPath: String,
                                       fileManager: FileManager) -> [Int64] {
        // Blu-ray / UHD: BDMV/STREAM/*.m2ts
        let streamDir = (mountPath as NSString).appendingPathComponent("BDMV/STREAM")
        if let m2ts = try? fileManager.contentsOfDirectory(atPath: streamDir),
           m2ts.contains(where: { $0.lowercased().hasSuffix(".m2ts") }) {
            return fileSizes(in: streamDir, matching: ".m2ts", fileManager: fileManager)
        }
        // DVD: VIDEO_TS/*.VOB
        let videoTS = (mountPath as NSString).appendingPathComponent("VIDEO_TS")
        if let vobs = try? fileManager.contentsOfDirectory(atPath: videoTS),
           vobs.contains(where: { $0.lowercased().hasSuffix(".vob") }) {
            return fileSizes(in: videoTS, matching: ".vob", fileManager: fileManager)
        }
        return []
    }

    private static func fileSizes(in dir: String, matching ext: String,
                                  fileManager: FileManager) -> [Int64] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }
        return entries
            .filter { $0.lowercased().hasSuffix(ext) }
            .map { name in
                let p = (dir as NSString).appendingPathComponent(name)
                let attrs = try? fileManager.attributesOfItem(atPath: p)
                return (attrs?[.size] as? Int64) ?? 0
            }
            .filter { $0 > 0 }
    }

    /// The content-fingerprint portion of an identity string (everything after the
    /// first "#"). Two identities for the same physical disc share this even when
    /// the volume-label portion drifts on remount (e.g. "FIREFLY" → "FIREFLY 1").
    /// Returns the whole string when there's no "#" (a label-only fallback identity),
    /// so a label-only identity still only matches itself.
    static func fingerprintComponent(of identity: String) -> String {
        guard let hashIndex = identity.firstIndex(of: "#") else { return identity }
        return String(identity[identity.index(after: hashIndex)...])
    }

    static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
