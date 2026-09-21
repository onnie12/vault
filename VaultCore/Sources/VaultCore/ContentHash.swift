import Crypto
import Foundation

/// SHA-256 fingerprints for file contents. Two files with the same bytes get the
/// same hash, which is how Vault spots duplicates (spec: "Already in Vault").
public enum ContentHash {

    /// Lowercase hex SHA-256 of `data`, 64 characters.
    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
