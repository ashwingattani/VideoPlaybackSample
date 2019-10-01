import UIKit

import AVFoundation
import Charts

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    
    @IBOutlet weak var camPreview: UIView!
    @IBOutlet weak var lineCharView: LineChartView!
    
    let cameraButton = UIView()
    let captureSession = AVCaptureSession()
    let movieOutput = AVCaptureMovieFileOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    var outputURL: URL!
    
    private var hueDataSet: NSMutableArray = []
    let framePerSeconds = 30
    
    private var lastH: Float = 0
    private var lastHighPassValue: Float = 0
    
//    private var redLineChartEntry = [ChartDataEntry]()
//    private var blueLineChartEntry = [ChartDataEntry]()
//    private var greenLineChartEntry = [ChartDataEntry]()
//    private var alphaLineChartEntry = [ChartDataEntry]()
    
    private var hueLineChartEntry = [ChartDataEntry]()
    
//    private var latestRedValue: Float = 0
//    private var latestBlueValue: Float = 0
//    private var latestGreenValue: Float = 0
//    private var latestAlphaValue: Float = 0
    
    private var iterationCount: Double = 0
    
    private var graphTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if setupSession() {
            setupPreview()
            startSession()
        }
        
        cameraButton.isUserInteractionEnabled = true
        
        let cameraButtonRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.startCapture))
        
        cameraButton.addGestureRecognizer(cameraButtonRecognizer)
        
        cameraButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        cameraButton.center = CGPoint.init(x: self.view.center.x, y: self.view.center.y+self.view.center.y/4)
        
        cameraButton.backgroundColor = UIColor.red
        
        camPreview.addSubview(cameraButton)
        
    }
    
    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = camPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        camPreview.layer.addSublayer(previewLayer)
    }
    
    //MARK:- Setup Camera
    
    func setupSession() -> Bool {
        
        captureSession.sessionPreset = AVCaptureSession.Preset.low
        
        // Setup Camera
        let camera = AVCaptureDevice.default(for: AVMediaType.video)!
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
        
        var currentFormat: AVCaptureDevice.Format?
        for format in camera.formats {
            let ranges = format.videoSupportedFrameRateRanges
            let frameRates: AVFrameRateRange = ranges[0]
            
            if (Int(frameRates.maxFrameRate) == framePerSeconds) {
                if currentFormat == nil {
                    currentFormat = format
                } else if (CMVideoFormatDescriptionGetDimensions(format.formatDescription).width < CMVideoFormatDescriptionGetDimensions(currentFormat!.formatDescription).width && CMVideoFormatDescriptionGetDimensions(format.formatDescription).height < CMVideoFormatDescriptionGetDimensions(currentFormat!.formatDescription).height) {
                    currentFormat = format
                }
            }
        }
        
        do {
            try camera.lockForConfiguration()
            camera.activeFormat = currentFormat ?? camera.activeFormat
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(framePerSeconds))
            camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(framePerSeconds))
            camera.unlockForConfiguration()
            
        } catch {
            print("Error setting camera configuration: \(error)")
            return false
        }
//        AVCaptureDeviceFormat *currentFormat;
//        for (AVCaptureDeviceFormat *format in captureDevice.formats)
//        {
//            NSArray *ranges = format.videoSupportedFrameRateRanges;
//            AVFrameRateRange *frameRates = ranges[0];
//
//            // Find the lowest resolution format at the frame rate we want.
//            if (frameRates.maxFrameRate == FRAMES_PER_SECOND && (!currentFormat || (CMVideoFormatDescriptionGetDimensions(format.formatDescription).width < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).width && CMVideoFormatDescriptionGetDimensions(format.formatDescription).height < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).height)))
//            {
//                currentFormat = format;
//            }
//        }
        
        // Movie output
//        if captureSession.canAddOutput(movieOutput) {
//            captureSession.addOutput(movieOutput)
//        }
        
        //Video output
        let captureQueue = DispatchQueue.init(label: "catpureQueue")
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        return true
    }
    
    //MARK:- Camera Session
    func startSession() {
        
        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
                do {
                    try self.activeInput.device.lockForConfiguration()
                    try self.activeInput.device.setTorchModeOn(level: 1.0)
                    self.activeInput.device.unlockForConfiguration()
                } catch {
                    print("error in torch")
                }
            }
        }
        
