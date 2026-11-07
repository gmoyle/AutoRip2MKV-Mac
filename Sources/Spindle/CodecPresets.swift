import Foundation

// MARK: - Codec Preset Configuration

extension SettingsManager {
    
    /// Codec presets with recommended settings for different use cases
    struct CodecPreset {
        let name: String
        let description: String
        let codec: String
        let quality: String
        let recommendedUseCases: [String]
    }
    
    /// All available codec presets
    static let codecPresets: [CodecPreset] = [
        // H.264 Presets
        CodecPreset(
            name: "H.264 Fast",
            description: "Quick encoding with good compatibility. Best for archiving with time constraints.",
            codec: "h264",
            quality: "low",
            recommendedUseCases: ["Quick backups", "Archival with time limits", "Testing"]
        ),
        CodecPreset(
            name: "H.264 Balanced",
            description: "Balanced quality and speed. Excellent for most content with universal compatibility.",
            codec: "h264",
            quality: "medium",
            recommendedUseCases: ["General purpose", "Streaming", "Most compatible"]
        ),
        CodecPreset(
            name: "H.264 High Quality",
            description: "High quality H.264 encoding. Slower but maintains excellent quality.",
            codec: "h264",
            quality: "high",
            recommendedUseCases: ["High-quality archiving", "Professional use", "Long-term storage"]
        ),
        
        // H.265 Presets
        CodecPreset(
            name: "H.265 Fast",
            description: "H.265/HEVC with quick encoding. Better compression than H.264 at similar speed.",
            codec: "h265",
            quality: "low",
            recommendedUseCases: ["4K content", "Space-constrained storage", "Quick encoding"]
        ),
        CodecPreset(
            name: "H.265 Balanced",
            description: "Excellent compression with reasonable encoding time. Ideal for 4K/HDR content.",
            codec: "h265",
            quality: "medium",
            recommendedUseCases: ["4K/UHD content", "HDR video", "Modern devices"]
        ),
        CodecPreset(
            name: "H.265 High Quality",
            description: "Superior H.265 quality. Slow encoding but excellent for long-term archival.",
            codec: "h265",
            quality: "high",
            recommendedUseCases: ["4K archival", "HDR preservation", "Premium quality"]
        ),
        
        // AV1 Presets
        CodecPreset(
            name: "AV1 Fast",
            description: "AV1 with fast encoding settings. Best compression efficiency at high speed.",
            codec: "av1",
            quality: "low",
            recommendedUseCases: ["Modern streaming", "Space-critical", "Future-proof archival"]
        ),
        CodecPreset(
            name: "AV1 Balanced",
            description: "Balanced AV1 encoding. Superior compression with moderate encoding time.",
            codec: "av1",
            quality: "medium",
            recommendedUseCases: ["Streaming services", "8K content", "Maximum compression"]
        ),
        CodecPreset(
            name: "AV1 High Quality",
            description: "Maximum AV1 quality with tile-based encoding. Slow but unmatched compression.",
            codec: "av1",
            quality: "high",
            recommendedUseCases: ["8K archival", "Professional mastering", "Ultra-premium quality"]
        ),
        
        // VP9 Presets
        CodecPreset(
            name: "VP9 Fast",
            description: "VP9 with realtime encoding. Good for live transcoding and quick conversions.",
            codec: "vp9",
            quality: "low",
            recommendedUseCases: ["Live streaming", "Web video", "Quick turnaround"]
        ),
        CodecPreset(
            name: "VP9 Balanced",
            description: "Balanced VP9 with multi-threading. Excellent for web delivery and YouTube.",
            codec: "vp9",
            quality: "medium",
            recommendedUseCases: ["YouTube uploads", "Web streaming", "Social media"]
        ),
        CodecPreset(
            name: "VP9 High Quality",
            description: "High quality VP9 encoding. Best for web-based 4K streaming with lookahead.",
            codec: "vp9",
            quality: "high",
            recommendedUseCases: ["4K web streaming", "Premium web video", "High-end web delivery"]
        )
    ]
    
    /// Get presets for a specific codec
    static func presets(for codec: String) -> [CodecPreset] {
        return codecPresets.filter { $0.codec == codec }
    }
    
    /// Get preset by name
    static func preset(named name: String) -> CodecPreset? {
        return codecPresets.first { $0.name == name }
    }
    
    /// Codec feature comparison
    struct CodecFeatures {
        let codec: String
        let displayName: String
        let compressionEfficiency: Int  // 1-10 scale
        let encodingSpeed: Int          // 1-10 scale (10 = fastest)
        let compatibility: Int          // 1-10 scale (10 = most compatible)
        let hardwareSupport: Bool
        let recommendedFor: [String]
        let notes: String
    }
    
    /// Comparison of codec features
    static let codecFeatures: [CodecFeatures] = [
        CodecFeatures(
            codec: "h264",
            displayName: "H.264 (AVC)",
            compressionEfficiency: 7,
            encodingSpeed: 9,
            compatibility: 10,
            hardwareSupport: true,
            recommendedFor: ["Universal compatibility", "Older devices", "Fast encoding"],
            notes: "Most widely supported codec. Best for maximum compatibility."
        ),
        CodecFeatures(
            codec: "h265",
            displayName: "H.265 (HEVC)",
            compressionEfficiency: 8,
            encodingSpeed: 6,
            compatibility: 7,
            hardwareSupport: true,
            recommendedFor: ["4K content", "HDR video", "Modern devices"],
            notes: "50% better compression than H.264. Excellent for 4K/HDR."
        ),
        CodecFeatures(
            codec: "av1",
            displayName: "AV1",
            compressionEfficiency: 10,
            encodingSpeed: 3,
            compatibility: 5,
            hardwareSupport: false,
            recommendedFor: ["Maximum compression", "Future-proof archival", "8K content"],
            notes: "State-of-the-art compression. Slow encoding but unmatched efficiency."
        ),
        CodecFeatures(
            codec: "vp9",
            displayName: "VP9",
            compressionEfficiency: 8,
            encodingSpeed: 5,
            compatibility: 6,
            hardwareSupport: false,
            recommendedFor: ["Web streaming", "YouTube", "Open-source workflows"],
            notes: "Open-source codec with excellent compression. Great for web delivery."
        )
    ]
    
    /// Get codec features by codec identifier
    static func features(for codec: String) -> CodecFeatures? {
        return codecFeatures.first { $0.codec == codec }
    }
}
