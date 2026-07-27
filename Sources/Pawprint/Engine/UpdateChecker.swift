import AppKit
import CryptoKit
import Observation
import Security

/// One release, as described by the update feed.
struct UpdateRelease: Codable, Equatable {
    var version: String            // marketing version, e.g. "1.2.0"
    var build: String?             // CFBundleVersion, used to break ties
    var notes: String?             // what changed, shown before installing
    var downloadURL: String        // .zip containing Pawprint.app
    var minimumSystemVersion: String?
    var publishedAt: String?

    /// Base64 Ed25519 signature of the downloaded archive, produced by `scripts/updatekeys.swift`.
    var signature: String?

    var downloadLink: URL? { URL(string: downloadURL) }
}

/// The shape GitHub's Releases API returns. Mapped onto `UpdateRelease` so the app can point
/// straight at `api.github.com` with no extra file to publish and keep in sync.
private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }
    let tag_name: String
    let name: String?
    let body: String?
    let draft: Bool?
    let prerelease: Bool?
    let published_at: String?
    let assets: [Asset]

    /// GitHub has no field for our signature, so the workflow uploads it as a tiny `.sig` asset
    /// alongside the archive and the app fetches it separately.
    func asUpdateRelease() -> UpdateRelease? {
        guard let archive = assets.first(where: { $0.name.hasSuffix(".zip") }) else { return nil }
        return UpdateRelease(
            version: tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name,
            build: nil,
            notes: body,
            downloadURL: archive.browser_download_url,
            minimumSystemVersion: "14.0",
            publishedAt: published_at,
            signature: assets.first(where: { $0.name.hasSuffix(".zip.sig") })?.browser_download_url
        )
    }
}

/// Checks for, downloads, and installs updates for a directly-distributed build.
///
/// Pawprint isn't on the App Store, so nothing updates it for us. It also promises to work fully
/// offline and to make no network request the user didn't ask for — so this is **opt-in and off by
/// default**, and the only request it ever makes is a plain GET for the feed and the download. No
/// identifiers, no usage data, no telemetry: the feed URL is fetched exactly as typed.
///
/// **Trust model.** The feed is plain JSON over the network and could be substituted, so what
/// decides whether code is trusted is a signature, never a URL. Two independent checks:
///
///  1. **Ed25519 over the archive bytes**, against a public key compiled into this app. The
///     matching private key lives only in the release workflow's secrets. This is the primary
///     gate and the one that works everywhere.
///  2. **Code signing**, when it can say anything useful: the downloaded app must satisfy the
///     running app's designated requirement. Skipped for ad-hoc-signed builds, whose requirement
///     is a content hash that by construction never matches a different build — demanding it
///     there would reject every update rather than add safety.
///
/// Without check 1 passing, nothing is installed. A release published without a signature is
/// treated as untrusted and offered as a manual browser download only.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate(checkedAt: Date)
        case available(UpdateRelease)
        case downloading(progress: Double)
        case readyToInstall(UpdateRelease)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastCheckedAt: Date?

    /// Where the verified, unpacked replacement is staged until the user installs it.
    private var stagedAppURL: URL?
    private var stagingRoot: URL?

    static var updatePublicKey: String { UpdateDistribution.publicKey }

    private var scheduleTimer: Timer?

    private init() {}

    /// Checks now (after a short delay so launch isn't competing with the network) and then on a
    /// slow repeat. Six hours is chosen to be useful without being a poll: releases are occasional,
    /// and a user who leaves the app running for a week should still hear about one.
    func startPeriodicChecks(settings: AppSettings) {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        guard settings.updateCheckEnabled,
              settings.updateCheckAutomatically,
              !settings.updateFeedURL.isEmpty else { return }

        let feed = settings.updateFeedURL
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            await self.checkIfIdle(feedURL: feed)
        }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in await self.checkIfIdle(feedURL: feed) }
        }
    }

    func stopPeriodicChecks() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }

    /// A background check must never disturb a download the user started, or clear an update
    /// they have already been offered.
    private func checkIfIdle(feedURL: String) async {
        switch state {
        case .idle, .upToDate, .failed:
            await check(feedURL: feedURL, manual: false)
        case .checking, .downloading, .available, .readyToInstall:
            return
        }
    }

    /// One-tap path for the popover banner: fetch, verify, install, relaunch.
    func downloadAndInstall(_ release: UpdateRelease) async {
        await download(release)
        guard case .readyToInstall = state else { return }
        install()
    }

    /// Snapshot-only: puts the checker into a given state so each banner variant can be rendered
    /// without a real release to react to. Reachable only from `DebugSnapshot`, which needs an
    /// environment variable to run at all.
    func debugForceState(_ forced: State) { state = forced }

    /// Set while an update is worth showing in the UI.
    var pendingRelease: UpdateRelease? {
        switch state {
        case .available(let release), .readyToInstall(let release): return release
        default: return nil
        }
    }
}

