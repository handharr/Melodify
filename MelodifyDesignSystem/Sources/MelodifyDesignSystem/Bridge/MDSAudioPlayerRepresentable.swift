import SwiftUI
import UIKit

/// UIViewRepresentable wrapper for MDSAudioPlayerView.
/// MDSAudioPlayerView is the only UIKit component in the DS with no clean native
/// SwiftUI equivalent — stateful play/pause + waveform icon requires UIButton lifecycle.
public struct MDSAudioPlayerRepresentable: UIViewRepresentable {
    public let configuration: MDSAudioPlayerConfiguration
    public let onPlayPause: () -> Void

    public init(configuration: MDSAudioPlayerConfiguration, onPlayPause: @escaping () -> Void) {
        self.configuration = configuration
        self.onPlayPause = onPlayPause
    }

    public func makeUIView(context: Context) -> MDSAudioPlayerView {
        let view = MDSAudioPlayerView()
        view.onPlayPause = onPlayPause
        return view
    }

    public func updateUIView(_ uiView: MDSAudioPlayerView, context: Context) {
        uiView.configure(with: configuration)
    }
}
