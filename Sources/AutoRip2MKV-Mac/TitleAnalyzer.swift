// TitleAnalyzer.swift
// AutoRip2MKV-Mac
// Phase 2 Task 3: Intelligent Title Selection
// Created: 2026-02-01

import Foundation

/// Intelligent title/playlist analysis and filtering system
class TitleAnalyzer {
    
    // MARK: - Configuration
    
    struct FilteringRules {
        var skipMenus: Bool = true
        var skipTrailers: Bool = true
        var skipDuplicates: Bool = true
        var minMainFeatureDuration: TimeInterval = 3600 // 60 minutes
        var minBonusFeatureDuration: TimeInterval = 300 // 5 minutes
        var preferLongestTitle: Bool = true
        var autoSelectMainFeature: Bool = true
        
        init() {}
    }
    
    // MARK: - Analysis Results
    
    struct TitleScore {
        let titleNumber: Int
        let score: Double
        let classification: ContentClassification
        let reasons: [String]
        
        enum ContentClassification {
            case mainFeature
            case extendedEdition
            case bonusFeature
            case trailer
            case menu
            case duplicate
            case unknown
            
            var displayName: String {
                switch self {
                case .mainFeature: return "Main Feature"
                case .extendedEdition: return "Extended Edition"
                case .bonusFeature: return "Bonus Feature"
                case .trailer: return "Trailer"
                case .menu: return "Menu/Warning"
                case .duplicate: return "Duplicate"
                case .unknown: return "Unknown"
                }
            }
        }
    }
    
    // MARK: - DVD Title Analysis
    
    /// Analyze and score DVD titles for intelligent selection
    func analyzeDVDTitles(_ titles: [DVDTitle], rules: FilteringRules) -> [TitleScore] {
        guard !titles.isEmpty else { return [] }
        
        var scores: [TitleScore] = []
        let longestDuration = titles.map { $0.duration }.max() ?? 0
        let totalTitles = titles.count
        
        for (index, title) in titles.enumerated() {
            var score = 0.0
            var reasons: [String] = []
            var classification: TitleScore.ContentClassification = .unknown
            
            // Duration analysis (40% of score)
            let durationScore = calculateDurationScore(
                duration: title.duration,
                longestDuration: longestDuration,
                minMainFeature: rules.minMainFeatureDuration,
                minBonus: rules.minBonusFeatureDuration
            )
            score += durationScore * 0.4
            
            if title.duration >= rules.minMainFeatureDuration {
                reasons.append("Duration: \(title.formattedDuration) (feature-length)")
            } else if title.duration < 120 {
                reasons.append("Duration: \(title.formattedDuration) (very short)")
            }
            
            // Chapter analysis (20% of score)
            let chapterScore = calculateChapterScore(chapters: title.chaptersCount)
            score += chapterScore * 0.2
            
            if title.chaptersCount >= 8 {
                reasons.append("Chapters: \(title.chaptersCount) (structured content)")
            } else if title.chaptersCount <= 1 {
                reasons.append("Chapters: \(title.chaptersCount) (likely menu/warning)")
            }
            
            // Position analysis (15% of score)
            let positionScore = calculatePositionScore(index: index, total: totalTitles)
            score += positionScore * 0.15
            
            if index == 0 {
                reasons.append("Position: First title")
            }
            
            // Size analysis (15% of score)
            let sizeScore = calculateSizeScore(sectors: title.sectors, chaptersCount: title.chaptersCount)
            score += sizeScore * 0.15
            
            // Angle analysis (10% of score)
            let angleScore = calculateAngleScore(angles: title.angles, duration: title.duration)
            score += angleScore * 0.1
            
            if title.angles > 1 {
                reasons.append("Angles: \(title.angles) (multi-angle content)")
            }
            
            // Classify based on score and heuristics
            classification = classifyDVDTitle(
                title: title,
                score: score,
                index: index,
                longestDuration: longestDuration,
                rules: rules
            )
            
            scores.append(TitleScore(
                titleNumber: title.number,
                score: score,
                classification: classification,
                reasons: reasons
            ))
        }
        
        // Detect duplicates
        scores = detectDuplicates(scores: scores, titles: titles)
        
        return scores
    }
    
