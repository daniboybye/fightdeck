//
// LocalAssetServer.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation
import Network

/// Serves `dataset/assets/` over HTTP on localhost so Kingfisher performs a real network fetch.
actor LocalAssetServer {
    static let shared = LocalAssetServer()
    static let port: UInt16 = 8765

    private var listener: NWListener?
    private var assetsRoot: URL?

    func start(assetsRoot: URL) throws {
        guard listener == nil else { return }
        self.assetsRoot = assetsRoot
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!)
        listener?.newConnectionHandler = { [weak self] connection in
            Task { await self?.serve(connection: connection) }
        }
        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func serve(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self, let data, let requestLine = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            Task {
                let response = await self.makeResponse(for: requestLine)
                connection.send(content: response.headers, completion: .contentProcessed { _ in
                    connection.send(content: response.body, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                })
            }
        }
    }

    private struct HTTPResponse {
        let headers: Data
        let body: Data
    }

    private func makeResponse(for request: String) -> HTTPResponse {
        guard let assetsRoot,
              let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first else {
            return errorResponse(status: 400, message: "Bad Request")
        }

        let relative = String(pathPart).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fileURL = assetsRoot.appendingPathComponent(relative)
        guard fileURL.standardizedFileURL.path.hasPrefix(assetsRoot.standardizedFileURL.path),
              let body = try? Data(contentsOf: fileURL) else {
            return errorResponse(status: 404, message: "Not Found")
        }

        let contentType = mimeType(for: fileURL.pathExtension)
        return HTTPResponse(headers: header(status: 200,
                                            reason: "OK",
                                            contentType: contentType,
                                            length: body.count),
                            body: body)
    }

    private func errorResponse(status: Int, message: String) -> HTTPResponse {
        let body = Data(message.utf8)
        let statusText = status == 404 ? "Not Found" : "Bad Request"
        return HTTPResponse(headers: header(status: status,
                                            reason: statusText,
                                            contentType: "text/plain",
                                            length: body.count),
                            body: body)
    }

    private func header(status: Int, reason: String, contentType: String, length: Int) -> Data {
        let lines = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(length)",
            "Connection: close",
        ]
        // The header block ends in a blank line. A multi-line string literal drops the newline
        // on its own final line, which leaves a bare CR and makes CFNetwork fail with -1017.
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: "application/octet-stream"
        }
    }
}

enum DatasetLocator {
    static func datasetRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["FIGHTDECK_DATASET_ROOT"],
           !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Dataset"),
           holdsDataset(bundled) {
            return bundled
        }
        // Development fallback. Walking up beats a fixed number of parent hops, which
        // resolves to a plausible-but-wrong directory the moment this file moves.
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("dataset")
            if holdsDataset(candidate) {
                return candidate
            }
            directory = directory.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: "/tmp/fightdeck-dataset")
    }

    private static func holdsDataset(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("events.json").path)
    }

    static func eventsURL() -> URL {
        datasetRoot().appendingPathComponent("events.json")
    }
}
