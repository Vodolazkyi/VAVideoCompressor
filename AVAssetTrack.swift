//
//  AVAssetTrack.swift
//  VAVideoCompressor
//
//  Created by Anton Vodolazkyi on 29.07.2018.
//  Copyright © 2018 Anton Vodolazkyi. All rights reserved.
//

import AVFoundation
import UIKit

extension AVAssetTrack {
    
    var orientation: (UIInterfaceOrientation, AVCaptureDevice.Position) {
        var orientation: UIInterfaceOrientation = .unknown
        var device: AVCaptureDevice.Position = .unspecified
        let t = preferredTransform
        
        if (t.a == 0 && t.b == 1.0 && t.d == 0) {
            orientation = .portrait
            
            if t.c == 1.0 {
                device = .front
            } else if t.c == -1.0 {
                device = .back
            }
        } else if (t.a == 0 && t.b == -1.0 && t.d == 0) {
            orientation = .portraitUpsideDown
            
            if t.c == -1.0 {
                device = .front
            } else if t.c == 1.0 {
                device = .back
            }
        } else if (t.a == 1.0 && t.b == 0 && t.c == 0) {
            orientation = .landscapeRight
            
            if t.d == -1.0 {
                device = .front
            } else if t.d == 1.0 {
                device = .back
            }
        } else if (t.a == -1.0 && t.b == 0 && t.c == 0) {
            orientation = .landscapeLeft
            
            if t.d == 1.0 {
                device = .front
            } else if t.d == -1.0 {
                device = .back
            }
        }
        
        return (orientation, device)
    }
    
    var isPortrait: Bool {
        return orientation.0.isPortrait
    }
    
    var orientationBasedSize: CGSize {
        guard isPortrait else {
            return naturalSize
        }
        
        return CGSize(width: naturalSize.height, height: naturalSize.width)
    }
    
}
