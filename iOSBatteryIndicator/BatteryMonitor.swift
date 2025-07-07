//
//  BatteryMonitor.swift
//  iOSBatteryPercentage
//
//  Created by BetaFruit on 7/5/25.
//

import Foundation
import IOKit.ps
import Combine

class BatteryMonitor: ObservableObject {
    @Published var batteryPercentage: Int = 100
    @Published var isPluggedIn: Bool = false
    @Published var isCharging: Bool = false
    @Published var isLowPowerMode: Bool = false
    
    private var powerSourceRunLoopSource: CFRunLoopSource?
    
    init() {
        update()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    @objc private func lowPowerModeChanged() {
        DispatchQueue.main.async {
            self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    
    // Refresh everything
    func update() {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
           let info = IOPSGetPowerSourceDescription(snapshot, sources[0])?.takeUnretainedValue() as? [String: Any] {
            
            // Percentage
            if let current = info[kIOPSCurrentCapacityKey as String] as? Int,
               let max = info[kIOPSMaxCapacityKey as String] as? Int {
                batteryPercentage = Int(Double(current) / Double(max) * 100)
            }
            
            // Charging state
            if let isChargingVal = info[kIOPSIsChargingKey as String] as? Bool {
                isCharging = isChargingVal
            }
            
            // Power state
            if let sourceState = info[kIOPSPowerSourceStateKey as String] as? String {
                isPluggedIn = sourceState == kIOPSACPowerValue
            }
        }
        
        // Delay because it updates too early otherwise - this might be useless because I added an observer but whatever
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
    
    private func startMonitoring() {
        // Callback to update
        let callback: IOPowerSourceCallbackType = { context in
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.update()
            }
        }
        
        // Trigger callback when thingies change
        powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue()
        
        if let source = powerSourceRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        
        // Observe low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    private func stopMonitoring() {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            powerSourceRunLoopSource = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
}
