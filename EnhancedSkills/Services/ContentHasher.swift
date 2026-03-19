import Foundation
import CryptoKit

struct ContentHasher {
    static func sha256(of fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(ofString string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
