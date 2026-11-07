import XCTest
@testable import AutoRip2MKV_Mac

final class MakeMKVInstallerTests: XCTestCase {
    func testFindsMacDownloadOnPage() {
        let html = """
        <li><a href='/download/Setup_MakeMKV_v2.0.0.exe'>MakeMKV 2.0.0 for Windows</a></li>
        <li><a href='/download/makemkv_v2.0.0_osx.dmg'>MakeMKV 2.0.0 for Mac OS X</a></li>
        """
        let found = MakeMKVInstaller.macDownload(fromPageHTML: html)
        XCTAssertEqual(found?.url.absoluteString, "https://www.makemkv.com/download/makemkv_v2.0.0_osx.dmg")
        XCTAssertEqual(found?.version, "2.0.0")
    }

    func testNoLinkWhenMissing() {
        XCTAssertNil(MakeMKVInstaller.macDownload(fromPageHTML: "<a href='/download/old.zip'>x</a>"))
    }

    func testIgnoresOffSiteLinks() {
        // Only the site-relative /download/ path is accepted, always rebuilt on makemkv.com.
        let found = MakeMKVInstaller.macDownload(
            fromPageHTML: "<a href='https://evil.example/download/makemkv_v9.9_osx.dmg'>")
        XCTAssertEqual(found?.url.host, "www.makemkv.com")
    }
}
