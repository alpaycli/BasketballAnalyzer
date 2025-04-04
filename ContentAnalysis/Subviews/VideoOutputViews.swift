import UIKit
import AVFoundation

// MARK: - Coordinates conversion

protocol NormalizedGeometryConverting {
   func viewRectConverted(fromNormalizedContentsRect normalizedRect: CGRect) -> CGRect
   func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint
}

// MARK: - View to display live camera feed

class CameraFeedView: UIView, NormalizedGeometryConverting {
   private var previewLayer: AVCaptureVideoPreviewLayer!
   
   override class var layerClass: AnyClass {
      return AVCaptureVideoPreviewLayer.self
   }
   
   init(frame: CGRect, session: AVCaptureSession, videoOrientation: AVCaptureVideoOrientation) {
      super.init(frame: frame)
      previewLayer = layer as? AVCaptureVideoPreviewLayer
      previewLayer.session = session
      previewLayer.videoGravity = .resizeAspect
      previewLayer.connection?.videoOrientation = videoOrientation
   }
   
   required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
   }
   
   func viewRectConverted(fromNormalizedContentsRect normalizedRect: CGRect) -> CGRect {
      return previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect)
   }
   
   func normalizedRectConverted(fromViewRect viewRect: CGRect) -> CGRect {
      previewLayer.metadataOutputRectConverted(fromLayerRect: viewRect)
   }
   
   func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint {
      return previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
   }
}

// MARK: - View for rendering video file contents

class VideoRenderView: UIView, NormalizedGeometryConverting {
   private var renderLayer: AVPlayerLayer!
   
   var player: AVPlayer? {
      get {
         return renderLayer.player
      }
      set {
         renderLayer.player = newValue
      }
   }
   
   override class var layerClass: AnyClass {
      return AVPlayerLayer.self
   }
   
   override init(frame: CGRect) {
      super.init(frame: frame)
      renderLayer = layer as? AVPlayerLayer
      renderLayer.videoGravity = .resizeAspect
   }
   
   required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
   }
   
   func viewRectConverted(fromNormalizedContentsRect normalizedRect: CGRect) -> CGRect {
      let videoRect = renderLayer.videoRect
      let origin = CGPoint(x: videoRect.origin.x + normalizedRect.origin.x * videoRect.width,
                           y: videoRect.origin.y + normalizedRect.origin.y * videoRect.height)
      let size = CGSize(width: normalizedRect.width * videoRect.width,
                        height: normalizedRect.height * videoRect.height)
      let convertedRect = CGRect(origin: origin, size: size)
      return convertedRect.integral
   }
   
   func normalizedRectConverted(fromViewRect viewRect: CGRect) -> CGRect {
      let videoRect = renderLayer.videoRect
      let origin = CGPoint(
         x: (viewRect.origin.x - videoRect.origin.x) / videoRect.width,
         y: (viewRect.origin.y - videoRect.origin.y) / videoRect.height
      )
      let size = CGSize(
         width: viewRect.width / videoRect.width,
         height: viewRect.height / videoRect.height
      )
      return CGRect(origin: origin, size: size)
   }
   
   func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint {
      let videoRect = renderLayer.videoRect
      let convertedPoint = CGPoint(x: videoRect.origin.x + normalizedPoint.x * videoRect.width,
                                   y: videoRect.origin.y + normalizedPoint.y * videoRect.height)
      return convertedPoint
   }
}
