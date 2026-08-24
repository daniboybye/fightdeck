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

struct VideoScreenView: View {
    let item: MediaItem
    let posterURL: URL

    @State private var player: AVPlayer?
    @State private var controller: AVPlayerViewController?

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
    let posterURL: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        configureAudioSession()
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.showsPlaybackControls = true

        if let url = URL(string: item.url) {
            let player = AVPlayer(url: url)
            controller.player = player
            context.coordinator.player = player
            updateNowPlaying(item: item)
            player.play()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var player: AVPlayer?
    }

    private func configureAudioSession() {
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
