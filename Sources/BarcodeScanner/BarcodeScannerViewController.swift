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
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "viewfinder")

        return iv
    }()
    
    private let torchlightButton: UIButton = {
        let btn = UIButton()
        btn.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .black.withAlphaComponent(0.65)
        return btn
    }()
    
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
        
        let eightyPercentOfWidth = view.frame.size.width * 0.8

        imageView.frame = CGRect(x: view.frame.midX - (eightyPercentOfWidth / 2), y: view.frame.midY - (eightyPercentOfWidth / 2), width:eightyPercentOfWidth, height: eightyPercentOfWidth)
        
        view.addSubview(imageView)
        
        torchlightButton.frame = CGRect(x: view.frame.midX - 25, y: view.frame.maxY - 160, width: 60, height: 60)
        torchlightButton.layer.cornerRadius = 25
        view.addSubview(torchlightButton)
        
        torchlightButton.addTarget(self, action: #selector(didTapTorchlightButton), for: .touchUpInside)
    }
    
    @objc func didTapTorchlightButton() {
        toggleFlash()
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
    
    func toggleFlash() {
        // Get the AVCaptureDevice instance representing the camera
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("Camera not found")
            return
        }
        
        // Check if the device supports flash (torch)
        if device.hasTorch {
            do {
                // Lock the device for configuration changes
                try device.lockForConfiguration()
                
                // Toggle the torch mode: if it's on, turn it off; if it's off, turn it on
                if device.torchMode == .on {
                    device.torchMode = .off  // Turn off the flash
                } else {
                    try device.setTorchModeOn(level: 1.0)  // Turn on the flash at full brightness
                }
                
                // Unlock the device after configuration
                device.unlockForConfiguration()
            } catch {
                print("Error while configuring flash: \(error)")
            }
        } else {
            print("Device does not support flash.")
        }
    }
}

public enum BarcodeScannerError: Error {
    case cameraNotSupported
    case couldNotAddInput
    case couldNotAddOutput
}
