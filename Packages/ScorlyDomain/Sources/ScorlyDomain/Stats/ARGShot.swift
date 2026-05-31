import Foundation

/// One around-the-green shot: a chip, pitch, or bunker recovery between
/// the approach landing and the first putt. Captured per stroke so the
/// SG calculator can reconstruct the chip phase exactly rather than
/// folding it into a residual.
///
/// `distanceToPinYards` is in **yards** (not feet — putts are feet).
/// The lie is the playable Lie the shot was taken from.
public struct ARGShot: Sendable, Equatable, Codable {
    public let lie: Lie
    public let distanceToPinYards: Int

    public init(lie: Lie, distanceToPinYards: Int) {
        self.lie = lie
        self.distanceToPinYards = distanceToPinYards
    }
}
