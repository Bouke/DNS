import Foundation

/// A one bit field that specifies whether this message is a
/// query (0), or a response (1).
///
/// - query: query to a name server
/// - response: response from a name server
public enum MessageType {
    case query
    case response
}

/// All communications inside of the domain protocol are carried in a single
/// format called a message.  The top level format of message is divided
/// into 5 sections (some of which are empty in certain cases) shown below:
///
///     +---------------------+
///     |        Header       |
///     +---------------------+
///     |       Question      | the question for the name server
///     +---------------------+
///     |        Answer       | RRs answering the question
///     +---------------------+
///     |      Authority      | RRs pointing toward an authority
///     +---------------------+
///     |      Additional     | RRs holding additional information
///     +---------------------+
///
/// The header section is always present.  The header includes fields that
/// specify which of the remaining sections are present, and also specify
/// whether the message is a query or a response, a standard query or some
/// other opcode, etc.
///
/// The names of the sections after the header are derived from their use in
/// standard queries.  The question section contains fields that describe a
/// question to a name server.  These fields are a query type (QTYPE), a
/// query class (QCLASS), and a query domain name (QNAME).  The last three
/// sections have the same format: a possibly empty list of concatenated
/// resource records (RRs).  The answer section contains RRs that answer the
/// question; the authority section contains RRs that point toward an
/// authoritative name server; the additional records section contains RRs
/// which relate to the query, but are not strictly answers for the
/// question.
public struct Message {

    // MARK: Message header section

    /// A 16 bit identifier assigned by the program that
    /// generates any kind of query.  This identifier is copied
    /// the corresponding reply and can be used by the requester
    /// to match up replies to outstanding queries.
    public var id: UInt16

    /// A one bit field that specifies whether this message is a
    /// query (0), or a response (1).
    public var type: MessageType

    /// A four bit field that specifies kind of query in this
    /// message.  This value is set by the originator of a query
    /// and copied into the response.  The values are:
    public var operationCode: OperationCode

    /// Authoritative Answer - this bit is valid in responses,
    /// and specifies that the responding name server is an
    /// authority for the domain name in question section.
    ///
    /// Note that the contents of the answer section may have
    /// multiple owner names because of aliases.  The AA bit
    /// corresponds to the name which matches the query name, or
    /// the first owner name in the answer section.
    public var authoritativeAnswer: Bool

    /// TrunCation - specifies that this message was truncated
    /// due to length greater than that permitted on the
    /// transmission channel.
    public var truncation: Bool

    /// Recursion Desired - this bit may be set in a query and
    /// is copied into the response.  If RD is set, it directs
    /// the name server to pursue the query recursively.
    /// Recursive query support is optional.
    public var recursionDesired: Bool

    /// Recursion Available - this be is set or cleared in a
    /// response, and denotes whether recursive query support is
    /// available in the name server.
    public var recursionAvailable: Bool

    /// Response code - this 4 bit field is set as part of
    /// responses.
    public var returnCode: ReturnCode

    // MARK: Other sections

    /// Question section.
    public var questions: [Question]

    /// Answer section.
    public var answers: [ResourceRecord]

    /// Authority section.
    public var authorities: [ResourceRecord]

    /// Additional records section.
    public var additional: [ResourceRecord]

    // MARK: Initializing

