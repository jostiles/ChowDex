/*
Abstract:
Main view controller: handles camera, preview and cutout UI.
*/

import Foundation
import UIKit
import AVFoundation
import Vision


class SecondViewController: UIViewController {
    // MARK: - UI objects
    
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var cutoutView: UIView!
    @IBOutlet weak var wordView: UILabel!
    var maskLayer = CAShapeLayer()
    // Device orientation. Updated whenever the orientation changes to a different supported orientation.
    var currentOrientation = UIDeviceOrientation.portrait
    
    // MARK: - Capture related objects
    private let captureSession = AVCaptureSession()
    let captureSessionQueue = DispatchQueue(label: "com.example.apple-samplecode.CaptureSessionQueue")
    
    var captureDevice: AVCaptureDevice?
    
    var videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoDataOutputQueue")
    
    // MARK: - Region of interest (ROI) and text orientation
    // Region of video data output buffer that recognition should be run on.
    // Gets recalculated once the bounds of the preview layer are known.
    var regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    // Orientation of text to search for in the region of interest.
    var textOrientation = CGImagePropertyOrientation.up
    
    // MARK: - Coordinate transforms
    var bufferAspectRatio: Double!
    // Transform from UI orientation to buffer orientation.
    var uiRotationTransform = CGAffineTransform.identity
    // Transform bottom-left coordinates to top-left.
    var bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    // Transform coordinates in ROI to global coordinates (still normalized).
    var roiToGlobalTransform = CGAffineTransform.identity
    
    // Vision -> AVF coordinate transform.
    var visionToAVFTransform = CGAffineTransform.identity
    
    
    var request: VNRecognizeTextRequest!
    // Temporal string tracker
    let itemTracker = StringTracker2()
    let generator = UIImpactFeedbackGenerator(style: .medium)
    
    
    
    
    // MARK: - View controller methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        print("1")
        // Set up preview view.
        previewView.session = captureSession
        
        // Set up cutout view.
        cutoutView.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        maskLayer.backgroundColor = UIColor.clear.cgColor
        maskLayer.fillRule = .evenOdd
        cutoutView.layer.mask = maskLayer
        previewView.bringSubviewToFront(cutoutView)
        // Starting the capture session is a blocking call. Perform setup using
        // a dedicated serial dispatch queue to prevent blocking the main thread.
        captureSessionQueue.async {
            self.setupCamera()
            
            // Calculate region of interest now that the camera is setup.
            DispatchQueue.main.async {
                // Figure out initial ROI.
                self.calculateRegionOfInterest()
            }
        }
        
        // Add the subview at the end
        previewView.addSubview(cutoutView)
        print("2")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Only change the current orientation if the new one is landscape or
        // portrait. You can't really do anything about flat or unknown.
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation.isPortrait || deviceOrientation.isLandscape {
            currentOrientation = deviceOrientation
        }
        