    /// Filter DVD titles based on analysis and rules
    func filterDVDTitles(_ titles: [DVDTitle], rules: FilteringRules) -> [DVDTitle] {
        let scores = analyzeDVDTitles(titles, rules: rules)
        var filtered: [DVDTitle] = []
        
        for (title, score) in zip(titles, scores) {
            // Apply filtering rules
            if rules.skipMenus && score.classification == .menu {
                continue
            }
            if rules.skipTrailers && score.classification == .trailer {
                continue
            }
            if rules.skipDuplicates && score.classification == .duplicate {
                continue
            }
            
            // Check minimum durations
            if score.classification == .mainFeature || score.classification == .extendedEdition {
                if title.duration >= rules.minMainFeatureDuration {
                    filtered.append(title)
                }
            } else if score.classification == .bonusFeature {
                if title.duration >= rules.minBonusFeatureDuration {
                    filtered.append(title)
                }
            } else if score.classification != .menu && score.classification != .trailer {
                filtered.append(title)
            }
        }
        
        // Auto-select main feature if enabled
        if rules.autoSelectMainFeature && filtered.count > 1 {
            if let mainFeature = selectMainFeature(from: scores, titles: titles, rules: rules) {
                return [mainFeature]
            }
        }
        
        return filtered
    }
    
    // MARK: - Blu-ray Playlist Analysis
    
    /// Analyze and score Blu-ray playlists for intelligent selection
    func analyzeBluRayPlaylists(_ playlists: [BluRayPlaylist], rules: FilteringRules) -> [TitleScore] {
        guard !playlists.isEmpty else { return [] }
        
        var scores: [TitleScore] = []
        let longestDuration = playlists.map { $0.duration }.max() ?? 0
        let totalPlaylists = playlists.count
        
        for (index, playlist) in playlists.enumerated() {
            var score = 0.0
            var reasons: [String] = []
            var classification: TitleScore.ContentClassification = .unknown
            
            // Duration analysis (40% of score)
            let durationScore = calculateDurationScore(
                duration: playlist.duration,
                longestDuration: longestDuration,
                minMainFeature: rules.minMainFeatureDuration,
                minBonus: rules.minBonusFeatureDuration
            )
            score += durationScore * 0.4
            
            if playlist.duration >= rules.minMainFeatureDuration {
                reasons.append("Duration: \(playlist.formattedDuration) (feature-length)")
            } else if playlist.duration < 120 {
                reasons.append("Duration: \(playlist.formattedDuration) (very short)")
            }
            
            // Chapter analysis (20% of score)
            let chapterScore = calculateChapterScore(chapters: playlist.chapterCount)
            score += chapterScore * 0.2
            
            if playlist.chapterCount >= 8 {
                reasons.append("Chapters: \(playlist.chapterCount) (structured content)")
            } else if playlist.chapterCount <= 1 {
                reasons.append("Chapters: \(playlist.chapterCount) (likely menu/warning)")
            }
            
            // Position analysis (15% of score)
            let positionScore = calculatePositionScore(index: index, total: totalPlaylists)
            score += positionScore * 0.15
            
            if index == 0 {
                reasons.append("Position: First playlist")
            }
            
            // Size analysis (15% of score)
            let sizeScore = calculateSizeScoreBluRay(size: playlist.totalSize, duration: playlist.duration)
            score += sizeScore * 0.15
            
            // Clip count analysis (10% of score)
            let clipScore = calculateClipScore(clipCount: playlist.playItems.count)
            score += clipScore * 0.1
            
            if playlist.playItems.count > 5 {
                reasons.append("Clips: \(playlist.playItems.count) (complex structure)")
            }
            
            // Classify based on score and heuristics
            classification = classifyBluRayPlaylist(
                playlist: playlist,
                score: score,
                index: index,
                longestDuration: longestDuration,
                rules: rules
            )
            
            scores.append(TitleScore(
                titleNumber: playlist.number,
                score: score,
                classification: classification,
                reasons: reasons
            ))
        }
        
        // Detect duplicates
        scores = detectDuplicatesPlaylists(scores: scores, playlists: playlists)
        
        return scores
    }
    
