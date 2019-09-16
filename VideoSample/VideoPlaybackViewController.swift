//
//  VideoPlaybackViewController.swift
//  VideoSample
//
//  Created by Ashwin Gattani on 16/09/19.
//  Copyright © 2019 Ashwin Gattani. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPlaybackViewController: UIViewController {

    let avPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer!
    
    var videoURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        avPlayerLayer = AVPlayerLayer(player: avPlayer)
        avPlayerLayer.frame = view.bounds
        avPlayerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.view.layer.insertSublayer(avPlayerLayer, at: 0)
        
        view.layoutIfNeeded()
        
        let playerItem = AVPlayerItem(url: videoURL as URL)
        avPlayer.replaceCurrentItem(with: playerItem)
        
        avPlayer.play()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(VideoPlaybackViewController.dismissView)))
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer.currentItem, queue: .main) { [weak self] _ in
            self?.avPlayer.seek(to: CMTime.zero)
            self?.avPlayer.play()
        }
    }

    @objc func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
}
