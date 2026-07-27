import AppKit
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

    var downloadLink: URL? { URL(string: downloadURL) }
}

/// Checks for, downloads, and installs updates for a directly-distributed build.
///
/// Pawprint isn't on the App Store, so nothing updates it for us. It also promises to work fully
/// offline and to make no network request the user didn't ask for — so this is **opt-in and off by
/// default**, and the only request it ever makes is a plain GET for the feed and the download. No
/// identifiers, no usage data, no telemetry: the feed URL is fetched exactly as typed.
///
/// Installing verifies that the downloaded app satisfies the *running* app's designated code
/// signing requirement before anything is swapped. An update that isn't signed by the same
/// identity is refused — otherwise a hijacked feed URL would be a straight path to running
/// arbitrary code as the user.
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

    private init() {}

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
            state = .failed("업데이트 주소가 올바르지 않아요 (https 주소가 필요해요)")
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
                state = .failed("업데이트 서버가 \(http.statusCode)를 반환했어요")
                return
            }

            let release = try JSONDecoder().decode(UpdateRelease.self, from: data)
            lastCheckedAt = Date()

            guard release.downloadLink != nil else {
                state = .failed("업데이트 정보에 다운로드 주소가 없어요")
                return
            }
            if let minimum = release.minimumSystemVersion, !systemMeets(minimum) {
                state = .failed("이 업데이트는 macOS \(minimum) 이상이 필요해요")
                return
            }
            if isNewer(release) {
                state = .available(release)
            } else {
                state = .upToDate(checkedAt: Date())
                if !manual { state = .idle }
            }
        } catch {
            state = .failed("업데이트를 확인하지 못했어요 — \(error.localizedDescription)")
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
            state = .failed("다운로드 주소가 올바르지 않아요")
            return
        }
        state = .downloading(progress: 0)
        cleanUpStaging()

        do {
            let (temporaryFile, response) = try await URLSession.shared.download(from: link)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                state = .failed("다운로드에 실패했어요 (\(http.statusCode))")
                return
            }
            state = .downloading(progress: 0.7)

            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("PawprintUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            stagingRoot = root

            let archive = root.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: temporaryFile, to: archive)

            let unpacked = root.appendingPathComponent("unpacked")
            try unzip(archive, to: unpacked)
            state = .downloading(progress: 0.9)

            guard let app = findApp(in: unpacked) else {
                state = .failed("내려받은 파일에서 Pawprint.app을 찾지 못했어요")
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
            state = .failed("업데이트를 준비하지 못했어요 — \(error.localizedDescription)")
        }
    }

    struct UpdateError: Error { let message: String }

    /// `ditto` rather than `unzip`: it is the tool that round-trips macOS archives without
    /// mangling symlinks and extended attributes, and a mangled bundle fails signature checks.
    private func unzip(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError(message: "압축을 푸는 데 실패했어요")
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
        var selfCode: SecCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode else {
            throw UpdateError(message: "현재 앱의 서명을 확인할 수 없어요")
        }
        var selfStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic else {
            throw UpdateError(message: "현재 앱의 서명을 확인할 수 없어요")
        }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess,
              let requirement else {
            throw UpdateError(message: "현재 앱의 서명 요구사항을 읽을 수 없어요")
        }

        var candidate: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess,
              let candidate else {
            throw UpdateError(message: "내려받은 앱의 서명을 읽을 수 없어요")
        }
        let status = SecStaticCodeCheckValidity(candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement)
        guard status == errSecSuccess else {
            throw UpdateError(
                message: "내려받은 앱이 현재 앱과 같은 서명이 아니에요. 설치를 중단했어요 (코드 \(status))"
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
            state = .failed("설치할 업데이트가 준비되지 않았어요")
            return
        }
        let destination = Bundle.main.bundleURL
        guard destination.pathExtension == "app" else {
            state = .failed("설치 위치를 확인할 수 없어요")
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
            state = .failed("설치 준비 폴더를 찾지 못했어요")
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
            state = .failed("설치를 시작하지 못했어요 — \(error.localizedDescription)")
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
