//
//  ViewController.swift
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    @IBAction func startStopAction(_ sender: Any) {
        if startSession {
            createCSV()
            startStopButton.setTitle("Start", for: .normal)
            sceneView.session.pause()
            sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
            if let configuration = sceneView.session.configuration {
                sceneView.session.run(configuration,
                                      options: .resetTracking)
            }
            startSession = false
        } else {
            startStopButton.setTitle("Stop", for: .normal)
            startSession = true
        }
    }
    
    var startSession = false
    var dotNodes = [SCNNode]()
    var textNode = SCNNode()
    let compassHeading = CompassHeading()
    var dots = [[String]]()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if startSession {
            if let location = touches.first?.location(in: sceneView) {
                let locationsInSpace = sceneView.hitTest(location, types: .featurePoint)
                
                if let locationInSpace = locationsInSpace.first {
                    addDot(at: locationInSpace)
                }
            }
        }
    }
    
    func addDot(at location: ARHitTestResult) {
        
        dots.append(["\(textNode.position.x)", "\(textNode.position.y)", "\(textNode.position.z)" ,"\(compassHeading.degrees)"])
        let dotGeometry = SCNSphere(radius: 0.005)
        let dotNode = SCNNode()
        
        let dotMaterial = SCNMaterial()
        dotMaterial.diffuse.contents = UIColor.red
        
        dotGeometry.materials = [dotMaterial]
        dotNode.position = SCNVector3(
            location.worldTransform.columns.3.x,
            location.worldTransform.columns.3.y,
            location.worldTransform.columns.3.z
        )
        
        dotNode.geometry = dotGeometry
        sceneView.scene.rootNode.addChildNode(dotNode)
        dotNodes.append(dotNode)
        
        if dotNodes.count >= 2 {
            calculate()
        }
    }
    
    func calculate() {
        let start = dotNodes[0]
        let end = dotNodes.last!
        
        // mathematical formula for calculating distance
        let a = start.position.x - end.position.x
        let b = start.position.y - end.position.y
        let c = start.position.z - end.position.z
        var distance = sqrt(pow(a, 2) + pow(b, 2) + pow(c, 2))
        
        // rounding distance
        distance *= 10000
        distance = round(distance)
        distance /= 10000
        
        updateText(text: String(distance), at: end.position)
    }
    
    func updateText(text: String, at position: SCNVector3) {
        textNode.removeFromParentNode()
        let text = SCNText(string: "\(dotNodes.count)", extrusionDepth: 1.0)
        text.firstMaterial?.diffuse.contents = UIColor.blue
        textNode = SCNNode(geometry: text)
        textNode.position = position
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        sceneView.scene.rootNode.addChildNode(textNode)
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
        dotNodes.removeAll()
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
