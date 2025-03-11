//
//  SwiftUIView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 13.02.25.
//

import ReplayKit
import SwiftUI

struct RPPreviewView: UIViewControllerRepresentable {
    let previewVC: RPPreviewViewController
    init(previewVC: RPPreviewViewController) {
        self.previewVC = previewVC
    }
    
    
    func makeUIViewController(context: Context) -> RPPreviewViewController {
        previewVC.previewControllerDelegate = context.coordinator
        
        return previewVC
    }
    
    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true)
        }
    }
}
