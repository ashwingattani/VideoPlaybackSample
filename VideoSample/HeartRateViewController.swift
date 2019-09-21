//
//  HeartRateViewController.swift
//  VideoSample
//
//  Created by Ashwin Gattani on 20/09/19.
//  Copyright © 2019 Ashwin Gattani. All rights reserved.
//

import UIKit

class HeartRateViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let heartRateModel = HeartRateDetectionModel.init()
        heartRateModel.delegate = self
        heartRateModel.preview = self.view
        heartRateModel.startDetection()
    }
}

extension HeartRateViewController: HeartRateDetectionModelDelegate {
    func heartRateStart() {
        print("detection started")
    }
    
    func heartRateEnd() {
        print("detection stopped")
    }
    
    func heartRateUpdate(_ bpm: Int32, atTime seconds: Int32) {
        print("heart rate: ", bpm, seconds)
    }
}
