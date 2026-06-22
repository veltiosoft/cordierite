import Foundation
import SwiftUI

@MainActor
@Observable
final class ConfigStore {
    var configuration: AppConfiguration

    static var configDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Cordierite", isDirectory: true)
    }

    static var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("config.json")
    }

    init() {
        configuration = Self.load() ?? AppConfiguration()
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { self.configuration[keyPath: keyPath] },
            set: { newValue in
                self.configuration[keyPath: keyPath] = newValue
                self.save()
            }
        )
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: Self.configDirectoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: Self.configFileURL, options: .atomic)
        } catch {
            NSLog("Failed to save configuration: \(error.localizedDescription)")
        }
    }

    func update(_ transform: (inout AppConfiguration) -> Void) {
        transform(&configuration)
        save()
    }

    private static func load() -> AppConfiguration? {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            return try JSONDecoder().decode(AppConfiguration.self, from: data)
        } catch {
            NSLog("Failed to load configuration: \(error.localizedDescription)")
            return nil
        }
    }
}
