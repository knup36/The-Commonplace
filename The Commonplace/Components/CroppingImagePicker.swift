// CroppingImagePicker.swift
// Commonplace
//
// UIViewControllerRepresentable wrapper around UIImagePickerController
// with allowsEditing enabled — provides the native iOS crop/zoom UI
// when setting a person's profile photo.
//
// The editing UI lets the user pinch to zoom and drag to reposition,
// exactly like the iOS Contacts app photo picker.
//
// Only used for person avatars. All other photo picking uses PhotosPicker.

import SwiftUI
import UIKit

struct CroppingImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CroppingImagePicker
        
        init(_ parent: CroppingImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let picked = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            if let picked {
                parent.image = clipToCircle(picked)
            }
            parent.dismiss()
        }
        
        func clipToCircle(_ image: UIImage) -> UIImage {
            let size = image.size
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                UIBezierPath(ovalIn: rect).addClip()
                image.draw(in: rect)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
