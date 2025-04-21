//
//  ContentView.swift
//  Assignment1_v2
//
//  Created by Matthew Wallingford on 4/19/25.
//

import SwiftUI
import CoreMotion
import UIKit
import Foundation
import Combine
import Charts

struct ViewControllerWrapper: UIViewControllerRepresentable {
    var chartModel: OrientationChartModel

    func makeUIViewController(context: Context) -> ViewController {
        let vc = ViewController()
        vc.chartModel = chartModel
        return vc
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}
struct ContentView: View {
    @StateObject var chartModel = OrientationChartModel()

    var body: some View {
        VStack {
            ViewControllerWrapper(chartModel: chartModel)
                .edgesIgnoringSafeArea(.all)
            LiveComplementaryChartView(chartModel: chartModel)
        }
    }
}

class ViewController: UIViewController {
    let motion = CMMotionManager()
    let updateInterval = 1/10.0
    var timer: Timer?
    private let accelLabel = UILabel()
    private let gyroLabel = UILabel()
    var csvText = "timestamp,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z\n"
    let saveButton = UIButton(type: .system)
    var chartModel: OrientationChartModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //setupLabel()
        startAccelAndGyro()
        //fetchAcceleratorData()
        //fetchGyroData()
        //setupButton()
        startRecording()
        
    }
    
    func setupLabel() {
        accelLabel.frame = CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 100)
        accelLabel.numberOfLines = 0
        accelLabel.textAlignment = .center
        accelLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        accelLabel.text = "waiting for data..."
        view.addSubview(accelLabel)
        
        gyroLabel.frame = CGRect(x: 20, y: 200, width: view.frame.width - 40, height: 100)
        gyroLabel.numberOfLines = 0
        gyroLabel.textAlignment = .center
        gyroLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        gyroLabel.text = "waiting for data..."
        view.addSubview(gyroLabel)
    }
    
    func setupButton() {
        saveButton.setTitle("Save CSV", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        saveButton.frame = CGRect(x: 60, y: 300, width: view.frame.width - 120, height: 50)
        saveButton.layer.cornerRadius = 10
        saveButton.backgroundColor = UIColor.systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.addTarget(self, action: #selector(stopAndSaveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
    }
    
    func startAccelAndGyro() {
        if (self.motion.isAccelerometerAvailable && self.motion.isGyroAvailable){
            self.motion.startAccelerometerUpdates()
            self.motion.startGyroUpdates()
            self.motion.accelerometerUpdateInterval = updateInterval
            self.motion.gyroUpdateInterval = updateInterval
        }
    }
    
    func fetchAcceleratorData(){
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let data = self?.motion.accelerometerData {
                let x = data.acceleration.x
                let y = data.acceleration.y
                let z = data.acceleration.z
                self?.accelLabel.text = String(format: "IMU\nx: %.3f\ny: %.3f\nz: %.3f", x, y, z)
            }
        }
    }
    
    func fetchGyroData(){
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let data = self?.motion.gyroData {
                let x = data.rotationRate.x
                let y = data.rotationRate.y
                let z = data.rotationRate.z
                
                self?.gyroLabel.text = String(format: "gyro\nx: %.3f\ny: %.3f\nz: %.3f", x, y, z)
            }
        }
    }
    func startRecording() {
        var gyro_x = 0.0
        var gyro_y = 0.0
        var gyro_z = 0.0
        var complementary_x = Double()
        var complementary_y = Double()
        var complementary_z = Double()
        let alpha = 0.0
        //initialize tilt
        if let accelData = motion.accelerometerData {
                let a_x = accelData.acceleration.x
                let a_y = accelData.acceleration.y
                let a_z = accelData.acceleration.z
                let accel_roll = atan2(a_y, a_z)
                let accel_pitch = atan2(-a_x, sqrt(a_y * a_y + a_z * a_z))
                complementary_x = accel_roll
                complementary_y = accel_pitch
                complementary_z = 0.0
            }

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let accelData = self.motion.accelerometerData,
                  let gyroData = self.motion.gyroData else { return }
            
            let timestamp = Date().timeIntervalSince1970
            let a_x = accelData.acceleration.x
            let a_y = accelData.acceleration.y
            let a_z = accelData.acceleration.z
            let v_x = gyroData.rotationRate.x
            let v_y = gyroData.rotationRate.y
            let v_z = gyroData.rotationRate.z
            
            gyro_x = gyro_x + v_x * updateInterval
            gyro_y = gyro_y + v_y * updateInterval
            gyro_z = gyro_z + v_z * updateInterval
            
            let accel_roll = atan2(a_y, a_z)
            let accel_pitch = -1*atan2(-a_x, sqrt(a_y * a_y + a_z * a_z))
            
            complementary_x = alpha * (complementary_x + v_x * updateInterval) + (1-alpha)*accel_roll
            complementary_y = alpha * (complementary_y + v_y * updateInterval) + (1-alpha)*accel_pitch
            complementary_z = (complementary_z + v_z * updateInterval)

            DispatchQueue.main.async {
                self.chartModel.append(roll: complementary_x*180 / .pi,
                                       pitch: complementary_y*180 / .pi,
                                       yaw: complementary_z*180 / .pi)
            }
            let row = String(format: "%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f\n",
                             timestamp,
                             accelData.acceleration.x,
                             accelData.acceleration.y,
                             accelData.acceleration.z,
                             gyroData.rotationRate.x,
                             gyroData.rotationRate.y,
                             gyroData.rotationRate.z,
                             accel_roll,
                             accel_pitch
            )
            self.csvText.append(row)
        }
    }
    @objc func stopAndSaveTapped(){
        saveCSVFile()
    }
    
    func saveCSVFile() {
        let fileName = "imu_data.csv"
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = path.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Saved CSV to:", fileURL)
            let rowCount = csvText.components(separatedBy: "\n").filter { !$0.isEmpty }.count - 1  // subtract header
            print("Number of rows recorded:", rowCount)
            
        } catch {
            print("Failed to write CSV:", error)
        }
    }
}
class OrientationChartModel: ObservableObject {
    @Published var data: [OrientationPoint] = []
    private var timeCounter = 0.0
    let updateInterval = 1.0 / 50.0

