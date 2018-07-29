//
//  AVAsset.swift
//  VAVideoCompressor
//
//  Created by Anton Vodolazkyi on 29.07.2018.
//  Copyright © 2018 Anton Vodolazkyi. All rights reserved.
//

import AVFoundation
import UIKit

extension AVAsset {
    
    func videoSize() -> CGSize {
        let visual = AVMediaCharacteristic.visual
        let vTrack = tracks(withMediaCharacteristic: visual)[0]
        var error: NSError? = nil
        let keyPath = #keyPath(AVAssetTrack.naturalSize)
        if vTrack.statusOfValue(forKey: keyPath, error: &error) == .loaded {
            return vTrack.orientationBasedSize
        } else {
            var size = CGSize()
            let dg = DispatchGroup()
            dg.enter()
            vTrack.loadValuesAsynchronously(forKeys: [keyPath]) {
                size = vTrack.orientationBasedSize
                dg.leave()
            }
            dg.wait()
            return size
        }
    }
    
}
