//
// VideoScreenView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import AVKit
import MediaPlayer
import FightDeckEvents
import SwiftUI
import UIKit

struct VideoScreenView: View {
    let item: MediaItem

    var body: some View {
        List {
            Section {
                VideoPlayerContainer(item: item)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                Text(item.title)
                    .font(.title3.bold())
                LabeledContent("Duration", value: Display.duration(totalSeconds: item.durationSeconds))
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

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        Self.activateAudioSession()
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        // Leaving the app hands the clip to the floating window rather than stopping it.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.showsPlaybackControls = true
        controller.delegate = context.coordinator

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
        coordinator.leaveScreen()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// AVKit calls the delegate on the main thread but its protocol predates the annotation,
    /// so the conformance has to say so.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency AVPlayerViewControllerDelegate {
        private var controller: AVPlayerViewController?
        private var player: AVPlayer?
        private var isInPictureInPicture = false
        private var hasLeftScreen = false

        func bind(controller: AVPlayerViewController, player: AVPlayer) {
            self.controller = controller
            self.player = player
        }

        /// The screen is going away — unless the clip has moved into the floating window, where
        /// outliving this screen is the whole point.
        func leaveScreen() {
            hasLeftScreen = true
            guard !isInPictureInPicture else { return }
            stop()
        }

        private func stop() {
            player?.pause()
            controller?.player = nil
            player = nil
            controller = nil
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPictureInPicture = true
            // SwiftUI drops this controller as soon as the screen behind the window goes away,
            // and a deallocated controller takes the window with it.
            PictureInPictureHost.shared.hold(playerViewController)
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPictureInPicture = false
            PictureInPictureHost.shared.release()
            // Closing the window after leaving the screen leaves nothing showing the clip, so
            // stop it rather than let it play on to no one.
            if hasLeftScreen {
                stop()
            }
        }

        /// Tapping the window's restore button brings the clip back to this screen.
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }
    }

    /// Keeps the controller alive for exactly as long as its floating window is on screen.
    @MainActor
    final class PictureInPictureHost {
        static let shared = PictureInPictureHost()
        private var controller: AVPlayerViewController?

        private init() {}

        func hold(_ controller: AVPlayerViewController) { self.controller = controller }
        func release() { controller = nil }
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
            MPNowPlayingInfoPropertyIsLiveStream: false,
        ]
        if let image = UIImage(systemName: "sportscourt.fill") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