        // Handle device orientation in the preview layer.
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            if let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
                videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            }
        }
        
        // Orientation changed: figure out new region of interest (ROI).
        calculateRegionOfInterest()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCutout()
    }
    
    // MARK: - Setup
    
    func calculateRegionOfInterest() {
        // In landscape orientation the desired ROI is specified as the ratio of
        // buffer width to height. When the UI is rotated to portrait, keep the
        // vertical size the same (in buffer pixels). Also try to keep the
        // horizontal size the same up to a maximum ratio.
        let desiredHeightRatio = 0.18
        let desiredWidthRatio = 0.6
        let maxPortraitWidth = 0.96

        // Figure out size of ROI.
        let size: CGSize
        if currentOrientation.isPortrait || currentOrientation == .unknown {
//             print(bufferAspectRatio)
            size = CGSize(width: min(desiredWidthRatio * bufferAspectRatio, maxPortraitWidth), height: desiredHeightRatio / bufferAspectRatio)
    
        } else {
            size = CGSize(width: desiredWidthRatio, height: desiredHeightRatio)
        }
        // Make it centered.
        regionOfInterest.origin = CGPoint(x: (1 - size.width) / 2, y: (1 - size.height) / 2)
        regionOfInterest.size = size
        
        // ROI changed, update transform.
        setupOrientationAndTransform()
        
        // Update the cutout to match the new ROI.
        DispatchQueue.main.async {
            // Wait for the next run cycle before updating the cutout. This
            // ensures that the preview layer already has its new orientation.
            self.updateCutout()
        }
    }
    
    func updateCutout() {
        // Figure out where the cutout ends up in layer coordinates.
        let roiRectTransform = bottomToTopTransform.concatenating(uiRotationTransform)
        let cutout = previewView.videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: regionOfInterest.applying(roiRectTransform))
        
        // Create the mask.
        let path = UIBezierPath(rect: cutoutView.frame)
        path.append(UIBezierPath(rect: cutout))
        maskLayer.path = path.cgPath
        
        // Move the number view down to under cutout.
        var numFrame = cutout
        numFrame.origin.y += numFrame.size.height
        wordView.frame = numFrame
        previewView.addSubview(cutoutView)
    }
    
    func setupOrientationAndTransform() {
        // Recalculate the affine transform between Vision coordinates and AVF coordinates.
        
        // Compensate for region of interest.
        let roi = regionOfInterest
        roiToGlobalTransform = CGAffineTransform(translationX: roi.origin.x, y: roi.origin.y).scaledBy(x: roi.width, y: roi.height)
        
        // Compensate for orientation (buffers always come in the same orientation).
        switch currentOrientation {
        case .landscapeLeft:
            textOrientation = CGImagePropertyOrientation.up
            uiRotationTransform = CGAffineTransform.identity
        case .landscapeRight:
            textOrientation = CGImagePropertyOrientation.down
            uiRotationTransform = CGAffineTransform(translationX: 1, y: 1).rotated(by: CGFloat.pi)
        case .portraitUpsideDown:
            textOrientation = CGImagePropertyOrientation.left
            uiRotationTransform = CGAffineTransform(translationX: 1, y: 0).rotated(by: CGFloat.pi / 2)
        default: // We default everything else to .portraitUp
            textOrientation = CGImagePropertyOrientation.right
            uiRotationTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -CGFloat.pi / 2)
        }
        
        // Full Vision ROI to AVF transform.
        visionToAVFTransform = roiToGlobalTransform.concatenating(bottomToTopTransform).concatenating(uiRotationTransform)
    }
    
    func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            print("Could not create capture device.")
            return
        }
        self.captureDevice = captureDevice
        
        // NOTE:
        // Requesting 4k buffers allows recognition of smaller text but will
        // consume more power. Use the smallest buffer size necessary to keep
        // down battery usage.
        if captureDevice.supportsSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
            bufferAspectRatio = 3840.0 / 2160.0
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
            bufferAspectRatio = 1920.0 / 1080.0
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Could not create device input.")
            return
        }
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }
        
        // Configure video data output.
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            // NOTE:
            // There is a trade-off to be made here. Enabling stabilization will
            // give temporally more stable results and should help the recognizer
            // converge. But if it's enabled the VideoDataOutput buffers don't
            // match what's displayed on screen, which makes drawing bounding
            // boxes very hard. Disable it in this app to allow drawing detected
            // bounding boxes on screen.
            videoDataOutput.connection(with: AVMediaType.video)?.preferredVideoStabilizationMode = .off
        } else {
            print("Could not add VDO output")
            return
        }
        
        // Set zoom and autofocus to help focus on very small text.
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.videoZoomFactor = 2
            captureDevice.autoFocusRangeRestriction = .near
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not set zoom level due to error: \(error)")
            return
        }
        
        captureSession.startRunning()
    }
    
    // MARK: - UI drawing and interaction
    
    func showString(string: String) {
        // Found a definite number.
        // Stop the camera synchronously to ensure that no further buffers are
        // received. Then update the number view asynchronously.
        captureSessionQueue.sync {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                // string is the interpreted output
                self.wordView.text = string
                self.wordView.isHidden = false
                self.wordView.layer.zPosition = 1;
            }
        }
    }
    
    
    func recognizeTextHandler(request: VNRequest, error: Error?) {
    //        var numbers = [String]()
            var menuItems = [String]()
            var redBoxes = [CGRect]() // Shows all recognized text lines
            var greenBoxes = [CGRect]() // Shows words that might be serials
            
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            let maximumCandidates = 1
            
            for visionResult in results {
                guard let candidate = visionResult.topCandidates(maximumCandidates).first else { continue }
                
                // Draw red boxes around any detected text, and green boxes around
                // any detected phone numbers. The phone number may be a substring
                // of the visionResult. If a substring, draw a green box around the
                // number and a red box around the full string. If the number covers
                // the full result only draw the green box.
                var numberIsSubstring = true
                
                // Checks to see if the top candidate of the scan is a phone number
                // It does this through extractPhoneNumber, which will return nil if unable
                // Future change: switch extractPhoneNumber to look for a list of restaurants
                
                // Converts candidate to a string
                let textCandidate = candidate.string
                
                let (keyBool, vettedCandidate, rawCandidate) = searchList(keyword: textCandidate)
                if keyBool {
    //                print(vettedCandidate)
    //                exit(-1)
                    // vettedCandidate is the correct version of what the VNVision is
                    // looking for
                    // rawCandidate is what the VNVision actually sees
                    let firstIndex = textCandidate.index(of: rawCandidate)!
                    let lastIndex = textCandidate.endIndex(of: rawCandidate)!
                    let range = firstIndex..<lastIndex
                    if let menuBox = try? candidate.boundingBox(for: range)?.boundingBox{
                        menuItems.append(vettedCandidate)
                        greenBoxes.append(menuBox)
                    }
                    numberIsSubstring = !(range.lowerBound == candidate.string.startIndex && range.upperBound == candidate.string.endIndex)
                }

                
                if numberIsSubstring {
                    redBoxes.append(visionResult.boundingBox)
                }
            }
            
            // Log any found menu items.
            itemTracker.logFrame(strings: menuItems)
            show(boxGroups: [(color: UIColor.red.cgColor, boxes: redBoxes), (color: UIColor.green.cgColor, boxes: greenBoxes)])
            
            // Check if we have any temporally stable numbers.
            if let sureNumber = itemTracker.getStableString() {
                // showString displays the output
                showString(string: sureNumber)
                // Haptic feedback generator
                generator.impactOccurred()
                itemTracker.reset(string: sureNumber)
            }
        }
        
