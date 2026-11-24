//
//  PreferencesStores.swift
//  AuraSpatial
//
//  Small UserDefaults-backed stores for the Profile screen's settings and
//  lifetime stats. Like the other repositories, Controllers talk to these
//  instead of touching UserDefaults directly.
//

import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "auraspatial.settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

final class UsageStatsStore {
    private let defaults: UserDefaults
    private let key = "auraspatial.stats"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UsageStats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(UsageStats.self, from: data) else {
            return UsageStats()
        }
        return stats
    }

    func save(_ stats: UsageStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Which Community soundscapes the user has liked.
final class LikesStore {
    private let defaults: UserDefaults
    private let key = "auraspatial.community.likes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<UUID> {
        let strings = defaults.stringArray(forKey: key) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    func save(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
