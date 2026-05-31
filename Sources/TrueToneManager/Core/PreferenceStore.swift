import Foundation

protocol PreferenceStoreDelegate: AnyObject {
    func preferencesDidChange()
}

class PreferenceStore {
    weak var delegate: PreferenceStoreDelegate?

    private let queue = DispatchQueue(label: "com.truetonemanager.preferences", attributes: .concurrent)
    private var preferences: [String: AppPreference] = [:]
    private let preferencesURL: URL

    init(preferencesURL: URL? = nil) {
        self.preferencesURL = preferencesURL ?? Self.defaultPreferencesURL()
    }

    private static func defaultPreferencesURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("TrueToneManager")
        return directory.appendingPathComponent("preferences.json")
    }

    private func ensureDirectoryExists() throws {
        let directory = preferencesURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func loadPreferences() throws {
        guard FileManager.default.fileExists(atPath: preferencesURL.path) else {
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: preferencesURL)
        } catch {
            throw PreferenceStoreError.fileReadError(message: error.localizedDescription)
        }

        let collection: PreferenceCollection
        do {
            collection = try JSONDecoder().decode(PreferenceCollection.self, from: data)
        } catch {
            try handleCorruptedFile()
            return
        }

        queue.sync(flags: .barrier) {
            for pref in collection.preferences {
                preferences[pref.bundleIdentifier] = pref
            }
        }
    }

    private func handleCorruptedFile() throws {
        let corruptedURL = preferencesURL.appendingPathExtension("corrupted-\(Date().timeIntervalSince1970)")
        try? FileManager.default.moveItem(at: preferencesURL, to: corruptedURL)
        preferences = [:]
    }

    func savePreferences() throws {
        try ensureDirectoryExists()

        let collection = PreferenceCollection(preferences: getAllPreferencesCached())
        let data: Data
        do {
            data = try JSONEncoder().encode(collection)
        } catch {
            throw PreferenceStoreError.fileWriteError(message: error.localizedDescription)
        }

        let tempURL = preferencesURL.appendingPathExtension("tmp")
        let backupURL = preferencesURL.appendingPathExtension("backup")

        try data.write(to: tempURL, options: .atomic)

        if FileManager.default.fileExists(atPath: preferencesURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: preferencesURL, to: backupURL)
        }

        do {
            try FileManager.default.moveItem(at: tempURL, to: preferencesURL)
        } catch {
            throw PreferenceStoreError.fileWriteError(message: error.localizedDescription)
        }
    }

    private func getAllPreferencesCached() -> [AppPreference] {
        return queue.sync {
            Array(preferences.values)
        }
    }

    func getPreference(for bundleIdentifier: String) -> AppPreference? {
        return queue.sync {
            preferences[bundleIdentifier]
        }
    }

    func getAllPreferences() -> [AppPreference] {
        return queue.sync {
            Array(preferences.values)
        }
    }

    func setPreference(_ preference: AppPreference) throws {
        guard !preference.bundleIdentifier.isEmpty else {
            throw PreferenceStoreError.invalidBundleIdentifier
        }

        queue.sync(flags: .barrier) {
            preferences[preference.bundleIdentifier] = preference
        }

        do {
            try savePreferences()
        } catch {
            _ = queue.sync(flags: .barrier) {
                preferences.removeValue(forKey: preference.bundleIdentifier)
            }
            throw error
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.preferencesDidChange()
        }
    }

    func removePreference(for bundleIdentifier: String) throws {
        guard !bundleIdentifier.isEmpty else {
            throw PreferenceStoreError.invalidBundleIdentifier
        }

        let removed = queue.sync(flags: .barrier) {
            preferences.removeValue(forKey: bundleIdentifier)
        }

        guard removed != nil else {
            return
        }

        do {
            try savePreferences()
        } catch {
            queue.sync(flags: .barrier) {
                preferences[bundleIdentifier] = removed
            }
            throw error
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.preferencesDidChange()
        }
    }
}

extension PreferenceCollection {
    init(preferences: [AppPreference]) {
        self.version = PreferenceCollection.currentVersion
        self.preferences = preferences
    }
}
