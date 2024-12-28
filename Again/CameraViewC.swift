//
//  CameraViewControllerOutputDelegate.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 18.12.24.
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    let recordedVideoAsset: AVAsset?
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        if let recordedVideoAsset {
            vc.startReadingAsset(recordedVideoAsset)
            vc.stopCameraSession()
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if let recordedVideoAsset {
            uiViewController.startReadingAsset(recordedVideoAsset)
            uiViewController.stopCameraSession()
        }
    }
}

protocol CameraViewControllerOutputDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController,
                              didReceiveBuffer buffer: CMSampleBuffer,
                              orientation: CGImagePropertyOrientation)
}

class CameraViewController: UIViewController {
    
    // MARK: - Public Properties
    weak var outputDelegate: CameraViewControllerOutputDelegate?

    // MARK: - Private Properties
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)
    
    private var cameraFeedView: CameraFeedView!
    private var cameraFeedSession: AVCaptureSession?
    private var videoRenderView: VideoRenderView!
    private var videoFileReader: AVAssetReader?
    private let videoFileReadingQueue = DispatchQueue(label: "VideoFileReading", qos: .userInteractive)
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startObservingStateChanges()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        let backgroundQueue = DispatchQueue(label: "background_queue", qos: .background)
        backgroundQueue.async { [weak self] in
            // Stop the capture session.
            self?.cameraFeedSession?.stopRunning()
            // Stop the video reader.
            self?.videoFileReader?.cancelReading()
        }
        
    }
    
    // MARK: - Public Methods
    
    func stopCameraSession() {
        self.cameraFeedSession?.stopRunning()
    }
    
    func setupAVSession() throws {
        
        // Create a device discovery session.
        let wideAngle = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [wideAngle],
                                                                mediaType: .video,
                                                                position: .back)
        
        // Select a video device and make an input.
        guard let videoDevice = discoverySession.devices.first else {
//            throw AppError.captureSessionSetup(reason: "Couldn't find a wide angle camera device.")
            print("Error")
            return
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
//            throw AppError.captureSessionSetup(reason: "Couldn't create an input video device.")
            print("Error")
            return
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
//            throw AppError.captureSessionSetup(reason: "Couldn't add an input video device to the session.")
            print("Error")
            return
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
//            throw AppError.captureSessionSetup(reason: "Couldn't add video data output to the session.")
            print("Error")
            return
        }
        
        let captureConnection = dataOutput.connection(with: .video)
        captureConnection?.preferredVideoStabilizationMode = .standard
        captureConnection?.isEnabled = true
        session.commitConfiguration()
        cameraFeedSession = session
        
        cameraFeedView = CameraFeedView(frame: view.bounds, session: session)
        setupVideoOutputView(cameraFeedView)
        
        let backgroundQueue = DispatchQueue(label: "background_queue", qos: .background)
        backgroundQueue.async { [weak self] in
            self?.cameraFeedSession?.startRunning()
        }
        
    }
    
    func viewRectForVisionRect(_ visionRect: CGRect) -> CGRect {
        
        let flipVertical = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        let flippedRect = visionRect.applying(flipVertical)
        let viewRect: CGRect
        if cameraFeedSession != nil {
            viewRect = cameraFeedView.viewRectConverted(fromNormalizedContentsRect: flippedRect)
        } else {
            viewRect = videoRenderView.viewRectConverted(fromNormalizedContentsRect: flippedRect)
        }
        return viewRect
        
    }
    
    func setupVideoOutputView(_ videoOutputView: UIView) {
        
        videoOutputView.translatesAutoresizingMaskIntoConstraints = false
        videoOutputView.backgroundColor = .black
        view.addSubview(videoOutputView)
        NSLayoutConstraint.activate([
            videoOutputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoOutputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoOutputView.topAnchor.constraint(equalTo: view.topAnchor),
            videoOutputView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
    }
    
    func startReadingAsset(_ asset: AVAsset) {
        
        videoRenderView = VideoRenderView(frame: view.bounds)
        setupVideoOutputView(videoRenderView)
        videoFileReadingQueue.async { [weak self] in
            do {
                guard let track = asset.tracks(withMediaType: .video).first else {
//                    throw AppError.videoReadingError(reason: "No video tracks found in the asset.")
                    print("error--", "No video tracks found in the asset.")
                    return
                }
                
                let reader = try AVAssetReader(asset: asset)
                let settings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
                if reader.canAdd(output) {
                    reader.add(output)
                } else {
//                    throw AppError.videoReadingError(reason: "Couldn't add a track to the asset reader.")
                    print("error--", "Couldn't add a track to the asset reader.")
                }
                
                if !reader.startReading() {
//                    throw AppError.videoReadingError(reason: "Couldn't start the asset reader.")
                    print("error--", "Couldn't start the asset reader.")
                }
                
                self?.videoFileReader = reader
                let affineTransform = track.preferredTransform.inverted()
                let angleInDegrees = atan2(affineTransform.b, affineTransform.a) * CGFloat(180) / CGFloat.pi
                var orientation: UInt32 = 1
                switch angleInDegrees {
                case 0:
                    orientation = 1 // The recording button is on the right.
                case 180, -180:
                    orientation = 3 // The 180-degree rotation recording button is on the right.
                case 90:
                    orientation = 8 // The 90-degree clockwise rotation recording button is on the top.
                case -90:
                    orientation = 6 // The 90-degree counterclockwise rotation recording button is on the bottom.
                default:
                    orientation = 1
                }
                let bufferOrientation = CGImagePropertyOrientation(rawValue: orientation)!
                var readyForNextBuffer = true
                var lastTimestamp = CMTime(value: 0, timescale: 600)
                let ciCtx = CIContext()
                
                while reader.status == .reading {
                    autoreleasepool {
                        guard let strongSelf = self else {
                            return
                        }
                        if let sample = output.copyNextSampleBuffer(),
                            let buffer = CMSampleBufferGetImageBuffer(sample) {
                            
                            let frameTimestamp = CMSampleBufferGetPresentationTimeStamp(sample)
                            let delay = CMTimeGetSeconds(CMTimeSubtract(frameTimestamp, lastTimestamp))
                            lastTimestamp = frameTimestamp
                            Thread.sleep(forTimeInterval: delay)
                            DispatchQueue.main.async { [weak buffer] in
                                guard let strongBuffer = buffer else {
                                    return
                                }
                                let ciImage = CIImage(cvPixelBuffer: strongBuffer).transformed(by: affineTransform)
                                let cgImg = ciCtx.createCGImage(ciImage, from: ciImage.extent)
                                
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                strongSelf.videoRenderView.layer.contents = cgImg
                                CATransaction.commit()
                            }
                            if readyForNextBuffer {
                                readyForNextBuffer = false
                                strongSelf.videoDataOutputQueue.async {
                                    strongSelf.outputDelegate?.cameraViewController(strongSelf,
                                                                                    didReceiveBuffer: sample,
                                                                                    orientation: bufferOrientation)
                                    readyForNextBuffer = true
                                    
                                }
                            }
                            
                        }
                    }
                }
            } catch {
                print("Failed to read the asset. \(error.localizedDescription)")
            }
        }
        
    }
    
}

extension CameraViewController: GameStateChangeObserver {
    func gameManagerDidEnter(state: GameManager.State, from previousState: GameManager.State?) {}
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        outputDelegate?.cameraViewController(self, didReceiveBuffer: sampleBuffer, orientation: .up)
    }
    
}
