import Foundation

extension MainViewController {

    private static let omdbAPIKey = "6132cfef"

    /// Tokens that appear in disc volume labels but are not part of the movie
    /// title (screener marks, disc numbers, format/region tags).
    private static let volumeLabelJunk: Set<String> = [
        "scn", "screener", "promo", "disc", "disc1", "disc2", "d1", "d2",
        "ws", "fs", "se", "ce", "r1", "r2", "r4", "ntsc", "pal", "dvd",
        "bluray", "bd", "video", "widescreen", "fullscreen", "extended",
        "unrated", "theatrical", "special", "edition", "collectors", "anamorphic"
    ]

    /// Looks up a movie title via OMDb using the disc volume name as a search term.
    /// Junk label tokens are stripped first; the raw name is retried as a fallback.
    /// Calls back on the main thread with "Title (Year)", or nil if nothing found.
    func lookupDiscTitle(volumeName: String, completion: @escaping (String?) -> Void) {
        let words = volumeName
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ").map(String.init)
        let cleanedWords = words.filter {
            !Self.volumeLabelJunk.contains($0.lowercased()) && Int($0) == nil
        }

        let raw = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let cleaned = cleanedWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)

        var candidates: [String] = []
        if !cleaned.isEmpty { candidates.append(cleaned) }
        if !raw.isEmpty, raw.caseInsensitiveCompare(cleaned) != .orderedSame {
            candidates.append(raw)
        }

        tryLookup(candidates: candidates, completion: completion)
    }

    private func tryLookup(candidates: [String], completion: @escaping (String?) -> Void) {
        guard let query = candidates.first else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        appendToLog("Looking up '\(query)' on OMDb...")
        searchOMDb(query: query) { [weak self] result in
            if let result = result {
                DispatchQueue.main.async { completion(result) }
            } else {
                self?.tryLookup(candidates: Array(candidates.dropFirst()), completion: completion)
            }
        }
    }

    private func searchOMDb(query: String, completion: @escaping (String?) -> Void) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.omdbapi.com/?s=\(encoded)&type=movie&apikey=\(Self.omdbAPIKey)")
        else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["Response"] as? String, response == "True",
                  let results = json["Search"] as? [[String: Any]]
            else {
                completion(nil)
                return
            }

            // Prefer an exact title match over OMDb's first (often older) hit
            let exact = results.first {
                ($0["Title"] as? String)?.caseInsensitiveCompare(query) == .orderedSame
            }
            guard let match = exact ?? results.first,
                  let title = match["Title"] as? String else {
                completion(nil)
                return
            }

            let year = (match["Year"] as? String).map { " (\($0))" } ?? ""
            completion("\(title)\(year)")
        }.resume()
    }
}
