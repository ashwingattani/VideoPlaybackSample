// switch on the flash in torch mode
if([camera isTorchModeSupported:AVCaptureTorchModeOn]) {
    [camera lockForConfiguration:nil];
    camera.torchMode=AVCaptureTorchModeOn;
    [camera unlockForConfiguration];
}

[session setSessionPreset:AVCaptureSessionPresetLow];

// Create the AVCapture Session
session = [[AVCaptureSession alloc] init];

// Get the default camera device
AVCaptureDevice* camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
if([camera isTorchModeSupported:AVCaptureTorchModeOn]) {
    [camera lockForConfiguration:nil];
    camera.torchMode=AVCaptureTorchModeOn;
    [camera unlockForConfiguration];
}
// Create a AVCaptureInput with the camera device
NSError *error=nil;
AVCaptureInput* cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:&error];
if (cameraInput == nil) {
    NSLog(@"Error to create camera capture:%@",error);
}

// Set the output
AVCaptureVideoDataOutput* videoOutput = [[AVCaptureVideoDataOutput alloc] init];

// create a queue to run the capture on
dispatch_queue_t captureQueue=dispatch_queue_create("catpureQueue", NULL);

// setup our delegate
[videoOutput setSampleBufferDelegate:self queue:captureQueue];

// configure the pixel format
videoOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber     numberWithUnsignedInt:kCVPixelFormatType_32BGRA], (id)kCVPixelBufferPixelFormatTypeKey,
                             nil];
// cap the framerate
videoOutput.minFrameDuration=CMTimeMake(1, 10);
// and the size of the frames we want
[session setSessionPreset:AVCaptureSessionPresetLow];

// Add the input and output
[session addInput:cameraInput];
[session addOutput:videoOutput];

// Start the session

[session startRunning];

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    
    
    // this is the image buffer
    
    CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    
    // Lock the image buffer
    
    CVPixelBufferLockBaseAddress(cvimgRef,0);
    
    
    // access the data
    
    int width=CVPixelBufferGetWidth(cvimgRef);
    int height=CVPixelBufferGetHeight(cvimgRef);
    
    
    // get the raw image bytes
    uint8_t *buf=(uint8_t *) CVPixelBufferGetBaseAddress(cvimgRef);
    size_t bprow=CVPixelBufferGetBytesPerRow(cvimgRef);
    
    
    // get the average red green and blue values from the image
    
    float r=0,g=0,b=0;
    for(int y=0; y<height; y++) {
        for(int x=0; x<width*4; x+=4) {
            b+=buf[x];
            g+=buf[x+1];
            r+=buf[x+2];
        }
        buf+=bprow;
    }
    r/=255*(float) (width*height);
    g/=255*(float) (width*height);
    b/=255*(float) (width*height);
    
    NSLog(@"%f,%f,%f", r, g, b);
}
