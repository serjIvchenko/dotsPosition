//
//  ViewController.swift
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    @IBAction func startStopAction(_ sender: Any) {
        if startSession {
            startStopButton.setTitle("Start", for: .normal)
            startSession = false
            createCSV()
        } else {
            startStopButton.setTitle("Stop", for: .normal)
            startSession = true
        }
    }
    
    var startSession = false
    let compassHeading = CompassHeading()
    var dots = [[String]]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if startSession {
            guard let pointFirst = frame.rawFeaturePoints?.points.first,
                  let pointLast = frame.rawFeaturePoints?.points.last else { return }
            dots.append(["\(pointFirst.x)", "\(pointFirst.y)", "\(pointFirst.z)", "\(compassHeading.degrees)"])
            dots.append(["\(pointLast.x)", "\(pointLast.y)", "\(pointLast.z)", "\(compassHeading.degrees)"])
        }
    }
    
    var logFile: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileName = "pointData.csv"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func createCSV() {
        guard let logFile = logFile else {
            return
        }
        var csvText = "\("pointID"),\("X"),\("Y"),\("Z"),\("Degrees")\n\n"
        for dot in dots {
            csvText = csvText.appending("\(String(describing: dots.firstIndex(of: dot)!)) ,\(dot[0]),\(dot[1]),\(dot[2]),\(dot[3])\n")
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
                print("Failed to create file")
                print("\(error)")
            }
            print(logFile)
        }
        dots.removeAll()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
}
