import Foundation
import Socket

public class Server: ResolverDelegate {
    private let socket: Socket
    private var queries = [UInt16: Socket.Address]()
    private let resolver: UDPResolver
    private let syncQueue = DispatchQueue(label: "server")
    private let port: Int

    public init(port: Int, resolver: UDPResolver) throws {
        self.port = port
        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        self.resolver = resolver
        self.resolver.delegate = self
        startReceivingQueries()
    }

    private func startReceivingQueries() {
        DispatchQueue.global().async {
            while true {
                self.receiveQuery()
            }
        }
    }

    private func receiveQuery() {
        do {
            var message = Data()
            let (size, sender) = try socket.listen(forMessage: &message, on: port, maxBacklogSize: 0)
            guard size > 0 else {
                print("Empty query")
                return
            }
            guard let senderUnwrapped = sender else {
                print("No sender info")
                return
            }
            try parse(packet: message, from: senderUnwrapped)
        } catch {
            print("Error receiving query: \(error)")
        }
    }

    private func parse(packet: Data, from: Socket.Address) throws {
        let query = try Message(deserialize: packet)
        guard query.type == .query else {
            print("Not a query")
            return
        }
        print("Request: \(query.questions.first?.name ?? "N/A")")
        syncQueue.sync {
            guard queries[query.id] == nil else {
                print("Duplicate query id, ignoring.")
                return
            }
            self.queries[query.id] = from
            DispatchQueue.main.async {
                do {
                    try self.resolver.resolve(query: query)
                } catch {
                    print("Error sending query: \(error)")
                }
            }
        }
    }

    public func resolver(_: UDPResolver, didResolveQuery query: Message, withAnswer response: Message) {
        syncQueue.async {
            guard let sender = self.queries[query.id] else {
                print("Response to unknown query received")
                return
            }
            print("Response: \(response.answers.first?.name ?? "N/A")")
            self.queries[query.id] = nil
            do {
                let bytes = try response.serialize()
                try self.socket.write(from: bytes, to: sender)
            } catch {
                print("Could not send reply: \(error)")
            }
        }
    }
}
