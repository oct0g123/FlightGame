import Foundation

/// The levels and difficulty profiles bundled with the game.
///
/// They live in this package (not FlightContent) so that tests on every
/// platform, Linux included, decode and validate the real files.
public enum BuiltInContent {
    /// Every bundled level, in menu order.
    public static let levelIDs = ["coastal-field", "test-range"]

    public static func level(_ id: String) throws -> Level {
        try decode(Level.self, named: id, in: "Levels")
    }

    public static func profile(_ id: String) throws -> DifficultyProfile {
        try decode(DifficultyProfile.self, named: id, in: "Difficulty")
    }

    public static func levels() throws -> [Level] {
        try levelIDs.map(level)
    }

    private static func decode<T: Decodable>(_ type: T.Type, named name: String, in folder: String)
        throws -> T
    {
        guard
            let url = Bundle.module.url(
                forResource: name, withExtension: "json", subdirectory: folder)
        else { throw ContentError.missing("\(folder)/\(name).json") }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

public enum ContentError: Error, Equatable {
    case missing(String)
}
