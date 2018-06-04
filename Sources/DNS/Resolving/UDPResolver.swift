import Foundation
import Socket

public protocol ResolverDelegate: class {
    func resolver(_: UDPResolver, didResolveQuery: Message, withAnswer: Message)
}

public protocol Resolver {
    var delegate: ResolverDelegate? { get set }
    func resolve(query: Message) throws
}

public class UDPResolver: Resolver {
    private let socket: Socket
    public weak var delegate: ResolverDelegate?
    private var queries = [UInt16: Message]()
    let syncQueue = DispatchQueue(label: "resolver")

    public init(hostname: String, port: Int) throws {
        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.connect(to: hostname, port: Int32(port))
        startReceivingResponses()
    }

    private func startReceivingResponses() {
        DispatchQueue.global().async {
            while true {
                self.receive()
            }
        }
    }

    private func receive() {
        do {
            var packet = Data()
            _ = try socket.readDatagram(into: &packet)
            try parse(packet: packet)
        } catch {
            print("Error : \(error)")
        }
    }

    private func parse(packet: Data) throws {
        let answer = try Message(deserialize: packet)
        guard answer.type == .response else {
            print("Message is no response")
            return
        }
        syncQueue.sync {
            guard let query = queries[answer.id] else {
                print("Response to unknown query")
                return
            }
            queries[answer.id] = nil
            DispatchQueue.main.async {
                self.delegate?.resolver(self, didResolveQuery: query, withAnswer: answer)
            }
        }
    }

    public func resolve(query: Message) throws {
        try syncQueue.sync {
            queries[query.id] = query
            try send(query: query)
        }
    }

    private func send(query: Message) throws {
        let bytes = try query.serialize()
        try socket.write(from: bytes)
    }
}
