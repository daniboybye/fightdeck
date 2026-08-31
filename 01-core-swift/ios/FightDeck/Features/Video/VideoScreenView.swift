//
// VideoScreenView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import AVKit
import MediaPlayer
import SwiftUI
import UIKit

struct VideoScreenView: View {
    let item: MediaItem
    let posterURL: URL?

    var body: some View {
        List {
            Section {
                VideoPlayerContainer(item: item, posterURL: posterURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                Text(item.title)
                    .font(.title3.bold())
                LabeledContent("Duration", value: item.durationSeconds.formattedDuration)
                LabeledContent("Format", value: item.kind.uppercased())
            }
            if let note = item.note {
                Section("About this clip") {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VideoPlayerContainer: UIViewControllerRepresentable {
    let item: MediaItem
    let posterURL: URL?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        Self.activateAudioSession()
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.showsPlaybackControls = true

        if let url = URL(string: item.url) {
            let player = AVPlayer(url: url)
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
            controller.player = player
            context.coordinator.bind(controller: controller, player: player)
            updateNowPlaying(item: item)
            player.play()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.teardown(stopPlayback: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Main-actor isolated so the notification closures below, which are `@Sendable`, may capture
    /// it and touch the player. Everything here already runs on the main thread.
    @MainActor
    final class Coordinator {
        private weak var controller: AVPlayerViewController?
        private var player: AVPlayer?
        private var observers: [any NSObjectProtocol] = []
        private var shouldResumeAfterForeground = false

        func bind(controller: AVPlayerViewController, player: AVPlayer) {
            self.controller = controller
            self.player = player
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // `queue: .main` already guarantees main-thread delivery; the compiler cannot
                // see that through NotificationCenter's `@Sendable` closure.
                MainActor.assumeIsolated { self?.detachForBackground() }
            })
            observers.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reattachAfterForeground() }
            })
        }

        private func detachForBackground() {
            guard let player else { return }
            shouldResumeAfterForeground = player.rate > 0
            controller?.player = nil
            guard shouldResumeAfterForeground else { return }
            VideoPlayerContainer.activateAudioSession()
            player.play()
        }

        private func reattachAfterForeground() {
            guard let player, let controller, controller.player == nil else { return }
            VideoPlayerContainer.activateAudioSession()
            controller.player = player
            if shouldResumeAfterForeground {
                player.play()
                shouldResumeAfterForeground = false
            }
        }

        func teardown(stopPlayback: Bool) {
            if stopPlayback {
                player?.pause()
            }
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
            controller?.player = nil
            player = nil
            controller = nil
        }
    }

    private static func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
        try? session.setActive(true)
    }

    // nonisolated on purpose. UIViewControllerRepresentable is @MainActor, so a closure
    // created here would inherit that isolation — and MediaPlayer invokes the artwork
    // handler on its own queue, which trips the Swift 6 executor check and traps.
    private nonisolated func updateNowPlaying(item: MediaItem) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyPlaybackDuration: item.durationSeconds,
            MPNowPlayingInfoPropertyIsLiveStream: item.kind == "hls",
        ]
        if let image = UIImage(systemName: "sportscourt.fill") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