/// Distribution constants, kept outside the `@MainActor` class so non-isolated types such as
/// `AppSettings` can read them without hopping actors.
enum UpdateDistribution {
    /// Public half of the update signing key. The private half is a GitHub Actions secret.
    /// Changing this invalidates every previously published release — rotate deliberately.
    static let publicKey = "WFrwhuof35wfjgGTjm5WwGXW8BlHb6DnXYKNcfoOiBc="

    /// GitHub Releases for this repository. Ships as the default so a fresh install already
    /// knows where updates come from; the setting itself is still off until the user opts in.
    static let feedURL = "https://api.github.com/repos/yhcho0405/Pawprint/releases/latest"
}

extension UpdateChecker {
    static var defaultFeedURL: String { UpdateDistribution.feedURL }

    // MARK: - Current version

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    // MARK: - Checking

    /// Fetches the feed and decides whether it describes something newer.
    ///
    /// `manual` only affects messaging: a background check that finds nothing should stay silent,
    /// while a check the user asked for should say "최신 버전이에요" so the button doesn't feel dead.
    func check(feedURL: String, manual: Bool) async {
        guard let url = URL(string: feedURL), url.scheme == "https" || url.scheme == "file" else {
            state = .failed(L10n.t("updateChecker.0cf8ad1b"))
            return
        }

        state = .checking
        do {
            var request = URLRequest(url: url)
            // Nothing identifying: no cookies, no cache validators tied to this install.
            request.httpShouldHandleCookies = false
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                state = .failed(L10n.t("updateChecker.1bece787", http.statusCode))
                return
            }

            let release: UpdateRelease
            if let github = try? JSONDecoder().decode(GitHubRelease.self, from: data) {
                if github.draft == true {
                    state = .failed(L10n.t("updateChecker.0c63ecbb"))
                    return
                }
                guard let mapped = github.asUpdateRelease() else {
                    state = .failed(L10n.t("updateChecker.f065798f"))
                    return
                }
                release = mapped
            } else {
                release = try JSONDecoder().decode(UpdateRelease.self, from: data)
            }
            lastCheckedAt = Date()

            guard release.downloadLink != nil else {
                state = .failed(L10n.t("updateChecker.b6ebf2ae"))
                return
            }
            if let minimum = release.minimumSystemVersion, !systemMeets(minimum) {
                state = .failed(L10n.t("updateChecker.0d8b1254", minimum))
                return
            }
            if isNewer(release) {
                state = .available(release)
            } else {
                state = .upToDate(checkedAt: Date())
                if !manual { state = .idle }
            }
        } catch {
            state = .failed(L10n.t("updateChecker.c3a641cc", error.localizedDescription))
        }
    }

    /// Compares marketing versions component-wise, falling back to the build number on a tie.
    /// String comparison would rank "1.10.0" below "1.9.0".
    func isNewer(_ release: UpdateRelease) -> Bool {
        switch compare(release.version, currentVersion) {
        case .orderedDescending: return true
        case .orderedAscending: return false
        case .orderedSame:
            guard let build = release.build else { return false }
            return compare(build, currentBuild) == .orderedDescending
        }
    }

    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = lhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }

    private func systemMeets(_ minimum: String) -> Bool {
        let current = ProcessInfo.processInfo.operatingSystemVersion
        let running = "\(current.majorVersion).\(current.minorVersion).\(current.patchVersion)"
        return compare(running, minimum) != .orderedAscending
    }

    // MARK: - Downloading

    func download(_ release: UpdateRelease) async {
        guard let link = release.downloadLink else {
            state = .failed(L10n.t("updateChecker.d9383631"))
            return
        }
        state = .downloading(progress: 0)
        cleanUpStaging()

        do {
            let (temporaryFile, response) = try await URLSession.shared.download(from: link)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                state = .failed(L10n.t("updateChecker.f0ce876e", http.statusCode))
                return
            }
            state = .downloading(progress: 0.7)

            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("PawprintUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            stagingRoot = root

            let archive = root.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: temporaryFile, to: archive)

            // Signature first: nothing gets unpacked, let alone executed, until the bytes are
            // proven to have come from the holder of the update key.
            try await verifyArchiveSignature(archive, release: release)
            state = .downloading(progress: 0.8)

            let unpacked = root.appendingPathComponent("unpacked")
            try unzip(archive, to: unpacked)
            state = .downloading(progress: 0.9)

            guard let app = findApp(in: unpacked) else {
                state = .failed(L10n.t("updateChecker.857994c9"))
                return
            }
            try verifySignature(of: app)

            stagedAppURL = app
            state = .readyToInstall(release)
        } catch let error as UpdateError {
            cleanUpStaging()
            state = .failed(error.message)
        } catch {
            cleanUpStaging()
            state = .failed(L10n.t("updateChecker.11fd7315", error.localizedDescription))
        }
    }

    struct UpdateError: Error { let message: String }

    /// Ed25519 check of the archive against the pinned public key.
    ///
    /// `release.signature` may be the signature itself or a URL to a `.sig` file — GitHub has no
    /// field for arbitrary metadata, so the workflow uploads it as an asset and this fetches it.
    private func verifyArchiveSignature(_ archive: URL, release: UpdateRelease) async throws {
        guard let reference = release.signature, !reference.isEmpty else {
            throw UpdateError(message: L10n.t("updateChecker.2add0994"))
        }

        let encodedSignature: String
        if reference.hasPrefix("https://") {
            guard let url = URL(string: reference) else {
                throw UpdateError(message: L10n.t("updateChecker.6635b1c3"))
            }
            var request = URLRequest(url: url)
            request.httpShouldHandleCookies = false
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            encodedSignature = String(decoding: data, as: UTF8.self)
        } else {
            encodedSignature = reference
        }

        guard let signature = Data(base64Encoded: encodedSignature.trimmingCharacters(in: .whitespacesAndNewlines)),
              let rawKey = Data(base64Encoded: Self.updatePublicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
            throw UpdateError(message: L10n.t("updateChecker.6156b73b"))
        }
        guard let payload = FileManager.default.contents(atPath: archive.path) else {
            throw UpdateError(message: L10n.t("updateChecker.e50e9207"))
        }
        guard key.isValidSignature(signature, for: payload) else {
            throw UpdateError(message: L10n.t("updateChecker.79d0bb3f"))
        }
    }

    /// True when the running app carries only an ad-hoc signature, whose designated requirement is
    /// a hash of this exact build and therefore can never be satisfied by a newer one.
    private func runningAppIsAdHocSigned() -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess,
              let code else { return false }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [String: Any] else { return false }
        // An ad-hoc signature has no certificate chain at all.
        let certificates = dictionary[kSecCodeInfoCertificates as String] as? [Any]
        return (certificates?.isEmpty ?? true)
    }

    /// `ditto` rather than `unzip`: it is the tool that round-trips macOS archives without
    /// mangling symlinks and extended attributes, and a mangled bundle fails signature checks.
    private func unzip(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError(message: L10n.t("updateChecker.6eb64361"))
        }
    }

    private func findApp(in directory: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        if let direct = contents.first(where: { $0.pathExtension == "app" }) { return direct }
        // Some zips wrap the app in a folder.
        for entry in contents {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            if let nested = findApp(in: entry) { return nested }
        }
        return nil
    }

    /// The downloaded app must satisfy the running app's own designated requirement.
    ///
    /// This is the whole security model for a self-distributed updater: the feed is plain JSON over
    /// the network and could be substituted, so the signature — not the URL — is what decides
    /// whether the code is trusted.
    private func verifySignature(of app: URL) throws {
        // For an ad-hoc build this check can only ever fail, so skip it and lean on the Ed25519
        // signature, which has already passed by the time we get here.
        guard !runningAppIsAdHocSigned() else { return }

        var selfCode: SecCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode else {
            throw UpdateError(message: L10n.t("updateChecker.134c2360"))
        }
        var selfStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic else {
            throw UpdateError(message: L10n.t("updateChecker.134c2360"))
        }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess,
              let requirement else {
            throw UpdateError(message: L10n.t("updateChecker.d7cab622"))
        }

        var candidate: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess,
              let candidate else {
            throw UpdateError(message: L10n.t("updateChecker.dae64861"))
        }
        let status = SecStaticCodeCheckValidity(candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement)
        guard status == errSecSuccess else {
            throw UpdateError(
                message: L10n.t("updateChecker.6e00548a", status)
            )
        }
    }

    // MARK: - Installing

    /// Swaps the bundle and relaunches.
    ///
    /// The swap runs in a detached shell script rather than in-process, because the app being
    /// replaced is the one doing the replacing — it has to be gone before its bundle can move.
    func install() {
        guard let staged = stagedAppURL else {
            state = .failed(L10n.t("updateChecker.3576a9f7"))
            return
        }
        let destination = Bundle.main.bundleURL
        guard destination.pathExtension == "app" else {
            state = .failed(L10n.t("updateChecker.85af4b0c"))
            return
        }

        let script = """
        #!/bin/sh
        # Wait for the running copy to exit before touching its bundle.
        for _ in $(seq 1 100); do
            kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null || break
            sleep 0.1
        done
        rm -rf "\(destination.path).old"
        mv "\(destination.path)" "\(destination.path).old" || exit 1
        if ! mv "\(staged.path)" "\(destination.path)"; then
            # Put the original back rather than leaving the user with no app at all.
            mv "\(destination.path).old" "\(destination.path)"
            exit 1
        fi
        rm -rf "\(destination.path).old"
        xattr -dr com.apple.quarantine "\(destination.path)" 2>/dev/null
        open "\(destination.path)"
        """

        guard let root = stagingRoot else {
            state = .failed(L10n.t("updateChecker.8b79e3fd"))
            return
        }
        let scriptURL = root.appendingPathComponent("install.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [scriptURL.path]
            try process.run()
        } catch {
            state = .failed(L10n.t("updateChecker.634bd356", error.localizedDescription))
            return
        }
        NSApp.terminate(nil)
    }

    /// Opens the download in a browser, for anyone who would rather install it by hand.
    func openDownloadPage(_ release: UpdateRelease) {
        guard let link = release.downloadLink else { return }
        NSWorkspace.shared.open(link)
    }

    func dismiss() {
        cleanUpStaging()
        state = .idle
    }

    private func cleanUpStaging() {
        if let root = stagingRoot { try? FileManager.default.removeItem(at: root) }
        stagingRoot = nil
        stagedAppURL = nil
    }
}
