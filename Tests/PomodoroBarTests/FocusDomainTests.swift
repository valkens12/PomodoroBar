import Foundation
import Testing

@testable import PomodoroBar

// MARK: - DomainMatch

@Suite("Domain matching")
struct DomainMatchTests {
  @Test("exact host matches its own pattern")
  func exactMatch() {
    #expect(DomainMatch.hostMatches("coursera.org", pattern: "coursera.org"))
  }

  @Test("subdomain matches the parent domain pattern")
  func subdomainMatch() {
    #expect(DomainMatch.hostMatches("learn.coursera.org", pattern: "coursera.org"))
  }

  @Test("suffix without a dot boundary does not match")
  func noBoundaryBleed() {
    #expect(!DomainMatch.hostMatches("evilcoursera.org", pattern: "coursera.org"))
  }

  @Test("unrelated host does not match")
  func unrelatedHost() {
    #expect(!DomainMatch.hostMatches("youtube.com", pattern: "coursera.org"))
  }

  @Test("parent domain does not match a subdomain pattern")
  func parentDoesNotMatchSubdomainPattern() {
    #expect(!DomainMatch.hostMatches("coursera.org", pattern: "learn.coursera.org"))
  }
}

// MARK: - Domain normalization

@Suite("Domain normalization")
@MainActor
struct NormalizeDomainTests {
  @Test("bare domain passes through")
  func bareDomain() {
    #expect(FocusGuard.normalizeDomain("coursera.org") == "coursera.org")
  }

  @Test("full pasted URL reduces to its host")
  func fullURL() {
    #expect(
      FocusGuard.normalizeDomain("https://www.Coursera.org/learn/swift?x=1") == "coursera.org"
    )
  }

  @Test("domain with trailing path loses the path")
  func domainWithPath() {
    #expect(FocusGuard.normalizeDomain("coursera.org/learn") == "coursera.org")
  }

  @Test("leading www. is stripped")
  func wwwStripped() {
    #expect(FocusGuard.normalizeDomain("www.coursera.org") == "coursera.org")
  }

  @Test("mixed case and surrounding whitespace normalize away")
  func caseAndWhitespace() {
    #expect(FocusGuard.normalizeDomain("  Coursera.ORG \n") == "coursera.org")
  }

  @Test("blank input yields nil", arguments: ["", "   ", "\n"])
  func blankInput(raw: String) {
    #expect(FocusGuard.normalizeDomain(raw) == nil)
  }
}

// MARK: - FocusApp decoding

@Suite("FocusApp persistence compatibility")
struct FocusAppDecodingTests {
  @Test("entries persisted before focusDomains existed still decode")
  func legacyEntryDecodes() throws {
    let legacyJSON = """
      [
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "bundleId": "com.apple.Safari",
          "name": "Safari",
          "urlPath": "/Applications/Safari.app"
        }
      ]
      """
    let apps = try JSONDecoder().decode([FocusApp].self, from: Data(legacyJSON.utf8))
    #expect(apps.count == 1)
    #expect(apps[0].bundleId == "com.apple.Safari")
    #expect(apps[0].focusDomains.isEmpty)
  }

  @Test("focusDomains round-trips through encode and decode")
  func roundTrip() throws {
    let app = FocusApp(
      id: UUID(),
      bundleId: "com.apple.Safari",
      name: "Safari",
      urlPath: "/Applications/Safari.app",
      focusDomains: ["coursera.org", "developer.apple.com"],
    )
    let data = try JSONEncoder().encode([app])
    let decoded = try JSONDecoder().decode([FocusApp].self, from: data)
    #expect(decoded == [app])
  }
}