//        self.graphTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.addNewEntryToGraph), userInfo: nil, repeats: true)
    }
    
    func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
        if let timer = graphTimer {
            timer.invalidate()
            self.graphTimer = nil
        }
    }
    
    func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }
    
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        return orientation
    }
    
    @objc func startCapture() {
        
        startRecording()
        
    }
    
    //EDIT 1: I FORGOT THIS AT FIRST
    
    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let vc = segue.destination as! VideoPlaybackViewController
        
        vc.videoURL = sender as? URL
        
    }
    
    func startRecording() {

        if movieOutput.isRecording == false {
            
            let connection = movieOutput.connection(with: AVMediaType.video)
            
            if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }
            
            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
            
            let device = activeInput.device
            
            if (device.isSmoothAutoFocusSupported) {
                
                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = false
                    try device.setTorchModeOn(level: 1.0)
                    device.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
                
            }
            
            //EDIT2: And I forgot this
            outputURL = tempURL()
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            
        }
        else {
            stopRecording()
        }
        
    }
    
    func stopRecording() {
        
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
        }
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
//        if (error != nil) {
//
//            print("Error recording movie: \(error!.localizedDescription)")
//
//        } else {
//
//            let videoRecorded = outputURL! as URL
//
//            let videoPlayController = VideoPlaybackViewController.init()
//            videoPlayController.videoURL = videoRecorded
//            self.present(videoPlayController, animated: true, completion: nil)
//
//        }
        
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            CVPixelBufferLockBaseAddress(cvImageBuffer, .readOnly)
            
            let width = CVPixelBufferGetWidth(cvImageBuffer)
            let height = CVPixelBufferGetHeight(cvImageBuffer)
            
            let baseAddress = CVPixelBufferGetBaseAddressOfPlane(cvImageBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvImageBuffer, 0)
            let bTypedPtr = baseAddress!.bindMemory(to: UInt8.self, capacity: bytesPerRow*height)
            let byteBuffer = UnsafeMutablePointer<UInt8>(bTypedPtr)
            
            var r: Float = 0, g: Float = 0, b: Float = 0
            for y in 0..<height {
                var x = y
                while x<(width*4) {
                    b+=Float(byteBuffer[x])
                    g+=Float(byteBuffer[x+1])
                    r+=Float(byteBuffer[x+2])
                    x+=4
                }
            }
            
            let color = UIColor.init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            
//            let highPassValue: Float = Float(hue) - lastH;
//            lastH = Float(hue);
//            lastHighPassValue = highPassValue;
//
//            let lowPassValue: Float = (lastHighPassValue + highPassValue) / 2;
//
//            if self.hueDataSet.count > 500 && lowPassValue > 0 {
//                let lastLowPassValue = self.hueDataSet[self.hueDataSet.count-1] as! Float
//                if lastLowPassValue < 0 {
//                    AudioServicesPlaySystemSound(SystemSoundID(1052))
//                }
//            }
//
//            self.hueDataSet.add(lowPassValue)
//
//            hueLineChartEntry.append(ChartDataEntry(x: iterationCount, y: Double(lowPassValue)))
//            self.addNewEntryToGraph()
            
            self.hueDataSet.add(hue)

            if (self.hueDataSet.count % framePerSeconds == 0) {
                let displaySeconds = hueDataSet.count / framePerSeconds
                let bandpassFilteredItems = self.butterworthBandpassFilter(inputData: self.hueDataSet)
                let smoothedBandpassItems = self.medianSmoothing(inputData: bandpassFilteredItems)
                let peakCount = self.peakCount(inputData: smoothedBandpassItems)

                let secondsPassed = smoothedBandpassItems.count / framePerSeconds
                let percentage = secondsPassed / 60

                if percentage > 0 {
                    let heartRate = peakCount / percentage
                    print("heart rate: ", heartRate, "in seconds: ", displaySeconds)
                }
            }

//            self.latestRedValue = r/(255 * Float(width*height))
//            self.latestGreenValue = g/(255 * Float(width*height))
//            self.latestBlueValue = b/(255 * Float(width*height))
            
            
            
            
        }
    }
}

