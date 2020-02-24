///*
//See LICENSE folder for this sample’s licensing information.
//
//Abstract:
//Vision view controller.
//            Recognizes text using a Vision VNRecognizeTextRequest request handler in pixel buffers from an AVCaptureOutput.
//            Displays bounding boxes around recognized text results in real time.
//*/
//
//import Foundation
//import UIKit
//import AVFoundation
//import Vision
//
//class VisionViewController: SecondViewController {
//
//    var request: VNRecognizeTextRequest!
//    // Temporal string tracker
//    let itemTracker = StringTracker2()
//    let generator = UIImpactFeedbackGenerator(style: .medium)
//
//    override func viewDidLoad() {
//        // Set up vision request before letting ViewController set up the camera
//        // so that it exists when the first buffer is received.
//        print("yppp")
//        request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
//        print("trip here")
//        super.viewDidLoad()
//    }
//
//    // MARK: - Text recognition
//
//    // Vision recognition handler.
//    func recognizeTextHandler(request: VNRequest, error: Error?) {
////        var numbers = [String]()
//        var menuItems = [String]()
//        var redBoxes = [CGRect]() // Shows all recognized text lines
//        var greenBoxes = [CGRect]() // Shows words that might be serials
//
//        guard let results = request.results as? [VNRecognizedTextObservation] else {
//            return
//        }
//
//        let maximumCandidates = 1
//
//        for visionResult in results {
//            guard let candidate = visionResult.topCandidates(maximumCandidates).first else { continue }
//
//            // Draw red boxes around any detected text, and green boxes around
//            // any detected phone numbers. The phone number may be a substring
//            // of the visionResult. If a substring, draw a green box around the
//            // number and a red box around the full string. If the number covers
//            // the full result only draw the green box.
//            var numberIsSubstring = true
//
//            // Checks to see if the top candidate of the scan is a phone number
//            // It does this through extractPhoneNumber, which will return nil if unable
//            // Future change: switch extractPhoneNumber to look for a list of restaurants
//
//            // Converts candidate to a string
//            let textCandidate = candidate.string
//
//            let (keyBool, vettedCandidate, rawCandidate) = searchList(keyword: textCandidate)
//            if keyBool {
////                print(vettedCandidate)
////                exit(-1)
//                // vettedCandidate is the correct version of what the VNVision is
//                // looking for
//                // rawCandidate is what the VNVision actually sees
//                let firstIndex = textCandidate.index(of: rawCandidate)!
//                let lastIndex = textCandidate.endIndex(of: rawCandidate)!
//                let range = firstIndex..<lastIndex
//                if let menuBox = try? candidate.boundingBox(for: range)?.boundingBox{
//                    menuItems.append(vettedCandidate)
//                    greenBoxes.append(menuBox)
//                }
//                numberIsSubstring = !(range.lowerBound == candidate.string.startIndex && range.upperBound == candidate.string.endIndex)
//            }
//
//
//            if numberIsSubstring {
//                redBoxes.append(visionResult.boundingBox)
//            }
//        }
//
//        // Log any found menu items.
//        itemTracker.logFrame(strings: menuItems)
//        show(boxGroups: [(color: UIColor.red.cgColor, boxes: redBoxes), (color: UIColor.green.cgColor, boxes: greenBoxes)])
//
//        // Check if we have any temporally stable numbers.
//        if let sureNumber = itemTracker.getStableString() {
//            // showString displays the output
//            showString(string: sureNumber)
//            // Haptic feedback generator
//            generator.impactOccurred()
//            itemTracker.reset(string: sureNumber)
//        }
//    }
//
//    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//            // Configure for running in real-time.
//            request.recognitionLevel = .fast
//            // Language correction won't help recognizing phone numbers. It also
//            // makes recognition slower.
//            request.usesLanguageCorrection = false
//            // Only run on the region of interest for maximum speed.
//            request.regionOfInterest = regionOfInterest
//
//            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
//            do {
//                try requestHandler.perform([request])
//            } catch {
//                print(error)
//            }
//        }
//    }
//
//    // MARK: - Bounding box drawing
//
//    // Draw a box on screen. Must be called from main queue.
//    var boxLayer = [CAShapeLayer]()
//    func draw(rect: CGRect, color: CGColor) {
//        let layer = CAShapeLayer()
//        layer.opacity = 0.5
//        layer.borderColor = color
////        print(color.hashValue)
////        print(layer.borderColor)
//        // If it's a green box, make it a little more thicc
//        if color.hashValue == 356111360 {
//            layer.borderWidth = 1.5
//        } else {
//            layer.borderWidth = 0.5
//        }
//        layer.frame = rect
//        boxLayer.append(layer)
//        previewView.videoPreviewLayer.insertSublayer(layer, at: 1)
//    }
//
//    // Remove all drawn boxes. Must be called on main queue.
//    func removeBoxes() {
//        for layer in boxLayer {
//            layer.removeFromSuperlayer()
//        }
//        boxLayer.removeAll()
//    }
//
//    typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])
//
//    // Draws groups of colored boxes.
//    func show(boxGroups: [ColoredBoxGroup]) {
//        DispatchQueue.main.async {
//            let layer = self.previewView.videoPreviewLayer
//            self.removeBoxes()
//            for boxGroup in boxGroups {
//                let color = boxGroup.color
//                for box in boxGroup.boxes {
//                    let rect = layer.layerRectConverted(fromMetadataOutputRect: box.applying(self.visionToAVFTransform))
//                    self.draw(rect: rect, color: color)
//                }
//            }
//        }
//    }
//
//    // MARK: Search for string
//    // Gets a string and searches to find if it is in an array of possibilities
//    // Returns Boolean and the word that passed
//    func searchList(keyword: String) -> (Bool, String, String) {
//        let threshold = 0.2
//        let textCandidateArray = keyword.components(separatedBy: " ")
//
//        // Array of entries that we are looking for
//        let keywordArray = ["assistance", "number", "Complimentary", "remove your garbage"]//["Landsharks", "Thai Kitchen", "Island Wing Company"]
//
//        // Take the Levenshtein distance between each word in the array to test
//        // and the word being tested. Then take the ratio of the distance to the
//        // length of the total word. If below or equal the threshold, it will pass
//        for candidate in textCandidateArray {
//            for option in keywordArray {
//                var optionScore: Double = 0
//                // bufferArray is the menu option split on spaces
//                let bufferArray = option.components(separatedBy: " ")
//                let currInd: Int = textCandidateArray.firstIndex(of: candidate)!
//                var avgScore: Double = 0
//
//                // Iterate if the menu option is more than one word long
//                if bufferArray.count > 1 && (textCandidateArray.count > (currInd + bufferArray.count)) {
//                    var rawCandidateString: String = ""
//                    var rawCandidateArray = [String]()
//                    // Iterate over each item in the menu option array
//                    for subItem in bufferArray {
//                        let subItemIndex = bufferArray.firstIndex(of: subItem)!
//                        let candidateIndex = textCandidateArray.firstIndex(of: candidate)!
//                        // Set the index to test to the consecutive item in the
//                        // candidate array
//                        let testIndex = Int(candidateIndex) + Int(subItemIndex)
//                        // Avoid any out of bounds errors
//                        if testIndex < textCandidateArray.count {
//                            let candidateToTest = textCandidateArray[testIndex]
//                            rawCandidateArray.append(candidateToTest)
//                            let subItemScore = Double(subItem.distanceLevenshtein(between: candidateToTest)) / Double(candidateToTest.count)
//                            optionScore += subItemScore
////                            print("Multi: \(rawCandidateString)")
//                        }
//                        rawCandidateString = rawCandidateArray.joined(separator: " ")
//                    }
//                    avgScore = optionScore / Double(bufferArray.count)
////                    print("avg: \(avgScore)")
//                    if avgScore < threshold {
//                        return (true, option, rawCandidateString)
//                    }
//                } else {
//                    avgScore = (Double(option.distanceLevenshtein(between: candidate)) / Double(option.count))
////                    print("single: \(avgScore)")
//                }
//
//                if avgScore < threshold {
//                    return (true, option, candidate)
//                }
//            }
//        }
//        return (false, "", "")
//    }
//}
//
////extension String {
////    public func distanceLevenshtein(between target: String) -> Int {
////        if self == target {
////            return 0
////        }
////        if self.count == 0 {
////            return target.count
////        }
////        if target.count == 0 {
////            return self.count
////        }
////
////        // The previous row of distances
////        var v0 = [Int](repeating: 0, count: target.count + 1)
////        // Current row of distances.
////        var v1 = [Int](repeating: 0, count: target.count + 1)
////        // Initialize v0.
////        // Edit distance for empty self.
////        for i in 0..<v0.count {
////            v0[i] = i
////        }
////        let selfArray = Array(self)
////        let targetArray = Array(target)
////        for i in 0..<self.count {
////            // Calculate v1 (current row distances) from previous row v0
////            // Edit distance is delete (i + 1) chars from self to match empty t.
////            v1[0] = i + 1
////
////            // Use formula to fill rest of the row.
////            for j in 0..<target.count {
////                let cost = selfArray[i] == targetArray[j] ? 0 : 1
////                v1[j + 1] = Swift.min(
////                    v1[j] + 1,
////                    v0[j + 1] + 1,
////                    v0[j] + cost
////                )
////            }
////
////            // Copy current row to previous row for next iteration.
////            for j in 0..<v0.count {
////                v0[j] = v1[j]
////            }
////        }
////
////        return v1[target.count]
////    }
////}
////
////extension String.Index {
////    func distance<S: StringProtocol>(in string: S) -> Int { string.distance(to: self) }
////}
////
////extension StringProtocol {
////    func indexDistance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
////
////    func indexDistance<S: StringProtocol>(of string: S) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
////
////    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
////        range(of: string, options: options)?.lowerBound
////    }
////    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
////        range(of: string, options: options)?.upperBound
////    }
////    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
////        var indices: [Index] = []
////        var startIndex = self.startIndex
////        while startIndex < endIndex,
////            let range = self[startIndex...]
////                .range(of: string, options: options) {
////                indices.append(range.lowerBound)
////                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
////                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
////        }
////        return indices
////    }
////    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
////        var result: [Range<Index>] = []
////        var startIndex = self.startIndex
////        while startIndex < endIndex,
////            let range = self[startIndex...]
////                .range(of: string, options: options) {
////                result.append(range)
////                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
////                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
////        }
////        return result
////    }
////}
////
////extension Collection {
////    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }
////}
