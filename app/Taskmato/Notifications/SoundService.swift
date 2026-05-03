//
//  SoundService.swift
//  Taskmato
//

import AppKit
import AVFoundation

/// Plays a short alert sound when a Pomodoro phase completes.
///
/// "Radial" is loaded from ToneLibrary (macOS ringtone, `.m4r` format) via `AVAudioPlayer`.
/// All other names are loaded as `.aiff` files from `/System/Library/Sounds/` via `NSSound`.
/// Falls back to "Glass", then `NSSound.beep()` if a sound cannot be found.
final class SoundService {

    private var audioPlayer: AVAudioPlayer?
    private var activeSound: NSSound?

    /// Plays the named sound. Defaults to `"Radial"`, falling back to `"Glass"` if unavailable.
    func play(named name: String = "Radial") {
        if name == "Radial" {
            let url = URL(filePath: "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones/Radial-EncoreInfinitum.m4r")
            if let player = try? AVAudioPlayer(contentsOf: url) {
                audioPlayer = player
                player.play()
                return
            }
            playSystemSound(named: "Glass")
        } else {
            playSystemSound(named: name)
        }
    }

    private func playSystemSound(named name: String) {
        let url = URL(filePath: "/System/Library/Sounds/\(name).aiff")
        if let sound = NSSound(contentsOf: url, byReference: true) {
            activeSound = sound
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