//Support Functions for data filteration
extension ViewController {
    func butterworthBandpassFilter(inputData: NSMutableArray) -> NSArray {
        let NZEROS: Double = 8
        let NPOLES: Double = 8
        var xv: [Double] = Array(repeating: 0, count: Int(NZEROS+1))
        var yv: [Double] = Array(repeating: 0, count: Int(NPOLES+1))
        
        let dGain: Double = 1.232232910e+02
        
        let outputArray = NSMutableArray()
        
        for number in inputData {
            let input: Double = (number as! NSNumber).doubleValue
            
            xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
            xv[8] = input / dGain;
            yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
            let y0 = ( -0.1397436053 * yv[0])
            let y1 = (  1.2948188815 * yv[1])
            let y2 = ( -5.4070037946 * yv[2])
            let y3 = ( 13.2683981280 * yv[3])
            let y4 = (-20.9442560520 * yv[4])
            let y5 = ( 21.7932169160 * yv[5])
            let y6 = (-14.5817197500 * yv[6])
            let y7 = (  5.7161939252 * yv[7])
            yv[8] = (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4] + y0 + y1
                + y2 + y3 + y4 + y5 + y6 + y7
            
            outputArray.add(yv[8])
        }
        
        return outputArray
    }
    
    func medianSmoothing(inputData: NSArray) -> NSArray {
        let newData = NSMutableArray()
        
        for i in 0..<inputData.count {
            if (i == 0 ||
                i == 1 ||
                i == 2 ||
                i == inputData.count - 1 ||
                i == inputData.count - 2 ||
                i == inputData.count - 3)        {
                newData.add(inputData[i])
            }
            else
            {
                var items = NSArray.init(objects: inputData[i-2],
                                         inputData[i-1],
                                         inputData[i],
                                         inputData[i+1],
                                         inputData[i+2])
                items = items.sortedArray(using: [NSSortDescriptor.init(key: "self", ascending: true)]) as NSArray
                newData.add(items[2])
            }
        }
        
        return newData
    }
    
    func peakCount(inputData: NSArray) -> Int {
        if (inputData.count == 0)
        {
            return 0;
        }
        
        var count: Int = 0;
        var i: Int = 3
        while i<(inputData.count-3) {
            if ((inputData[i] as! NSNumber).doubleValue > 0 &&
                (inputData[i] as! NSNumber).doubleValue > (inputData[i-1] as! NSNumber).doubleValue &&
                (inputData[i] as! NSNumber).doubleValue > (inputData[i-2] as! NSNumber).doubleValue &&
                (inputData[i] as! NSNumber).doubleValue > (inputData[i-2] as! NSNumber).doubleValue &&
                (inputData[i] as! NSNumber).doubleValue >= (inputData[i+1] as! NSNumber).doubleValue &&
                (inputData[i] as! NSNumber).doubleValue >= (inputData[i+2] as! NSNumber).doubleValue &&
                (inputData[i] as! NSNumber).doubleValue >= (inputData[i+3] as! NSNumber).doubleValue
                )
            {
                count = count + 1;
                i = i + 4;
            } else {
                i = i + 1
            }
        }
        
        return count;
    }
}


//Extension for Charts
extension ViewController {
    
    @objc func addNewEntryToGraph() {
//        redLineChartEntry.append(ChartDataEntry(x: iterationCount, y: Double(self.latestRedValue)))
//        blueLineChartEntry.append(ChartDataEntry(x: iterationCount, y: Double(self.latestBlueValue)))
//        greenLineChartEntry.append(ChartDataEntry(x: iterationCount, y: Double(self.latestGreenValue)))
        
        self.updateGraph()
        self.iterationCount += 1
    }
    
    func updateGraph() {
//        let redLine = LineChartDataSet(entries: redLineChartEntry, label: "red")
//        let blueLine = LineChartDataSet(entries: blueLineChartEntry, label: "blue")
//        let greenLine = LineChartDataSet(entries: greenLineChartEntry, label: "green")
        
        let hueLine = LineChartDataSet(entries: hueLineChartEntry, label: "red")
        
        hueLine.colors = [NSUIColor.red]
        hueLine.drawCirclesEnabled = false
        
//        blueLine.colors = [NSUIColor.blue]
//        blueLine.drawCirclesEnabled = false
//
//        greenLine.colors = [NSUIColor.green]
//        greenLine.drawCirclesEnabled = false
        
        let data = LineChartData()
        data.addDataSet(hueLine)
        
//        data.addDataSet(greenLine)
//        data.addDataSet(blueLine)
        
        DispatchQueue.main.async {
            self.lineCharView.backgroundColor = .gray
            self.lineCharView.data = data
        }
        
    }
}
