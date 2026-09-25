//
// AssetServer.swift
// FightDeckEvents
//
// Created by FightDeck on 25.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
#if !SKIP
import Network
#endif

/// Serves the dataset over HTTP on 127.0.0.1, so the image loaders on both platforms make a real
/// network fetch rather than reading a file. Each host used to carry its own server —
/// Network.framework on iOS, a `ServerSocket` on Android — doing the same four things: bind,
/// read a request line, refuse paths outside the dataset, answer with the file. Only the socket
/// differs now; what a request is answered with is written once.
///
/// The hosts keep `DatasetLocator`, since only they know where the dataset lives.
public final class AssetServer: @unchecked Sendable {
    public static let shared = AssetServer()

    /// Held for the whole of `start`, so a Retry that overlaps a start in progress waits for it
    /// and gets its port, rather than binding a second server the app never hands out.
    private let lock = NSLock()
    /// Zero while nothing is listening.
    private var port = 0
    #if !SKIP
    /// Network.framework stops listening once the listener is released.
    private var listener: NWListener?
    #endif

    private init() {}

    /// Starts serving `datasetRoot` on a port the kernel picks and returns it. The demo apps share
    /// one simulator, and a fixed port goes to whichever of them launches first. A second call
    /// while the server runs returns the same port.
    public func start(datasetRoot: String) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        if port != 0 {
            return port
        }
        let root = URL(fileURLWithPath: datasetRoot)
        port = try listen { requestLine in
            AssetServer.response(to: requestLine, root: root)
        }
        return port
    }

    /// Nil until the server is up, so an image shows its placeholder rather than a URL that
    /// nothing answers.
    public func url(for path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return port == 0 ? nil : "http://127.0.0.1:\(port)/\(path)"
    }

    /// Image URLs are built from the port, so a listener that died must stop advertising it.
    private func stopped() {
        lock.lock()
        defer { lock.unlock() }
        port = 0
    }

    // MARK: - The answer, shared

    private static func response(to requestLine: String, root: URL) -> Data {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return reply("400 Bad Request", contentType: "text/plain", body: Data("Bad Request".utf8))
        }
        var path = String(parts[1])
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        // `..` is the only way out of the dataset: the path is never percent-decoded, so an
        // encoded one names a file that does not exist.
        let climbsOut = path.split(separator: "/").contains { $0 == ".." }
        guard !climbsOut, let body = try? Data(contentsOf: root.appendingPathComponent(path)) else {
            return reply("404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
        }
        return reply("200 OK", contentType: contentType(of: path), body: body)
    }

    private static func reply(_ status: String, contentType: String, body: Data) -> Data {
        // The header block ends in a blank line; without the second CRLF CFNetwork fails the
        // request with -1017.
        let header = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        return response
    }

    private static func contentType(of path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Skip (Android)

#if SKIP
extension AssetServer {
    /// A blocking `ServerSocket` on a thread of its own, and one more thread per request.
    ///
    /// The address is spelled out: Android's `InetAddress.getLoopbackAddress()` is `::1`, which
    /// left the server listening where no image URL points.
    fileprivate func listen(_ respond: @escaping (String) -> Data) throws -> Int {
        let server = java.net.ServerSocket(0, 16, java.net.InetAddress.getByName("127.0.0.1"))
        java.lang.Thread {
            do {
                while true {
                    let socket = server.accept()
                    java.lang.Thread { AssetServer.answer(socket, respond) }.start()
                }
            } catch {
                self.stopped()
            }
        }.start()
        return server.localPort
    }

    /// An exception left to escape a thread would take the whole app down, so a request that
    /// fails midway only loses its own image.
    private static func answer(_ socket: java.net.Socket, _ respond: (String) -> Data) {
        do {
            let reader = socket.getInputStream().bufferedReader()
            let requestLine = reader.readLine() ?? ""
            // Read the headers as well, though nothing uses them: closing a socket with unread
            // bytes makes the kernel answer with a reset, which can reach the client before the
            // image does.
            var header = reader.readLine()
            while header != nil && header != "" {
                header = reader.readLine()
            }
            socket.getOutputStream().write(respond(requestLine).kotlin())
            socket.getOutputStream().flush()
        } catch {
        }
        socket.close()
    }
}
#endif

// MARK: - Native (iOS)

#if !SKIP
extension AssetServer {
    enum ListenError: Error {
        case notReady
    }

    /// Network.framework reports the bind through a callback; `start` is synchronous on both
    /// platforms, so this waits for it.
    fileprivate func listen(_ respond: @escaping @Sendable (String) -> Data) throws -> Int {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        let settled = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed, .cancelled: settled.signal()
            default: break
            }
        }
        listener.newConnectionHandler = { connection in
            AssetServer.answer(connection, respond)
        }
        listener.start(queue: .global(qos: .userInitiated))
        guard settled.wait(timeout: .now() + 5) == .success,
              case .ready = listener.state,
              let port = listener.port?.rawValue else {
            listener.cancel()
            throw ListenError.notReady
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.stopped()
            default: break
            }
        }
        self.listener = listener
        return Int(port)
    }

    /// One read takes the whole request, headers included: the image loaders send a few hundred
    /// bytes, and leaving any unread makes the close a reset.
    private static func answer(_ connection: NWConnection, _ respond: @escaping @Sendable (String) -> Data) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let requestLine = String(request.prefix { $0 != "\r" && $0 != "\n" })
            connection.send(content: respond(requestLine), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
#endif
