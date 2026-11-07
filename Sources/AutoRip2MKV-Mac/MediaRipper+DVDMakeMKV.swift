import Foundation

// MARK: - DVD staging: MakeMKV first, libdvdcss fallback

/// Where one chosen DVD title will end up.
struct DVDTitlePlan {
    let index: Int
    let title: DVDTitle
    let outputFileName: String
    let outputPath: String
    /// Local (non-synced) path ffmpeg encodes into before the atomic move.
    let stagingPath: String
}

extension MediaRipper {

    /// Name a chosen title's output and clear stale output/staging from an
    /// interrupted earlier run.
    func planDVDTitle(_ title: DVDTitle, index: Int, totalTitles: Int,
                      configuration: RippingConfiguration, outputDirectory: String) -> DVDTitlePlan {
        let titleName = determineTitleName(title: title, titleIndex: index, totalTitles: totalTitles)
        let outputFileName: String
        if let plexBase = plexBaseName(from: configuration) {
            // Main feature is "<Movie (Year)>.mkv" so Plex matches it directly;
            // any extra titles get a distinguishing suffix
            outputFileName = index == 0 ? "\(plexBase).mkv" : "\(plexBase) - \(titleName).mkv"
        } else {
            outputFileName = "\(titleName)_\(title.formattedDuration.replacingOccurrences(of: ":", with: "-")).mkv"
        }
        let outputPath = outputDirectory.appending("/\(outputFileName)")
        let stagingPath = encodingStagingPath(for: outputPath)
        for path in [outputPath, stagingPath] where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        return DVDTitlePlan(index: index, title: title, outputFileName: outputFileName,
                            outputPath: outputPath, stagingPath: stagingPath)
    }

    /// Have MakeMKV remux each planned title into local staging. Returns plan
    /// index → staged MKV for the titles it handled; unmatched titles are left
    /// for the libdvdcss reader. Throws MakeMKV errors (the caller falls back
    /// only on notInstalled; registrationRequired fails the rip so the user is
    /// prompted for a key rather than getting a raw read that can't follow the
    /// disc's navigation).
    func stageDVDTitlesWithMakeMKV(dvdPath: String, plans: [DVDTitlePlan]) throws -> [Int: String] {
        guard let firstPlan = plans.first else { return [:] }
        let backend = MakeMKVBackend(isCancelled: { [weak self] in self?.shouldCancel ?? false })
        makemkvBackend = backend
        defer { makemkvBackend = nil }

        delegate?.mediaRipperDidUpdateStatus("Reading the DVD's title list with MakeMKV...")
        let makemkvTitles = try backend.scanTitles(
            for: dvdPath,
            onStatus: { [weak self] message in
                self?.delegate?.mediaRipperDidUpdateStatus("MakeMKV: \(message)")
            },
            onProgress: { [weak self] fraction in
                // The bar shows the scan, then restarts at 0 for the rip.
                DispatchQueue.main.async {
                    self?.delegate?.mediaRipperDidUpdateProgress(
                        fraction, currentItem: .dvdTitle(firstPlan.title), totalItems: plans.count)
                }
            })
        guard !makemkvTitles.isEmpty else {
            Logger.shared.log("MakeMKV listed no titles for \(dvdPath); using libdvdcss",
                              level: .warning, category: .dvdRipping)
            return [:]
        }
        let matches = Self.matchMakeMKVTitles(plans.map(\.title), to: makemkvTitles)

        var staged: [Int: String] = [:]
        for plan in plans {
            if shouldCancel { throw MediaRipperError.cancelled }
            guard let makemkvIndex = matches[plan.index] else {
                Logger.shared.log("No MakeMKV title matches DVD title \(plan.title.number) "
                                  + "(\(plan.title.formattedDuration)); using libdvdcss for it",
                                  level: .warning, category: .dvdRipping)
                continue
            }
            delegate?.mediaRipperDidUpdateStatus(
                "Ripping title \(plan.title.number) (\(plan.title.formattedDuration)) with MakeMKV...")

            // One scratch folder per title so the rip's output is unambiguous.
            let scratch = (encodingStagingPath(for: "probe") as NSString).deletingLastPathComponent
                + "/makemkv-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: scratch) }

            let total = Double(max(plans.count, 1))
            let files = try backend.rip(
                discPath: dvdPath,
                outputDirectory: scratch,
                minLengthSeconds: 0,   // must match the `info` scan, which indexed titles at 0
                titleSpec: String(makemkvIndex),
                onStatus: { [weak self] in self?.delegate?.mediaRipperDidUpdateStatus($0) },
                onProgress: { [weak self] fraction in
                    let overall = (Double(plan.index) + fraction) / total
                    DispatchQueue.main.async {
                        self?.delegate?.mediaRipperDidUpdateProgress(
                            overall, currentItem: .dvdTitle(plan.title), totalItems: plans.count)
                    }
                })
            guard let ripped = files.first else { throw MakeMKVBackend.MakeMKVError.noTitlesRipped }

            let sourcePath = encodingStagingPath(for: plan.outputPath + ".source.mkv")
            try? FileManager.default.removeItem(atPath: sourcePath)
            try FileManager.default.moveItem(atPath: ripped, toPath: sourcePath)
            staged[plan.index] = sourcePath
            Logger.shared.log("MakeMKV staged DVD title \(plan.title.number) as MakeMKV title \(makemkvIndex)",
                              level: .info, category: .dvdRipping)
        }
        return staged
    }

