// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import AVFoundation

public protocol BarcodeScannerDelegate: AnyObject {
    func barcodeScanner(_ scanner: BarcodeScannerViewController, didCaptureCode code: String)
    func barcodeScannerDidFail(_ scanner: BarcodeScannerViewController, error: Error)
}

public class BarcodeScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    public weak var delegate: BarcodeScannerDelegate?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = getUltraWideCamera() ?? AVCaptureDevice.default(for: .video) else {
            print("Camera not available.")
            return
        }
        
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            notifyFailure(error: error)
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            notifyFailure(error: BarcodeScannerError.couldNotAddInput)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .code128]
        } else {
            notifyFailure(error: BarcodeScannerError.couldNotAddOutput)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    private func notifyFailure(error: Error) {
        delegate?.barcodeScannerDidFail(self, error: error)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.barcodeScanner(self, didCaptureCode: stringValue)
        }
        
        dismiss(animated: true)
    }
    
    public func getUltraWideCamera() -> AVCaptureDevice? {
        if let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return ultraWideCamera
        }
        return nil
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

public enum BarcodeScannerError: Error {
    case cameraNotSupported
    case couldNotAddInput
    case couldNotAddOutput
}