//        override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//                // Configure for running in real-time.
//                request.recognitionLevel = .fast
//                // Language correction won't help recognizing phone numbers. It also
//                // makes recognition slower.
//                request.usesLanguageCorrection = false
//                // Only run on the region of interest for maximum speed.
//                request.regionOfInterest = regionOfInterest
//
//                let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
//                do {
//                    try requestHandler.perform([request])
//                } catch {
//                    print(error)
//                }
//            }
//        }
        
        // MARK: - Bounding box drawing
        
        // Draw a box on screen. Must be called from main queue.
        var boxLayer = [CAShapeLayer]()
        func draw(rect: CGRect, color: CGColor) {
            let layer = CAShapeLayer()
            layer.opacity = 0.5
            layer.borderColor = color
    //        print(color.hashValue)
    //        print(layer.borderColor)
            // If it's a green box, make it a little more thicc
            if color.hashValue == 356111360 {
                layer.borderWidth = 1.5
            } else {
                layer.borderWidth = 0.5
            }
            layer.frame = rect
            boxLayer.append(layer)
            previewView.videoPreviewLayer.insertSublayer(layer, at: 1)
        }
        
        // Remove all drawn boxes. Must be called on main queue.
        func removeBoxes() {
            for layer in boxLayer {
                layer.removeFromSuperlayer()
            }
            boxLayer.removeAll()
        }
        
        typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])
        
        // Draws groups of colored boxes.
        func show(boxGroups: [ColoredBoxGroup]) {
            DispatchQueue.main.async {
                let layer = self.previewView.videoPreviewLayer
                self.removeBoxes()
                for boxGroup in boxGroups {
                    let color = boxGroup.color
                    for box in boxGroup.boxes {
                        let rect = layer.layerRectConverted(fromMetadataOutputRect: box.applying(self.visionToAVFTransform))
                        self.draw(rect: rect, color: color)
                    }
                }
            }
        }
        
        // MARK: Search for string
        // Gets a string and searches to find if it is in an array of possibilities
        // Returns Boolean and the word that passed
        func searchList(keyword: String) -> (Bool, String, String) {
            let threshold = 0.2
            let textCandidateArray = keyword.components(separatedBy: " ")
            
            // Array of entries that we are looking for
            let keywordArray = ["assistance", "number", "Complimentary", "remove your garbage", "JORDAN OLIVAS", "Air Force", "Geneva", "STORE CREDITS", "REDEMPTION", "Country Fried Steak Skillet", "Biscuits & Gravy", "Chorizo Omelet", "material", "between", "Landsharks", "Thai Kitchen", "Island Wing Company", "Traditional Breakfast Sampler", "The Mule", "Crepes", "Breakfast", "Gumbo", "Dinner", "IPA", "shrimp", "po' boy"]
            
            // Take the Levenshtein distance between each word in the array to test
            // and the word being tested. Then take the ratio of the distance to the
            // length of the total word. If below or equal the threshold, it will pass
            for candidate in textCandidateArray {
                for option in keywordArray {
                    var optionScore: Double = 0
                    // bufferArray is the menu option split on spaces
                    let bufferArray = option.components(separatedBy: " ")
                    let currInd: Int = textCandidateArray.firstIndex(of: candidate)!
                    var avgScore: Double = 0
                    
                    // Iterate if the menu option is more than one word long
                    if bufferArray.count > 1 && (textCandidateArray.count > (currInd + bufferArray.count)) {
                        var rawCandidateString: String = ""
                        var rawCandidateArray = [String]()
                        // Iterate over each item in the menu option array
                        for subItem in bufferArray {
                            let subItemIndex = bufferArray.firstIndex(of: subItem)!
                            let candidateIndex = textCandidateArray.firstIndex(of: candidate)!
                            // Set the index to test to the consecutive item in the
                            // candidate array
                            let testIndex = Int(candidateIndex) + Int(subItemIndex)
                            // Avoid any out of bounds errors
                            if testIndex < textCandidateArray.count {
                                let candidateToTest = textCandidateArray[testIndex]
                                rawCandidateArray.append(candidateToTest)
                                let subItemScore = Double(subItem.distanceLevenshtein(between: candidateToTest)) / Double(candidateToTest.count)
                                optionScore += subItemScore
    //                            print("Multi: \(rawCandidateString)")
                            }
                            rawCandidateString = rawCandidateArray.joined(separator: " ")
                        }
                        avgScore = optionScore / Double(bufferArray.count)
    //                    print("avg: \(avgScore)")
                        if avgScore < threshold {
                            return (true, option, rawCandidateString)
                        }
                    } else {
                        avgScore = (Double(option.distanceLevenshtein(between: candidate)) / Double(option.count))
    //                    print("single: \(avgScore)")
                    }
                    
                    if avgScore < threshold {
                        return (true, option, candidate)
                    }
                }
            }
            return (false, "", "")
        }
    
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        captureSessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            DispatchQueue.main.async {
                self.wordView.isHidden = true
            }
        }
    }
    
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SecondViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This is implemented in VisionViewController.
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            // Configure for running in real-time.
            request.recognitionLevel = .fast
            // Language correction won't help recognizing phone numbers. It also
            // makes recognition slower.
            request.usesLanguageCorrection = false
            // Only run on the region of interest for maximum speed.
            request.regionOfInterest = regionOfInterest
            
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
            do {
                try requestHandler.perform([request])
            } catch {
                print(error)
            }
        }
    }
}

// MARK: - Utility extensions

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}


