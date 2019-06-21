//
//  ViewController.swift
//  AudioLock
//
//  Created by Eric Dolecki on 6/21/19.
//  Copyright © 2019 Eric Dolecki. All rights reserved.
//

import UIKit
import BoseWearable
import Foundation
import AVFoundation

class ViewController: UIViewController, WearableDeviceSessionDelegate, SensorDispatchHandler {

    var session: WearableDeviceSession!
    private let sensorDispatch = SensorDispatch(queue: .main)
    private var token: ListenerToken?
    var device: WearableDevice? { return session.device }
    
    // Callibration.
    var currentGameRotation: Quaternion?
    var calibrateRotation = Quaternion(ix: 0, iy: 0, iz: 0, r: 1)
    
    // Audio playback.
    var crowdPlayer: AVAudioPlayer?
    // We only care about initial sensor data so we can start single music player.
    var gotSensorData = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startSearch()
    }

    func startSearch(){
        BoseWearable.shared.startDeviceSearch(mode: .alwaysShowUI) { result in
            switch result {
                
            case .success(let session):
                
                self.session = session
                self.session.delegate = self
                
                // When actually opened, we set up sensors and gestures.
                
                self.session.open()
                self.sensorDispatch.handler = self
                
            case .failure(let error):
                print("failure \(error.localizedDescription)")
                
            case .cancelled:
                print("cancelled.")
            }
        }
    }
    
    private func configureGestures()
    {
        session.device?.configureGestures { config in
            config.disableAll()
            config.set(gesture: .headNod, enabled: true)
            config.set(gesture: .headShake, enabled: true)
            config.set(gesture: .doubleTap, enabled: true)
            config.set(gesture: .singleTap, enabled: true)
        }
    }
    
    func listenForWearableDeviceEvents() {
        token = session.device?.addEventListener(queue: .main) { [weak self] event in
            self?.wearableDeviceEvent(event)
        }
    }
    
    private func listenForSensors() {
        session.device?.configureSensors { config in
            config.disableAll()
            config.enable(sensor: .gameRotation, at: ._20ms)
        }
    }
    
    private func wearableDeviceEvent(_ event: WearableDeviceEvent)
    {
        switch event {
        case .didFailToWriteSensorConfiguration(let error):
            print("Couldn't set configuration error: \(error)")
            
        case .didSuspendWearableSensorService:
            print("sensor suspended.")
            
        case .didResumeWearableSensorService:
            print("sensor resumed.")
            
        case .didUpdateSensorConfiguration(let config):
            print("Updated sensor configuration. Enabled:\(config.enabledSensors)")
            
        case .didFailToWriteGestureConfiguration(let error):
            print("Failed to write gesture config. \(error.localizedDescription)")
        
        // After getting initial sensor data, play the music. Only first time we get the data
        // so that we don't keep playing music on top of itself.
        case .didReceiveSensorData:
            if gotSensorData == false {
                playCrowd()
                gotSensorData = true
            }
            
        default:
            break
        }
    }
    
    func sessionDidOpen(_ session: WearableDeviceSession)
    {
        print("Session did open.")
        //Now that we have a session, let's set up the device to get events.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            self.configureGestures()
        })
        self.listenForSensors()
        self.listenForWearableDeviceEvents()
    }
    
    func session(_ session: WearableDeviceSession, didFailToOpenWithError error: Error?) {
        print("Session open error: \(error!)")
    }
    
    func session(_ session: WearableDeviceSession, didCloseWithError error: Error?) {
        if error != nil {
            print("Session closed error: \(error!)")
            if (error?.localizedDescription.contains("disconnected from us"))! {
                //if error?.localizedDescription == "The specified device has disconnected from us." {
                let alert = UIAlertController(title: "Disconnected", message: "Your Bose AR device has disconnected.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
        }
    }
    
    func receivedGesture(type: GestureType, timestamp: SensorTimestamp)
    {
        switch type {
        case .doubleTap:
            print("double-tap.")
        case .headNod:
            print("head nod.")
        case .headShake:
            print("head shake.")
        case .singleTap:
            print("single tap.")
        }
    }
    
    // Main input for this application right here.
    func receivedGameRotation(quaternion: Quaternion, timestamp: SensorTimestamp)
    {
        currentGameRotation = Quaternion(ix: 1, iy: 0, iz: 0, r: 0) * quaternion
        let calibratedRot = calibrateRotation * currentGameRotation!
        let yaw = calibratedRot.yaw
        
        // Inverse, reporting - to the right. Yaw can be used directly for panning.
        
        // Only works when looking to the right towards the pan position.
        if yaw < 0 {
            crowdPlayer?.pan = 1 + Float(yaw)
        } else {
            crowdPlayer?.pan = 1
            // TODO: Should we adjust volume as you look left but pan is already at 1?
        }
        //print(format(radians: -yaw), -yaw)
    }
    
    @IBAction func callibrateSensor(_ sender: Any) {
        if let quat = currentGameRotation?.inverse {
            calibrateRotation = quat
            print("GameRotation now callibrated.")
        }
    }
    
    func playCrowd()
    {
        let path = Bundle.main.path(forResource: "crowd.mp3", ofType: nil)
        let url = URL(fileURLWithPath: path!)
        do {
            crowdPlayer = try AVAudioPlayer(contentsOf: url)
            crowdPlayer?.numberOfLoops = -1
            crowdPlayer?.volume = 1.0
            crowdPlayer?.pan = 1.0 //All the way to the right.
            crowdPlayer?.prepareToPlay()
            crowdPlayer?.play()
        } catch {
            print("Error playing music.")
        }
    }
    
    //MARK: - Utilities.
    
    /// Utility to format radians as degrees with two decimal places and a degree symbol.
    func format(radians: Double) -> String {
        let degrees = radians * 180 / Double.pi
        return String(format: "%.02f°", degrees)
    }
    
    /// Utility to format radians as degrees with two decimal places and a degree symbol.
    func format(radians: Float) -> String {
        let degrees = radians * 180 / Float.pi
        return String(format: "%.02f°", degrees)
    }
    
    /// Utility to format degrees with two decimal places and a degree symbol.
    func format(degrees: Double) -> String {
        return String(format: "%.02f°", degrees)
    }
    
    /// Utility to format a double with four decimal places.
    func format(decimal: Double) -> String {
        return String(format: "%.04f", decimal)
    }
    
    /// Converts the byte sequence of this Data object into a hexadecimal representation (two lowercase characters per byte).
    func format(data: Data?) -> String? {
        return data?.map({ String(format: "%02hhX", $0) }).joined()
    }

}

