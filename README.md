# VAVideoCompressor
Video compressor written in swift

## Usage

```swift
  let audioSettings = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey: 2,
      AVSampleRateKey: 44100,
      AVEncoderBitRateKey: 128000
  ]
  let asset = AVAsset(url: URL(string: "video_path")!)
  let outputPath = URL(string: "output_video_path")!

  VAVideoCompressor.exportAsynchronously(
      with: asset,
      outputFileType: AVFileType.mp4,
      outputURL: outputPath,
      videoSettings: VAVideoCompressor.videoSettingsForPreset(.medium, size: asset.videoSize()),
      audioSettings: audioSettings,
      completion: { error in
          if let error = error {
              print(error)
          } else {
              print("success")
          }
  })
```