    /// Match the chosen DVD titles to MakeMKV's titles: by the source title
    /// number MakeMKV reports when present, otherwise by duration (closest
    /// wins, within 3 s or 1% of the length, whichever is larger: on discs with
    /// seamless branching the IFO's duration counts branch cells MakeMKV
    /// skips, e.g. The Goonies is 1:53:50 by IFO, 1:53:16 by MakeMKV). Each MakeMKV title is used at most once. Returns
    /// position in `dvdTitles` → MakeMKV title index.
    static func matchMakeMKVTitles(_ dvdTitles: [DVDTitle],
                                   to makemkvTitles: [MakeMKVBackend.Title]) -> [Int: Int] {
        var used = Set<Int>()
        var result: [Int: Int] = [:]
        for (position, dvd) in dvdTitles.enumerated() {
            let free = makemkvTitles.filter { !used.contains($0.index) }
            var pick = free.first { $0.sourceTitle == dvd.number }
            if pick == nil {
                pick = free
                    .compactMap { t -> (MakeMKVBackend.Title, Double)? in
                        guard let d = t.durationSeconds else { return nil }
                        let delta = abs(Double(d) - dvd.duration)
                        return delta <= max(3, dvd.duration * 0.01) ? (t, delta) : nil
                    }
                    .min { $0.1 < $1.1 || ($0.1 == $1.1 && $0.0.index < $1.0.index) }?
                    .0
            }
            if let pick = pick {
                used.insert(pick.index)
                result[position] = pick.index
            }
        }
        return result
    }

    /// Fallback: read and decrypt the title's sectors with libdvdcss into `path`.
    /// Opens the raw device on first use.
    func readTitleWithLibdvdcss(_ title: DVDTitle, dvdPath: String, to path: String,
                                titleIndex: Int, totalTitles: Int) throws {
        if dvdDecryptor == nil {
            delegate?.mediaRipperDidUpdateStatus("Initializing DVD CSS decryption...")
            guard let rawDevice = findRawDVDDevice(dvdPath: dvdPath) else {
                throw MediaRipperError.deviceNotFound
            }
            delegate?.mediaRipperDidUpdateStatus("Using device: \(rawDevice)")
            let decryptor = DVDDecryptor(devicePath: rawDevice)
            try decryptor.initializeDevice()
            dvdDecryptor = decryptor
        }
        let discStart = try discStartSector(of: title)
        _ = try dvdDecryptor!.getTitleKey(titleNumber: title.number, startSector: discStart)
        do {
            try readDVDTitle(title, from: discStart, to: path, titleIndex: titleIndex, totalTitles: totalTitles)
        } catch {
            try? FileManager.default.removeItem(atPath: path)
            throw error
        }
    }
}
