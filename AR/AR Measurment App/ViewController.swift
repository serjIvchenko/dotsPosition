//
//  ViewController.swift
//

import UIKit
import SceneKit
import ARKit
import CoreMotion
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!

    
    var finishSession = false
    let compassHeading = CompassHeading()
//    let manager = CMMotionManager()
    var dots = [[String]]()
    var fileName: String { "roadTrip\(counter)" }
    var counter = 1
    var flashIsOn = false
    
    // MotionManager
    let motionManager = CMMotionManager()
    
    // CLLocationManager
    var locationManager: CLLocationManager? = nil
    
    // Event handler
    var updateMotionManagerHandler: CMMagnetometerHandler? = nil
    var updateDeviceMotionHandler: CMDeviceMotionHandler? = nil
    
    // Timer for getting heading data
    var headingTimer: Timer?
    
    // Magnetometer update interval
    let updateInterval = 0.1
    
    var magneticFieldX = Double()
    var magneticFieldY = Double()
    var magneticFieldZ = Double()
    var calibratedMagneticFieldX = Double()
    var calibratedMagneticFieldY = Double()
    var calibratedMagneticFieldZ = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        // automatically add light to the scene
        sceneView.autoenablesDefaultLighting = true
        motionManager.deviceMotionUpdateInterval = 0.1
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        textLabel.text = "Session: \(fileName) is started"
        
        
        locationManager = CLLocationManager()
        locationManager?.headingFilter = kCLHeadingFilterNone
                
        if motionManager.isMagnetometerAvailable {
            // Set data acquisition interval
            motionManager.magnetometerUpdateInterval = updateInterval
            motionManager.deviceMotionUpdateInterval = updateInterval
            motionManager.showsDeviceMovementDisplay = true
            
            // Getting data from CMMotionManager
            
            updateMotionManagerHandler = {(magnetoData: CMMagnetometerData?, error:Error?) -> Void in
                self.magneticFieldX = self.outputMagnetDataByMotionManager(magnet: magnetoData!.magneticField).x
                self.magneticFieldY = self.outputMagnetDataByMotionManager(magnet: magnetoData!.magneticField).y
                self.magneticFieldZ = self.outputMagnetDataByMotionManager(magnet: magnetoData!.magneticField).z
            }
            
            // Getting data from CMDeviceMotion
            updateDeviceMotionHandler = {(deviceMotion: CMDeviceMotion?, error: Error?) -> Void in
                self.calibratedMagneticFieldX = self.outputMagnetDataByDeviceMotion(magnet: self.motionManager.deviceMotion!.magneticField).field.x
                self.calibratedMagneticFieldY = self.outputMagnetDataByDeviceMotion(magnet: self.motionManager.deviceMotion!.magneticField).field.y
                self.calibratedMagneticFieldZ = self.outputMagnetDataByDeviceMotion(magnet: self.motionManager.deviceMotion!.magneticField).field.z
            }
        }
        
        startMagnetometer()
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
    
    func outputMagnetDataByMotionManager(magnet: CMMagneticField) -> CMMagneticField {
        // Magnetometer
        return magnet
    }
    
    // Show calibrated magneetometer data
    func outputMagnetDataByDeviceMotion(magnet: CMCalibratedMagneticField) -> CMCalibratedMagneticField  {
        // Magnetometer
        return magnet
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        switch UIScreen.main.brightness {
        case 0 ... 0.6:
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
        motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            self.dots.append(["\(Date().currentTimeMillis())",
                              "\(pointFirst.x)",
                              "\(pointFirst.y)",
                              "\(pointFirst.z)",
                              "\(motion?.attitude.pitch ?? 0.0)",
                              "\(motion?.attitude.roll ?? 0.0)",
                              "\(motion?.attitude.yaw ?? 0.0)",
                              "\(self.compassHeading.degrees)",
                              "\(self.magneticFieldX)",
                              "\(self.magneticFieldY)",
                              "\(self.magneticFieldZ)",
                              "\(self.calibratedMagneticFieldX)",
                              "\(self.calibratedMagneticFieldY)",
                              "\(self.calibratedMagneticFieldZ)"])
            
            self.dots.append(["\(Date().currentTimeMillis())",
                              "\(pointLast.x)",
                              "\(pointLast.y)",
                              "\(pointLast.z)",
                              "\(motion?.attitude.pitch ?? 0.0)",
                              "\(motion?.attitude.roll ?? 0.0)",
                              "\(motion?.attitude.yaw ?? 0.0)",
                              "\(self.compassHeading.degrees)",
                              "\(self.magneticFieldX)",
                              "\(self.magneticFieldY)",
                              "\(self.magneticFieldZ)",
                              "\(self.calibratedMagneticFieldX)",
                              "\(self.calibratedMagneticFieldY)",
                              "\(self.calibratedMagneticFieldZ)"])
        }
    }
    
    var logFile: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileName = "\(fileName).csv"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func startMagnetometer() {
        guard let updateMotionManagerHandler = updateMotionManagerHandler else { return }
        motionManager.startMagnetometerUpdates(to: OperationQueue.main, withHandler: updateMotionManagerHandler)
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryCorrectedZVertical, to: OperationQueue.main, withHandler: updateDeviceMotionHandler!)
        
        locationManager?.startUpdatingHeading()
        headingTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(ViewController.headingTimerUpdate), userInfo: nil, repeats: true)
    }
    
    func createCSV() {
        guard let logFile = logFile else {
            return
        }
        
        var csvText = "\("timestamp"),\("X"),\("Y"),\("Z"),\("pitch"),\("roll"),\("yaw"),\("Degrees"),\("magneticFieldX"),\("magneticFieldY"),\("magneticFieldZ"),\("calibratedMagneticFieldX"),\("calibratedMagneticFieldY"),\("calibratedMagneticFieldZ")\n\n"
        for dot in dots {
            csvText = csvText.appending("\(dot[0]),\(dot[1]),\(dot[2]),\(dot[3]),\(dot[4]),\(dot[5]),\(dot[6]),\(dot[7]),\(dot[8]),\(dot[9]),\(dot[10]),\(dot[11]),\(dot[12]),\(dot[13])\n")
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        // Run the view's session
        sceneView.session.run(configuration)
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
    
    @objc func headingTimerUpdate() {
        let newHeading = self.locationManager?.heading
        let x = newHeading?.x ?? 0.0
        let y = newHeading?.y ?? 0.0
        let z = newHeading?.z ?? 0.0
        
//        headingX.text = String(format: "%10f", x)
//        headingY.text = String(format: "%10f", y)
//        headingZ.text = String(format: "%10f", z)
//        vector3.text = "vector3"
        let total = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2))
//        headingTotal.text = String(format: "%10f", total)
        
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}
