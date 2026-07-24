import Foundation

/// Whether a ripped disc holds a movie or an episodic TV season. This is the
/// content distinction Plex libraries care about (Movies vs. TV Shows), and it
/// is orthogonal to disc *format* (DVD/Blu-ray/UHD), which `MediaRipper.MediaType`
/// already covers.
enum ContentType: String, Codable {
    case movie
    case tvShow
    case unknown

    /// Human-readable label for UI (the Movie/TV toggle, review queue rows).
    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tvShow: return "TV Show"
        case .unknown: return "Unknown"
        }
    }
}

/// Classifies a disc as movie vs. TV season from the durations of the titles
/// MakeMKV enumerates. A disc doesn't state its content type, so we infer it
/// from structure: a TV season disc holds several similar-length episodes; a
/// movie disc holds one dominant feature plus short extras.
///
/// This is a best-effort guess. It returns a `Classification` carrying both the
/// verdict and a confidence, so callers can auto-route high-confidence guesses
/// and defer ambiguous ones to the user's review queue.
enum ContentTypeClassifier {

    struct Classification: Equatable {
        let type: ContentType
        /// 0…1. High means the structure strongly matches one shape.
        let confidence: Double
    }

    // Tunables for the episodic-cluster heuristic.
    /// Episode runtimes typically fall in this band (minutes). Below it is
    /// extras/trailers; above it is a feature film.
    static let episodeMinMinutes: Double = 18
    static let episodeMaxMinutes: Double = 65
    /// A movie's main feature is at least this long (minutes).
    static let featureMinMinutes: Double = 70
    /// Titles within this fractional spread of each other count as "same length".
    static let clusterTolerance: Double = 0.20
    /// Need at least this many similar-length titles to call it a season.
    static let minEpisodesForSeason = 3

    /// Classify from title durations in **seconds**. Order-independent.
    static func classify(titleDurationsSeconds: [Int]) -> Classification {
        let minutes = titleDurationsSeconds
            .map { Double($0) / 60.0 }
            .filter { $0 > 0 }
            .sorted()

        guard !minutes.isEmpty else {
            return Classification(type: .unknown, confidence: 0)
        }

        // Episodic signal: the largest cluster of similar-length titles that sit
        // inside the episode band.
        let episodeCandidates = minutes.filter { $0 >= episodeMinMinutes && $0 <= episodeMaxMinutes }
        let cluster = largestSimilarCluster(episodeCandidates, tolerance: clusterTolerance)

        // Movie signal: a single dominant feature-length title.
        let longest = minutes.last ?? 0
        let hasFeature = longest >= featureMinMinutes

        // Decide. An episodic cluster is the strongest signal for TV; a lone
        // long feature with no cluster is the strongest signal for a movie.
        if cluster.count >= minEpisodesForSeason {
            // Confidence grows with how many episodes cluster and how tight it is.
            let coverage = Double(cluster.count) / Double(minutes.count)
            let confidence = min(1.0, 0.55 + 0.1 * Double(cluster.count - minEpisodesForSeason) + 0.2 * coverage)
            return Classification(type: .tvShow, confidence: confidence)
        }

        if hasFeature {
            // A dominant feature that's clearly longer than everything else is a
            // confident movie; a feature with other longish titles is less sure.
            let secondLongest = minutes.count >= 2 ? minutes[minutes.count - 2] : 0
            let dominance = secondLongest > 0 ? (longest - secondLongest) / longest : 1.0
            let confidence = min(1.0, 0.6 + 0.35 * dominance)
            return Classification(type: .movie, confidence: confidence)
        }

        // Neither shape fit (e.g. a handful of medium titles, or only extras).
        // Guess based on count but flag low confidence for user review.
        if minutes.count == 1 {
            return Classification(type: .movie, confidence: 0.4)
        }
        return Classification(type: .unknown, confidence: 0.2)
    }

    /// The largest subset of `values` that are all within `tolerance` of a common
    /// center — i.e. the biggest group of "same length" titles. Values must be
    /// pre-sorted ascending.
    private static func largestSimilarCluster(_ values: [Double], tolerance: Double) -> [Double] {
        guard !values.isEmpty else { return [] }
        var best: [Double] = []
        // Sliding window: for each start, extend while the span stays within
        // tolerance of the window's smallest element.
        var start = 0
        for end in 0..<values.count {
            while values[end] - values[start] > tolerance * values[start] {
                start += 1
            }
            let window = Array(values[start...end])
            if window.count > best.count { best = window }
        }
        return best
    }
}