    /// Create a `Message` instance.
    ///
    /// To create a query:
    ///
    /// ```swift
    /// let query = Message(
    ///     id: UInt16(extendingOrTruncating: arc4random()),
    ///     type: .query,
    ///     questions: [
    ///         Question(name: "apple.com", type: .host)
    ///     ])
    /// ```
    ///
    /// To create a response for this query:
    ///
    /// ```swift
    /// let response = Message(
    ///     id: query.id,
    ///     type: .response,
    ///     returnCode: .noError,
    ///     questions: query.questions,
    ///     answers: [
    ///         HostRecord<IPv4>(name: "apple.com", ttl: 3600, ip: IPv4("17.172.224.47")!)
    ///     ])
    /// ```
    ///
    /// - Parameters:
    ///   - id:
    ///   - type:
    ///   - operationCode:
    ///   - authoritativeAnswer:
    ///   - truncation:
    ///   - recursionDesired:
    ///   - recursionAvailable:
    ///   - returnCode:
    ///   - questions:
    ///   - answers:
    ///   - authorities:
    ///   - additional:
    public init(
        id: UInt16 = 0,
        type: MessageType,
        operationCode: OperationCode = .query,
        authoritativeAnswer: Bool = true,
        truncation: Bool = false,
        recursionDesired: Bool = false,
        recursionAvailable: Bool = false,
        returnCode: ReturnCode = .noError,
        questions: [Question] = [],
        answers: [ResourceRecord] = [],
        authorities: [ResourceRecord] = [],
        additional: [ResourceRecord] = []
        ) {
        self.id = id
        self.type = type
        self.operationCode = operationCode
        self.authoritativeAnswer = authoritativeAnswer
        self.truncation = truncation
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.returnCode = returnCode

        self.questions = questions
        self.answers = answers
        self.authorities = authorities
        self.additional = additional
    }
}

extension Message: CustomDebugStringConvertible {
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch type {
        case .query: return "DNS Request(id: \(id), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable), questions: \(questions), answers: \(answers), authorities: \(authorities), additional: \(additional))"
        case .response: return "DNS Response(id: \(id), returnCode: \(returnCode), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable), questions: \(questions), answers: \(answers), authorities: \(authorities), additional: \(additional))"
        }
    }
}

/// A four bit field that specifies kind of query in this
/// message.  This value is set by the originator of a query
/// and copied into the response.
///
/// - query: a standard query (QUERY)
/// - inverseQuery: an inverse query (IQUERY)
/// - statusRequest: a server status request (STATUS)
/// - notify: (NOTIFY)
/// - update: (UPDATE)
public typealias OperationCode = UInt8

public extension OperationCode { // 4 bits: 0-15
    public static let query: OperationCode = 0 // QUERY
    public static let inverseQuery: OperationCode = 1 // IQUERY
    public static let statusRequest: OperationCode = 2 // STATUS
    public static let notify: OperationCode = 4 // NOTIFY
    public static let update: OperationCode = 5 // UPDATE
}

/// Response code - this 4 bit field is set as part of responses.
///
public typealias ReturnCode = UInt8

public extension ReturnCode { // 4 bits: 0-15
    // MARK: Basic DNS (RFC1035)

    /// No error condition.
    public static let noError: ReturnCode = 0 // NOERROR

    /// Format error - he name server was unable to interpret the query.
    public static let formatError: ReturnCode = 1 // FORMERR

    /// Server failure - The name server was unable to process this query due
    /// to a problem with the name server.
    public static let serverFailure: ReturnCode = 2 // SERVFAIL

    /// Name Error - Meaningful only for responses from an authoritative name
    /// server, this code signifies that the domain name referenced in the
    /// query does not exist.
    public static let nonExistentDomain: ReturnCode = 3 // NXDOMAIN

    /// Not Implemented - The name server does not support the requested kind
    /// of query.
    public static let notImplemented: ReturnCode = 4 // NOTIMPL

    /// Refused - The name server refuses to perform the specified operation
    /// for policy reasons.  For example, a name server may not wish to provide
    /// the information to the particular requester, or a name server may not
    /// wish to perform a particular operation (e.g., zone transfer) for
    /// particular data.
    public static let queryRefused: ReturnCode = 5 // REFUSED

    // MARK: DNS UPDATE (RFC2136)

    /// Some name that ought not to exist, does exist.
    public static let nameExistsWhenItShouldNot: ReturnCode = 6 // YXDOMAIN

    /// Some RRset that ought not to exist, does exist.
    public static let rrSetExistsWhenItShouldNot: ReturnCode = 7 // YXRRSET

    /// Some RRset that ought to exist, does not exist.
    public static let rrSetThatShouldExistDoestNot: ReturnCode = 8 // NXRRSET

    /// The server is not authoritative for the zone named in the Zone Section.
    public static let serverNotAuthoritativeForZone: ReturnCode = 9 // NOTAUTH

    /// A name used in the Prerequisite or Update Section is not within the
    /// zone denoted by the Zone Section.
    public static let nameNotContainedInZone: ReturnCode = 10 // NOTZONE
}