    /// Filter Blu-ray playlists based on analysis and rules
    func filterBluRayPlaylists(_ playlists: [BluRayPlaylist], rules: FilteringRules) -> [BluRayPlaylist] {
        let scores = analyzeBluRayPlaylists(playlists, rules: rules)
        var filtered: [BluRayPlaylist] = []
        
        for (playlist, score) in zip(playlists, scores) {
            // Apply filtering rules
            if rules.skipMenus && score.classification == .menu {
                continue
            }
            if rules.skipTrailers && score.classification == .trailer {
                continue
            }
            if rules.skipDuplicates && score.classification == .duplicate {
                continue
            }
            
            // Check minimum durations
            if score.classification == .mainFeature || score.classification == .extendedEdition {
                if playlist.duration >= rules.minMainFeatureDuration {
                    filtered.append(playlist)
                }
            } else if score.classification == .bonusFeature {
                if playlist.duration >= rules.minBonusFeatureDuration {
                    filtered.append(playlist)
                }
            } else if score.classification != .menu && score.classification != .trailer {
                filtered.append(playlist)
            }
        }
        
        // Auto-select main feature if enabled
        if rules.autoSelectMainFeature && filtered.count > 1 {
            if let mainFeature = selectMainFeaturePlaylist(from: scores, playlists: playlists, rules: rules) {
                return [mainFeature]
            }
        }
        
        return filtered
    }
    
    // MARK: - Scoring Algorithms
    
    private func calculateDurationScore(
        duration: TimeInterval,
        longestDuration: TimeInterval,
        minMainFeature: TimeInterval,
        minBonus: TimeInterval
    ) -> Double {
        // Very short content (< 2 min) = menu/warning
        if duration < 120 {
            return 0.1
        }
        
        // Short content (2-5 min) = trailer/intro
        if duration < minBonus {
            return 0.3
        }
        
        // Bonus feature length (5-60 min)
        if duration < minMainFeature {
            return 0.5 + (duration / minMainFeature) * 0.2
        }
        
        // Feature length (60-90 min)
        if duration < 5400 {
            return 0.8
        }
        
        // Long feature (90+ min) - likely main movie
        let ratio = min(duration / longestDuration, 1.0)
        return 0.8 + (ratio * 0.2)
    }
    
    private func calculateChapterScore(chapters: Int) -> Double {
        if chapters == 0 || chapters == 1 {
            return 0.2 // Likely menu or simple trailer
        } else if chapters >= 2 && chapters < 4 {
            return 0.5 // Short content with some structure
        } else if chapters >= 4 && chapters < 8 {
            return 0.7 // Moderate structure
        } else {
            return 1.0 // Well-structured feature (8+ chapters)
        }
    }
    
    private func calculatePositionScore(index: Int, total: Int) -> Double {
        // First title often main feature, but not always
        if index == 0 {
            return 0.8
        } else if index == 1 {
            return 0.6
        } else if index < total / 2 {
            return 0.5
        } else {
            return 0.3 // Later titles often bonus content
        }
    }
    
    private func calculateSizeScore(sectors: UInt32, chaptersCount: Int) -> Double {
        // Estimate content density
        let sectorsPerChapter = chaptersCount > 0 ? Double(sectors) / Double(chaptersCount) : Double(sectors)
        
        if sectorsPerChapter < 1000 {
            return 0.2 // Very small = menu
        } else if sectorsPerChapter < 10000 {
            return 0.5 // Small = trailer/bonus
        } else if sectorsPerChapter < 50000 {
            return 0.8 // Medium = feature
        } else {
            return 1.0 // Large = main feature
        }
    }
    
    private func calculateSizeScoreBluRay(size: UInt64, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0.5 }
        
        // Calculate bitrate (bytes per second)
        let bitrate = Double(size) / duration
        
        // Blu-ray typical bitrates:
        // Menu: < 5 MB/s
        // Trailer: 5-15 MB/s
        // Feature: 15-40 MB/s
        // High bitrate feature: > 40 MB/s
        
