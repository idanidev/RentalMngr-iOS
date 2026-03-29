import Foundation
import Realtime
import Supabase
import os

private let logger = Logger(subsystem: "com.rentalmngr", category: "RealtimeService")

final class RealtimeService: RealtimeServiceProtocol {
    private let client: SupabaseClient

    enum ChangeEvent: Sendable {
        case insert
        case update
        case delete
        case all
    }

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func listenForChanges(table: String) -> AsyncStream<ChangeEvent> {
        AsyncStream { continuation in
            // Unique topic per subscription prevents the Supabase SDK from
            // reusing an already-joined channel when multiple ViewModels
            // subscribe to the same table simultaneously.
            let topic = "public:\(table):\(UUID().uuidString)"

            // Capture client to avoid capturing self in @Sendable closure
            let client = self.client

            // Create the channel synchronously so it can be captured by both
            // the subscription task AND the onTermination cleanup closure.
            let channel = client.channel(topic)

            // postgresChange MUST be registered before subscribing the channel
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: table
            )

            let task = Task {
                do {
                    try await channel.subscribeWithError()

                    for await _ in changes {
                        continuation.yield(.all)
                    }
                } catch {
                    logger.error("Failed to subscribe to \(topic): \(error)")
                }
            }

            // Capture the exact channel instance — not a new client.channel(topic) call
            // which would create a different object and leave the original leaked.
            continuation.onTermination = { @Sendable [channel] _ in
                task.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }

}
