//
// VideoScreenView.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
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
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VideoPlayerContainer(item: item, posterURL: posterURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                Text(item.title)
                    .font(.system(size: DesignTokens.FontSize.title, weight: .bold))
                Text("Event: \(item.eventId)")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                Text("Duration: \(formattedDuration(item.durationSeconds))")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                Text("Transcript placeholder — demo copy only.")
                    .font(.system(size: DesignTokens.FontSize.body))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
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
