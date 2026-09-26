//
// AssetServer.swift
// FightEvents
//
// Created by FightDeck on 26.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

// Serves the dataset over HTTP on 127.0.0.1, so the image loaders on both platforms make a real
// network fetch rather than reading a file. Each host used to carry its own server —
// Network.framework on iOS, a `ServerSocket` on Android — doing the same four things: bind,
// read a request, refuse paths outside the dataset, answer with the file. This is the one both
// run, on POSIX sockets and threads, which Darwin and Bionic both have. Foundation's networking
// would drag ICU into the Android build, and Dispatch its 185 KB Swift overlay.
#if os(Android)
import Android
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public enum AssetServer {
    public struct StartError: Error {
        public let errno: Int32
    }

    /// Zero while nothing is listening.
    private static let port = Mutex(0)

    /// Starts serving `datasetRoot` on a port the kernel picks and returns the address an image
    /// path is appended to. The demo apps share one simulator, and a fixed port goes to whichever
    /// launches first. A second call while the server runs returns the same address, so a Retry
    /// cannot start another server and leave the app pointing at the wrong one.
    @discardableResult
    public static func start(datasetRoot: String) throws -> String {
        try port.withLock { port in
            if port == 0 {
                guard let root = canonical(datasetRoot) else { throw StartError(errno: ENOENT) }
                let (listener, bound) = try listenOnLoopback()
                port = bound
                detach { acceptLoop(listener, root: root) }
            }
            return baseURL(port)
        }
    }

    /// Nil until the server is up, so an image shows its placeholder rather than a URL that
    /// nothing answers.
    public static func url(for path: String) -> String? {
        let port = port.withLock { $0 }
        return port == 0 ? nil : baseURL(port) + path
    }

    private static func baseURL(_ port: Int) -> String {
        "http://127.0.0.1:\(port)/"
    }

    private static func listenOnLoopback() throws -> (socket: Int32, port: Int) {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        guard listener >= 0 else { throw StartError(errno: errno) }
        var address = sockaddr_in()
        #if !os(Android)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = in_addr_t(0x7F00_0001).bigEndian
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let listening = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(listener, socketAddress, length) == 0
                    && listen(listener, 16) == 0
                    && getsockname(listener, socketAddress, &length) == 0
            }
        }
        guard listening else {
            let code = errno
            close(listener)
            throw StartError(errno: code)
        }
        return (listener, Int(UInt16(bigEndian: address.sin_port)))
    }

    private static func acceptLoop(_ listener: Int32, root: String) {
        while true {
            let client = accept(listener, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            detach { serve(client, root: root) }
        }
        close(listener)
        // Image URLs are built from the port, so a listener that died must stop advertising it.
        port.withLock { $0 = 0 }
    }

    private final class Work: Sendable {
        let run: @Sendable () -> Void
        init(_ run: @escaping @Sendable () -> Void) { self.run = run }
    }

    /// A detached thread of its own, as the old Android server had.
    private static func detach(_ run: @escaping @Sendable () -> Void) {
        let work = Unmanaged.passRetained(Work(run)).toOpaque()
        if !spawn(work) {
            Unmanaged<Work>.fromOpaque(work).release()
        }
    }

    private static func spawn(_ work: UnsafeMutableRawPointer) -> Bool {
        var attributes = pthread_attr_t()
        pthread_attr_init(&attributes)
        defer { pthread_attr_destroy(&attributes) }
        pthread_attr_setdetachstate(&attributes, Int32(PTHREAD_CREATE_DETACHED))
        // `pthread_t` is an optional pointer on Darwin and an integer on Bionic.
        #if os(Android)
        var thread = pthread_t()
        #else
        var thread: pthread_t?
        #endif
        // The start routine hands back its argument: Bionic declares the result non-null, Darwin
        // optional, and a non-null pointer satisfies both.
        return pthread_create(&thread, &attributes, { context in
            Unmanaged<Work>.fromOpaque(context).takeRetainedValue().run()
            return context
        }, work) == 0
    }

    private static func serve(_ client: Int32, root: String) {
        defer { close(client) }
        // A client that connects and never writes would otherwise hold this thread for good.
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard let requestLine = readRequest(client) else { return }
        let target = requestLine.split(separator: " ").dropFirst().first.map(String.init)
        let answer: [UInt8]
        if let target {
            if let (file, body) = fileUnder(root, target) {
                answer = response("200 OK", contentType(file), body)
            } else {
                answer = response("404 Not Found", "text/plain", Array("Not Found".utf8))
            }
        } else {
            answer = response("400 Bad Request", "text/plain", Array("Bad Request".utf8))
        }
        sendAll(client, answer)
    }

    /// Reads the headers as well, though nothing uses them: closing a socket with unread bytes
    /// makes the kernel answer with a reset, and the reset can reach the client before the image.
    private static func readRequest(_ client: Int32) -> String? {
        var received: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while received.count < 65_536, !received.suffix(4).elementsEqual("\r\n\r\n".utf8) {
            let count = recv(client, &buffer, buffer.count, 0)
            guard count > 0 else { break }
            received += buffer[..<count]
        }
        let firstLine = received.prefix { $0 != UInt8(ascii: "\r") && $0 != UInt8(ascii: "\n") }
        return firstLine.isEmpty ? nil : String(decoding: firstLine, as: UTF8.self)
    }

    /// Resolved before the prefix check, so `../` cannot climb out of the dataset.
    private static func fileUnder(_ root: String, _ target: String) -> (String, [UInt8])? {
        guard let file = canonical(root + "/" + target.drop { $0 == "/" }),
              file.hasPrefix(root + "/"),
              let body = FileManager.default.contents(atPath: file) else {
            return nil
        }
        return (file, Array(body))
    }

    private static func canonical(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    private static func response(_ status: String, _ contentType: String, _ body: [UInt8]) -> [UInt8] {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\n"
            + "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Array(head.utf8) + body
    }

    private static func sendAll(_ client: Int32, _ bytes: [UInt8]) {
        // A client that hangs up mid-image must not take the process down with SIGPIPE.
        #if os(Android)
        let flags = Int32(MSG_NOSIGNAL)
        #else
        var one: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        let flags: Int32 = 0
        #endif
        var sent = 0
        while sent < bytes.count {
            // Bionic declares the buffer non-optional where Darwin does not; the slice is never
            // empty inside this loop.
            let count = bytes[sent...].withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress else { return 0 }
                return send(client, base, buffer.count, flags)
            }
            guard count > 0 else { return }
            sent += count
        }
    }

    private static func contentType(_ file: String) -> String {
        switch file.split(separator: ".").last?.lowercased() {
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: "application/octet-stream"
        }
    }
}
