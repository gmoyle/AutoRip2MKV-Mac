import Foundation

extension MainViewController {

    private static let omdbAPIKey = "6132cfef"

    /// Looks up a movie title via OMDb using the disc volume name as a search term.
    /// Calls back on the main thread with the resolved title, or nil if nothing found.
    func lookupDiscTitle(volumeName: String, completion: @escaping (String?) -> Void) {
        let query = volumeName
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.omdbapi.com/?s=\(encoded)&type=movie&apikey=\(Self.omdbAPIKey)")
        else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        appendToLog("Looking up '\(query)' on OMDb...")

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["Response"] as? String, response == "True",
                  let results = json["Search"] as? [[String: Any]],
                  let first = results.first,
                  let title = first["Title"] as? String
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let year = (first["Year"] as? String).map { " (\($0))" } ?? ""
            DispatchQueue.main.async { completion("\(title)\(year)") }
        }.resume()
    }
}