    func append(roll: Double, pitch: Double, yaw: Double) {
        data.append(OrientationPoint(time: timeCounter, roll: roll, pitch: pitch, yaw: yaw))
        timeCounter += updateInterval

        // Optional: keep only the most recent 500 points
        if data.count > 1000 {
            data.removeFirst()
        }
    }
}

struct LiveComplementaryChartView: View {
    @ObservedObject var chartModel: OrientationChartModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Complementary Filter Output")
                .font(.title)
                .padding(.top)
            Chart(chartModel.data) {
                LineMark(x: .value("Time", $0.time), y: .value("Roll", $0.roll))
            }
            .frame(height: 250)
            .chartXAxisLabel("Time (s)")
            .chartYAxisLabel("Roll (°)")
            .chartYScale(domain: -180...180)
            .padding(.horizontal)

            Chart(chartModel.data) {
                LineMark(x: .value("Time", $0.time), y: .value("Pitch", $0.pitch))
            }
            .frame(height: 250)
            .chartXAxisLabel("Time (s)")
            .chartYAxisLabel("Pitch (°)")
            .chartYScale(domain: -180...180)
            .padding(.horizontal)

            Chart(chartModel.data) {
                LineMark(x: .value("Time", $0.time), y: .value("Yaw", $0.yaw))
            }
            .frame(height: 250)
            .chartXAxisLabel("Time (s)")
            .chartYAxisLabel("Yaw (°)")
            .chartYScale(domain: -180...180)
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct OrientationPoint: Identifiable {
    let id = UUID()
    let time: Double
    let roll: Double
    let pitch: Double
    let yaw: Double
}


#Preview {
    ContentView()
}
