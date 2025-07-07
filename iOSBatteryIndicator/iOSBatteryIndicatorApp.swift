//
//  iOSBatteryPercentageApp.swift
//  iOSBatteryPercentage
//
//  Created by BetaFruit on 7/3/25.
//

import SwiftUI
import AppKit
import LaunchAtLogin

@main
struct iOSBatteryPercentageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        /*WindowGroup {
            PreviewWrapper()
        }*/
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let popover = NSPopover()
    let settings = IconSettings()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // statusItem
        let iconSwiftUI = Icon(monitor: BatteryMonitor(), settings: settings)
        let iconView = NSHostingView(rootView: iconSwiftUI)
        iconView.frame = NSRect(x: 0, y: 0, width: 40, height: 22)
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button { // Toggle settings popover
            button.addSubview(iconView)
            button.frame = iconView.frame
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        
        self.statusItem = statusItem
        
        popover.contentSize = NSSize(width: 220, height: 120)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsPopover(settings: settings))
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

struct SettingsPopover: View {
    @ObservedObject var settings: IconSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Colour mode:", selection: $settings.colourMode) {
                Text("Default").tag(0)
                Text("Colourful").tag(1)
                Text("Reduced").tag(2)
                Text("Monochrome").tag(3)
            }
            .pickerStyle(PopUpButtonPickerStyle())
            
            Toggle("Show charging symbol at 100%", isOn: $settings.alwaysShowIcon)
            
            Divider().padding(.vertical, 6)
            
            HStack {
                LaunchAtLogin.Toggle()
                
                Spacer()
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// Save settings in userDefaults
class IconSettings: ObservableObject {
    @Published var alwaysShowIcon: Bool {
        didSet {
            UserDefaults.standard.set(alwaysShowIcon, forKey: "alwaysShowIcon")
        }
    }
    
    @Published var colourMode: Int {
        didSet {
            UserDefaults.standard.set(colourMode, forKey: "colourMode")
            // 0 = default, 1 = always colourful, 2 = no green when charging, 3 = always white (I know this could be an enum but I don't feel like it)
        }
    }
    
    init() {
        self.alwaysShowIcon = UserDefaults.standard.bool(forKey: "alwaysShowIcon")
        self.colourMode = UserDefaults.standard.integer(forKey: "colourMode")
    }
}

struct Icon: View {
    @ObservedObject var monitor: BatteryMonitor
    @ObservedObject var settings: IconSettings
    
    // You wouldn't think it would be this complicated but I have an album of about 30 screenshots of my phone's battery indicator and boy does it do a lot of stuff that you would never notice
    // For example: Who knew it was green only when charging? Who knew the shade of grey changed to make the text more readable? Who knew the charging indicator dissapears at 100% because it doesn't fit? Who knew the nub only got filled in at 100%?
    var fullyCharged: Bool { monitor.batteryPercentage >= 100 }
    var showIcon: Bool { (!fullyCharged || settings.alwaysShowIcon) && (monitor.isCharging || monitor.isPluggedIn) }
    var fillColour: Color {
        if settings.colourMode == 3 { return .white }
        if monitor.isLowPowerMode { return .yellow }
        if (monitor.isCharging || monitor.isPluggedIn) && settings.colourMode != 2 && monitor.batteryPercentage > 20 { return .init(red: 0, green: 0.65, blue: 0) }
        if monitor.batteryPercentage <= 20 { return .red }
        if settings.colourMode == 1 { return .init(red: 0, green: 0.65, blue: 0) }
        return .white
    }
    var darkText: Bool {
        if fillColour == .white || fillColour == .yellow { return true }
        else { return false }
    }
    var bgColour: Color { return darkText ? .gray : .init(white: 0.5) }
    
    var body: some View {
        ZStack {
            let clamped = min(max(monitor.batteryPercentage, 0), 100)
            
            // Battery shape
            LinearGradient(
                stops: [
                    .init(color: fillColour, location: CGFloat(clamped) / 100),
                    .init(color: bgColour, location: CGFloat(clamped) / 100)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 25, height: 13)
            .mask(
                RoundedRectangle(cornerRadius: 3)
                    .frame(width: 25, height: 13)
            )
            
            // Label
            HStack(spacing: 1) {
                Text("\(clamped)")
                
                if showIcon
                {
                    Group {
                        if monitor.isCharging {
                            Image(systemName: "bolt.fill")
                        } else if monitor.isPluggedIn {
                            Image(systemName: "powerplug.fill") // Who knew MacOS had a different icon for pluged in but not charging?
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .frame(width: 9)
                    .font(.system(size: 8))
                    .baselineOffset(-1.5)
                    .offset(x: -2)
                }
            }
            .font(.system(size: showIcon && fullyCharged ? 7.5 : 11, weight: .semibold)) // Make room for icon at 100%
            .foregroundColor(darkText ? .black : .white)
            .offset(x: showIcon ? 1 : 0)
            
            // Nub
            Circle()
                .fill(fullyCharged ? fillColour : bgColour)
                .frame(width: 5, height: 5)
                .clipShape(
                    Rectangle()
                        .offset(x: 3.5)
                )
                .offset(x: 12.5, y: 0)
        }
        .frame(width: 40, height: 22)
    }
}

/*
#Preview {
    PreviewWrapper()
}

// Mock settings because I wanted to be able to preview the look without waiting for my battery to die
class MockBatteryMonitor: BatteryMonitor {
    override init() {
        super.init()
        self.batteryPercentage = 73
        self.isPluggedIn = false
        self.isCharging = false
        self.isLowPowerMode = false
    }
}

class MockIconSettings: IconSettings {
    override init() {
        super.init()
        self.alwaysShowIcon = true
        self.colourMode = 0
    }
}

private struct PreviewWrapper: View {
    @StateObject var mockMonitor = MockBatteryMonitor()
    @StateObject var mockSettings = MockIconSettings()
    
    var body: some View {
        VStack(spacing: 12) {
            Icon(monitor: mockMonitor, settings: mockSettings)
            
            VStack(alignment: .leading) {
                Text("Battery: \(mockMonitor.batteryPercentage)%")
                Slider(value: Binding(
                    get: { Double(mockMonitor.batteryPercentage) },
                    set: { mockMonitor.batteryPercentage = Int($0) }
                ), in: 0...100)
                
                Toggle("Low Power Mode", isOn: $mockMonitor.isLowPowerMode)
                Toggle("Is Plugged In", isOn: $mockMonitor.isPluggedIn)
                Toggle("Is Charging", isOn: $mockMonitor.isCharging)
                
                Divider().padding(.vertical, 6)
                
                Toggle("Always Show Icon", isOn: $mockSettings.alwaysShowIcon)
                Picker("Colour Mode", selection: $mockSettings.colourMode) {
                    Text("Default").tag(0)
                    Text("Colourful").tag(1)
                    Text("Reduced").tag(2)
                    Text("Monochrome").tag(3)
                }
                .pickerStyle(.menu)
                
                Divider().padding(.vertical, 6)
                
                Button("Export Image") { // For making images for the repo
                    exportIcon(
                        view: BigIcon(monitor: mockMonitor, settings: mockSettings, scale: 10),
                        size: CGSize(width: 400, height: 220)
                    )
                }
            }
            .frame(width: 200)
            .padding()
        }
        .padding()
        .background(Color.black)
    }
}

// Levaing this commented out in case I change the look a bit and need to update the images
func exportIcon(view: some View, size: CGSize) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "Icon.png"
    panel.canCreateDirectories = true
    panel.title = "Export Icon Preview"
    
    panel.begin { result in
        guard result == .OK, let url = panel.url else { return }
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: url)
                print("Exported to \(url.path)")
            } catch {
                print("Failed to write image: \(error)")
            }
        } else {
            print("Failed to convert image")
        }
    }
}

// Below is an exact copy of the Icon view but with a scale variable (for the images)
struct BigIcon: View {
    @ObservedObject var monitor: BatteryMonitor
    @ObservedObject var settings: IconSettings
    var scale: CGFloat = 10
    
    var fullyCharged: Bool { monitor.batteryPercentage >= 100 }
    var showIcon: Bool { (!fullyCharged || settings.alwaysShowIcon) && (monitor.isCharging || monitor.isPluggedIn) }
    var fillColour: Color {
        if settings.colourMode == 3 { return .white }
        if monitor.isLowPowerMode { return .yellow }
        if (monitor.isCharging || monitor.isPluggedIn) && settings.colourMode != 2 && monitor.batteryPercentage > 20 { return .init(red: 0, green: 0.65, blue: 0) }
        if monitor.batteryPercentage <= 20 { return .red }
        if settings.colourMode == 1 { return .init(red: 0, green: 0.65, blue: 0) }
        return .white
    }
    var darkText: Bool {
        if fillColour == .white || fillColour == .yellow { return true }
        else { return false }
    }
    var bgColour: Color { return darkText ? .gray : .init(white: 0.5) }
    
    var body: some View {
        ZStack {
            let clamped = min(max(monitor.batteryPercentage, 0), 100)
            
            // Battery shape
            LinearGradient(
                stops: [
                    .init(color: fillColour, location: CGFloat(clamped) / 100),
                    .init(color: bgColour, location: CGFloat(clamped) / 100)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 25 * scale, height: 13 * scale)
            .mask(
                RoundedRectangle(cornerRadius: 3 * scale)
                    .frame(width: 25 * scale, height: 13 * scale)
            )
            
            // Label
            HStack(spacing: 1 * scale) {
                Text("\(clamped)")
                
                if showIcon
                {
                    Group {
                        if monitor.isCharging {
                            Image(systemName: "bolt.fill")
                        } else if monitor.isPluggedIn {
                            Image(systemName: "powerplug.fill")
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .frame(width: 9 * scale)
                    .font(.system(size: 8 * scale))
                    .baselineOffset(-1.5 * scale)
                    .offset(x: -2 * scale)
                }
            }
            .font(.system(size: showIcon && fullyCharged ? 7.5 * scale : 11 * scale, weight: .semibold)) // Make room for icon at 100%
            .foregroundColor(darkText ? .black : .white)
            .offset(x: showIcon ? 1 * scale : 0)
            
            // Nub
            Circle()
                .fill(fullyCharged ? fillColour : bgColour)
                .frame(width: 5 * scale, height: 5 * scale)
                .clipShape(
                    Rectangle()
                        .offset(x: 3.5 * scale)
                )
                .offset(x: 12.5 * scale, y: 0)
        }
        .frame(width: 40 * scale, height: 22 * scale)
    }
}*/
