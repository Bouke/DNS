import DNS
import Foundation
import Utility

// The first argument is always the executable, drop it
let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())

let parser = ArgumentParser(usage: "<options>", overview: "Forwarding DNS server")
let localPort = parser.add(positional: "local_port", kind: Int.self, usage: "Local port to listen on (UDP)")
let resolverHost = parser.add(positional: "resolver_host", kind: String.self, usage: "Resolver IP address")
let resolverPort = parser.add(positional: "resolver_port", kind: Int.self, usage: "Resolver port (UDP)")

do {
    let parsedArguments = try parser.parse(arguments)
    let resolver = try UDPResolver(hostname: parsedArguments.get(resolverHost)!, port: parsedArguments.get(resolverPort)!)
    let server = try Server(port: parsedArguments.get(localPort)!, resolver: resolver)
    withExtendedLifetime(server) {
        dispatchMain()
    }
} catch let error as ArgumentParserError {
    print(error.description)
} catch let error {
    print(error.localizedDescription)
}
