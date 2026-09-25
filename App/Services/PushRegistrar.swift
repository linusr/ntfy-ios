import Foundation
import Observation
import NtfyKit

/// Registers this device's APNs token and topic list with each server.
@Observable
@MainActor
final class PushRegistrar {
    enum Status: Equatable {
        case unknown
        case registered
        case unsupported
        case failed(String)
    }

    private static let tokenKey = "apnsDeviceToken"

    private(set) var token: String? = SharedContainer.defaults.string(forKey: PushRegistrar.tokenKey)
    private(set) var status: [URL: Status] = [:]

    /// Read from the NtfyPushEnvironment Info.plist key; Debug builds use the APNs sandbox.
    private var environment: PushEnvironment {
        (Bundle.main.object(forInfoDictionaryKey: "NtfyPushEnvironment") as? String).flatMap(PushEnvironment.init) ?? .production
    }

    func update(token data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        token = hex
        SharedContainer.defaults.set(hex, forKey: Self.tokenKey)
    }

    func register(topicsByServer: [URL: [String]], directory: ServerDirectory) async {
        guard let token else { return }
        for (server, topics) in topicsByServer {
            do {
                try await directory.client(for: server).registerDevice(token: token, environment: environment, topics: topics)
                status[server] = .registered
            } catch NtfyError.apnsUnavailable {
                status[server] = .unsupported
            } catch {
                status[server] = .failed(error.localizedDescription)
            }
        }
    }

    func unregister(from server: URL, directory: ServerDirectory) async {
        guard let token else { return }
        try? await directory.client(for: server).unregisterDevice(token: token)
        status[server] = nil
    }
}
