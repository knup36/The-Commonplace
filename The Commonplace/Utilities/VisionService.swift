import Vision
import UIKit

class VisionService {
    
    static func analyze(imageData: Data) async -> (extractedText: String, tags: [String]) {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return ("", [])
        }
        
        async let textResult = recognizeText(cgImage: cgImage)
        async let tagsResult = classifyImage(cgImage: cgImage)
        
        let (text, tags) = await (textResult, tagsResult)
        return (text, tags)
    }
    
    // MARK: - Text Recognition (OCR)
    private static func recognizeText(cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Image Classification
    private static func classifyImage(cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let tags = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { $0.identifier }
                continuation.resume(returning: Array(tags))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
