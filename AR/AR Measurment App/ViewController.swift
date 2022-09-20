//
//  ViewController.swift
//

import UIKit
import SceneKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!

    
    var finishSession = false
    let compassHeading = CompassHeading()
    let manager = CMMotionManager()
    var dots = [[String]]()
    var fileName: String { "roadTrip\(counter)" }
    var counter = 1
    var flashIsOn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
//        sceneView.showsStatistics = true
        // automatically add light to the scene
//        let debugOptions: SCNDebugOptions = [ARSCNDebugOptions.showFeaturePoints,ARSCNDebugOptions.showWorldOrigin]
//        sceneView.debugOptions = debugOptions
        sceneView.autoenablesDefaultLighting = true
        manager.deviceMotionUpdateInterval = 0.1
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        textLabel.text = "Session: \(fileName) is started"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    @objc func appMovedToBackground() {
        debugPrint("app enters background")
        createCSV()
    }
    
    @objc func appCameToForeground() {
        debugPrint("app enters foreground")
        counter += 1
        textLabel.text = "Session: \(fileName) is started"
    }
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        switch UIScreen.main.brightness {
        case 0 ... 0.5:
            debugPrint("LOW LIGHT")
            if !flashIsOn {
                toggleFlash()
                flashIsOn = true
            }
        default:
            debugPrint("ENOUGH LIGHT")
            if flashIsOn {
                toggleFlash()
                flashIsOn = false
            }
        }
        
        guard let pointFirst = frame.rawFeaturePoints?.points.first,
              let pointLast = frame.rawFeaturePoints?.points.last else { return }
        manager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            self.dots.append(["\(Date().currentTimeMillis())",
                              "\(pointFirst.x)",
                              "\(pointFirst.y)",
                              "\(pointFirst.z)",
                              "\(motion?.attitude.pitch ?? 0.0)",
                              "\(motion?.attitude.roll ?? 0.0)",
                              "\(motion?.attitude.yaw ?? 0.0)",
                              "\(self.compassHeading.degrees)"])
            self.dots.append(["\(Date().currentTimeMillis())",
                              "\(pointLast.x)",
                              "\(pointLast.y)",
                              "\(pointLast.z)",
                              "\(motion?.attitude.pitch ?? 0.0)",
                              "\(motion?.attitude.roll ?? 0.0)",
                              "\(motion?.attitude.yaw ?? 0.0)",
                              "\(self.compassHeading.degrees)"])
        }
    }
    
    var logFile: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileName = "\(fileName).csv"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func createCSV() {
        guard let logFile = logFile else {
            return
        }
        
        var csvText = "\("timestamp"),\("X"),\("Y"),\("Z"),\("pitch"),\("roll"),\("yaw"),\("Degrees")\n\n"
        for dot in dots {
            csvText = csvText.appending("\(dot[0]),\(dot[1]),\(dot[2]),\(dot[3]),\(dot[4]),\(dot[5]),\(dot[6]),\(dot[7]))\n")
        }
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(csvText.data(using: String.Encoding.utf8)!)
                fileHandle.closeFile()
            }
        } else {
            do {
                try csvText.write(to: logFile, atomically: true, encoding: String.Encoding.utf8)
                
            } catch {
                debugPrint("Failed to create file")
                debugPrint("\(error)")
            }
            debugPrint(logFile)
        }
        dots.removeAll()
    }
    

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    debugPrint(error)
                }
            }

            device.unlockForConfiguration()
        } catch {
            debugPrint(error)
        }
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}