        let mbps = bitrate / (1024 * 1024)
        
        if mbps < 5 {
            return 0.2
        } else if mbps < 15 {
            return 0.5
        } else if mbps < 30 {
            return 0.8
        } else {
            return 1.0
        }
    }
    
    private func calculateAngleScore(angles: Int, duration: TimeInterval) -> Double {
        // Multi-angle content is usually main feature or bonus
        if angles == 1 {
            return 0.7 // Standard
        } else if duration < 300 {
            return 0.3 // Short multi-angle = menu navigation
        } else {
            return 1.0 // Feature-length multi-angle
        }
    }
    
    private func calculateClipScore(clipCount: Int) -> Double {
        if clipCount == 1 {
            return 0.6 // Simple single clip
        } else if clipCount >= 2 && clipCount <= 5 {
            return 0.8 // Standard feature structure
        } else if clipCount > 5 && clipCount <= 20 {
            return 1.0 // Complex feature (seamless branching, etc.)
        } else {
            return 0.4 // Too many clips = compilation or menu
        }
    }
    
    // MARK: - Classification
    
    private func classifyDVDTitle(
        title: DVDTitle,
        score: Double,
        index: Int,
        longestDuration: TimeInterval,
        rules: FilteringRules
    ) -> TitleScore.ContentClassification {
        // Menu detection
        if title.duration < 120 || (title.chaptersCount <= 1 && title.duration < 300) {
            return .menu
        }
        
        // Trailer detection
        if title.duration >= 120 && title.duration < rules.minBonusFeatureDuration && title.chaptersCount <= 2 {
            return .trailer
        }
        
        // Main feature detection
        if title.duration >= rules.minMainFeatureDuration {
            if title.duration >= 5400 || // 90+ minutes
               (index == 0 && title.duration >= 3600) || // First title, 60+ minutes
               title.duration == longestDuration {
                return .mainFeature
            } else if title.duration > longestDuration * 1.05 {
                // Slightly longer than "main" = extended edition
                return .extendedEdition
            } else {
                return .bonusFeature
            }
        }
        
        // Bonus feature
        if title.duration >= rules.minBonusFeatureDuration {
            return .bonusFeature
        }
        
        return .unknown
    }
    
    private func classifyBluRayPlaylist(
        playlist: BluRayPlaylist,
        score: Double,
        index: Int,
        longestDuration: TimeInterval,
        rules: FilteringRules
    ) -> TitleScore.ContentClassification {
        // Menu detection
        if playlist.duration < 120 || (playlist.chapterCount <= 1 && playlist.duration < 300) {
            return .menu
        }
        
        // Trailer detection
        if playlist.duration >= 120 && playlist.duration < rules.minBonusFeatureDuration && playlist.chapterCount <= 2 {
            return .trailer
        }
        
        // Main feature detection
        if playlist.duration >= rules.minMainFeatureDuration {
            if playlist.duration >= 5400 || // 90+ minutes
               (index == 0 && playlist.duration >= 3600) || // First playlist, 60+ minutes
               playlist.duration == longestDuration {
                return .mainFeature
            } else if playlist.duration > longestDuration * 1.05 {
                // Slightly longer than "main" = extended edition
                return .extendedEdition
            } else {
                return .bonusFeature
            }
        }
        
        // Bonus feature
        if playlist.duration >= rules.minBonusFeatureDuration {
            return .bonusFeature
        }
        
        return .unknown
    }
    
    // MARK: - Duplicate Detection
    
    private func detectDuplicates(scores: [TitleScore], titles: [DVDTitle]) -> [TitleScore] {
        var updatedScores = scores
        
        for i in 0..<titles.count {
            for j in (i + 1)..<titles.count {
                let title1 = titles[i]
                let title2 = titles[j]
                
                // Check for duplicate criteria
                let durationDiff = abs(title1.duration - title2.duration)
                let chapterDiff = abs(title1.chaptersCount - title2.chaptersCount)
                
                // Same duration within 5 seconds and same chapter count = likely duplicate
                if durationDiff < 5 && chapterDiff == 0 {
                    // Mark the lower-scored one as duplicate
                    if updatedScores[i].score < updatedScores[j].score {
                        updatedScores[i] = TitleScore(
                            titleNumber: updatedScores[i].titleNumber,
                            score: updatedScores[i].score,
                            classification: .duplicate,
                            reasons: updatedScores[i].reasons + ["Duplicate of title \(title2.number)"]
                        )
                    } else {
                        updatedScores[j] = TitleScore(
                            titleNumber: updatedScores[j].titleNumber,
                            score: updatedScores[j].score,
                            classification: .duplicate,
                            reasons: updatedScores[j].reasons + ["Duplicate of title \(title1.number)"]
                        )
                    }
                }
            }
        }
        
        return updatedScores
    }
    
    private func detectDuplicatesPlaylists(scores: [TitleScore], playlists: [BluRayPlaylist]) -> [TitleScore] {
        var updatedScores = scores
        
        for i in 0..<playlists.count {
            for j in (i + 1)..<playlists.count {
                let playlist1 = playlists[i]
                let playlist2 = playlists[j]
                
                // Check for duplicate criteria
                let durationDiff = abs(playlist1.duration - playlist2.duration)
                let chapterDiff = abs(playlist1.chapterCount - playlist2.chapterCount)
                
                // Same duration within 5 seconds and same chapter count = likely duplicate
                if durationDiff < 5 && chapterDiff == 0 {
                    // Mark the lower-scored one as duplicate
                    if updatedScores[i].score < updatedScores[j].score {
                        updatedScores[i] = TitleScore(
                            titleNumber: updatedScores[i].titleNumber,
                            score: updatedScores[i].score,
                            classification: .duplicate,
                            reasons: updatedScores[i].reasons + ["Duplicate of playlist \(playlist2.number)"]
                        )
                    } else {
                        updatedScores[j] = TitleScore(
                            titleNumber: updatedScores[j].titleNumber,
                            score: updatedScores[j].score,
                            classification: .duplicate,
                            reasons: updatedScores[j].reasons + ["Duplicate of playlist \(playlist1.number)"]
                        )
                    }
                }
            }
        }
        
        return updatedScores
    }
    
    // MARK: - Main Feature Selection
    
    private func selectMainFeature(
        from scores: [TitleScore],
        titles: [DVDTitle],
        rules: FilteringRules
    ) -> DVDTitle? {
        // Find main features
        let mainFeatures = scores.enumerated().filter {
            $0.element.classification == .mainFeature || $0.element.classification == .extendedEdition
        }
        
        if mainFeatures.isEmpty {
            return nil
        }
        
        // If multiple main features, choose based on preference
        if mainFeatures.count == 1 {
            return titles[mainFeatures[0].offset]
        }
        
        if rules.preferLongestTitle {
            // Compare by actual duration, not score
            let longestIndex = mainFeatures.max { titles[$0.offset].duration < titles[$1.offset].duration }?.offset
            return longestIndex != nil ? titles[longestIndex!] : nil
        } else {
            // Prefer first main feature
            return titles[mainFeatures[0].offset]
        }
    }
    
    private func selectMainFeaturePlaylist(
        from scores: [TitleScore],
        playlists: [BluRayPlaylist],
        rules: FilteringRules
    ) -> BluRayPlaylist? {
        // Find main features
        let mainFeatures = scores.enumerated().filter {
            $0.element.classification == .mainFeature || $0.element.classification == .extendedEdition
        }
        
        if mainFeatures.isEmpty {
            return nil
        }
        
        // If multiple main features, choose based on preference
        if mainFeatures.count == 1 {
            return playlists[mainFeatures[0].offset]
        }
        
        if rules.preferLongestTitle {
            // Compare by actual duration, not score
            let longestIndex = mainFeatures.max { playlists[$0.offset].duration < playlists[$1.offset].duration }?.offset
            return longestIndex != nil ? playlists[longestIndex!] : nil
        } else {
            // Prefer first main feature
            return playlists[mainFeatures[0].offset]
        }
    }
}
