//
//  CollectorController.swift
//  InnoMetricsCollector
//
//  Created by Denis Zaplatnikov on 11/01/2017.
//  Modified by Dragos Strugar on 11/02/2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa
import ServiceManagement
import Sparkle

func shell(_ command: String) -> String {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String

    return output
}

class CollectorController: NSObject {
    
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var collectorView: NSView!
    var metricsCollectorMenuItem: NSMenuItem!
    
    @IBOutlet weak var currentWorkingSessionView: CurrentWorkingSessionController!
    var currentWorkingSessionMenuItem: NSMenuItem!
    
    @IBOutlet weak var activeApplicationView: ActiveApplicationController!
    @IBOutlet weak var idleView: IdleController!

    @IBOutlet weak var pausePlayBtn: NSButton!
    @IBOutlet weak var pausePlayLabel: NSTextField!
    
    @IBOutlet weak var updateBtn: NSButtonCell!
    
    private var currentSession: Session!
    private var currentMetric: Metric?
    private var prevMetric: Metric?
    private var context: NSManagedObjectContext!
    private var isPaused: Bool = false
    private var timer : Timer? = Timer()
    private var measurements = Set<Measurement>()
    
    private var currentIdleMetric: IdleMetric?
    private let possibleUserMovements: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    
    private var isCollectingBrowserInfo: Bool = false
    private var isCollecting: Bool = true
    
    private let browsersId: [String] = ["org.chromium.Chromium", "com.google.Chrome.canary", "com.google.Chrome", "com.apple.Safari"]
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func startTimer(processID: Int32, metric: Metric) {
      if timer == nil {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.measureEnergyMetrics(sender:)), userInfo: ["processID": processID, "metric": metric], repeats: true)
      }
    }

    func stopTimer() {
      if timer != nil {
        timer!.invalidate()
        timer = nil
      }
    }
    
    override func awakeFromNib() {
        setUpLaunchAtLogin()
        
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu

        metricsCollectorMenuItem = statusMenu.item(withTitle: "Collector")
        metricsCollectorMenuItem.view = collectorView
        
        currentWorkingSessionMenuItem = statusMenu.item(withTitle: "CurrentWorkingSession")
        currentWorkingSessionMenuItem.view = currentWorkingSessionView
        
        // set up the NSManagedObjectContext
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        context = appDelegate.managedObjectContext
        
        let transferAppIdentifier = "ru.innometrics.InnometricsTransfer"
        let startChangingDbNotificationName = Notification.Name("db_start_changing")
        let endChangingDbNotificationName = Notification.Name("db_end_changing")
        
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(dbChangeBegin), name: startChangingDbNotificationName, object: transferAppIdentifier)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(dbChangeEnd), name: endChangingDbNotificationName, object: transferAppIdentifier)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationSwitchTriggered), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        // Monitor for all possible user's movements (actions)
        NSEvent.addGlobalMonitorForEvents (
            matching: self.possibleUserMovements,
            handler: { (event: NSEvent) in self.handleUserMovement()}
        )
        
        startMetricCollection()
    }
    
    func startMetricCollection() {
        isCollecting = true
        handleApplicationSwitch()
    }
    
    func stopMetricCollection() {
        isCollecting = false
        isCollectingBrowserInfo = false
        setEndTimeOfPrevMetric()
    }
    
    @objc func applicationSwitchTriggered(notification: NSNotification) {
        handleApplicationSwitch()
    }
    
    func handleApplicationSwitch() {
        if (!isCollecting) {
            return
        }
        
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        if (frontmostApp == nil) {
            return
        }
        
        let foregroundPID = frontmostApp?.processIdentifier
        let foregroundWindowBundleId = frontmostApp?.bundleIdentifier
        if (foregroundWindowBundleId == "ru.innometrics.InnoMetricsCollector") {
            return
        }
        
        setEndTimeOfPrevMetric()
        activeApplicationView.update(application: frontmostApp!)
        
        createAndSaveMetric(frontmostApp: frontmostApp!, processID: foregroundPID!)
        
        // browsers
        if (foregroundWindowBundleId != nil && browsersId.contains(foregroundWindowBundleId!)) {
            // background func
            let backgroundQueue = DispatchQueue(label: "ru.innometrics.InnoMetricsCollector", qos: .background, target: nil)
            
            backgroundQueue.async {
                self.isCollectingBrowserInfo = true
                while (self.isCollectingBrowserInfo) {
                    sleep(5)
                    let fronmostApp = NSWorkspace.shared.frontmostApplication
                    if (fronmostApp == nil) {
                        self.isCollectingBrowserInfo = false
                        break
                    }
                    let foregroundWindowBundleId = fronmostApp?.bundleIdentifier
                    
                    if (!self.browsersId.contains(foregroundWindowBundleId!)) {
                        self.isCollectingBrowserInfo = false
                        break
                    }
                    
                    let foregroundWindowTabUrl = BrowserInfoUtils.activeTabURL(bundleIdentifier: foregroundWindowBundleId!)
                    
                    if (self.prevMetric != nil) {
                        if (foregroundWindowTabUrl == self.prevMetric!.tabUrl) {
                            continue
                        }
                    }
                    
                    self.setEndTimeOfPrevMetric()
                    self.createAndSaveMetric(frontmostApp: fronmostApp!, processID: foregroundPID!)
                }
            }
        } else {
            self.isCollectingBrowserInfo = false
        }
    }
    
    func handleUserMovement() {
        if (!isCollecting) {
            return
        }
        
        let idleResult = idleView.userMadeAction()
        if (!idleResult.0) {
            return
        }
        
        let idleMetric = NSEntityDescription.insertNewObject(forEntityName: "IdleMetric", into: context) as! IdleMetric

        idleMetric.appName = idleResult.2!
        idleMetric.duration = idleResult.1
        idleMetric.timestampStart = NSDate(timeIntervalSinceNow: -idleResult.1)
        idleMetric.timestampEnd = NSDate()
        idleMetric.bundleURL = currentMetric?.bundleURL
        idleMetric.bundleIdentifier = currentMetric?.bundleIdentifier
        idleMetric.tabName = currentMetric?.tabName
        idleMetric.tabUrl = currentMetric?.tabUrl
        
        createAndSaveCurrentSession()
        idleMetric.session = currentSession
        
        do {
            try self.context.save()
        } catch {
            print("Error with idle metric occurred")
        }
    }
    
    @objc func measureEnergyMetrics(sender: Timer) {
        let userInfo = sender.userInfo as? NSDictionary
        let processID = userInfo!["processID"] as? Int32
        let metric = userInfo!["metric"] as? Metric
        let usesAcPower = shell("pmset -g ps").contains("AC Power") ? true : false
        
        // create metric model
        let batteryPercentageMeasurement = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: context) as! Measurement
        let batteryStatusMeasurement = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: context) as! Measurement
        let ramMeasurement = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: context) as! Measurement
        let vRamMeasurement = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: context) as! Measurement
        let cpuMeasurement = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: context) as! Measurement
        
        
        // 1. battery percentage
        let estimatedChargeRemaining = usesAcPower ? "-1" : shell("pmset -g batt | grep -Eo \"\\d+%\" | cut -d% -f1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        batteryPercentageMeasurement.alternativeLabel = "EstimatedChargeRemaining"
        batteryPercentageMeasurement.measurementTypeId = "1"
        batteryPercentageMeasurement.value = estimatedChargeRemaining
        batteryPercentageMeasurement.metric = metric
        
        // 2. battery status (charging or not)
        batteryStatusMeasurement.alternativeLabel = "BatteryStatus"
        batteryStatusMeasurement.measurementTypeId = "2"
        batteryStatusMeasurement.value = usesAcPower ? "2" : "1"
        batteryStatusMeasurement.metric = metric
        
        // 3. ram usage
        let ramUsage = shell("ps -axm -o rss,pid | grep \(processID!)")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        ramMeasurement.alternativeLabel = "RAM"
        ramMeasurement.measurementTypeId = "3"
        ramMeasurement.value = String(ramUsage.first ?? "0")
        ramMeasurement.metric = metric
        
        // 4. vRAM usage
        let vRamUsage = shell("ps -axm -o vsz,pid | grep \(processID!)")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        vRamMeasurement.alternativeLabel = "vRAM"
        vRamMeasurement.measurementTypeId = "4"
        vRamMeasurement.value = String(vRamUsage.first ?? "0")
        vRamMeasurement.metric = metric
        
        // 5. CPU usage
        let cpuUsage = shell("ps -axm -o %cpu,pid | grep \(processID!)")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        cpuMeasurement.alternativeLabel = "CPU"
        cpuMeasurement.measurementTypeId = "5"
        cpuMeasurement.value = String(cpuUsage.first ?? "0.0")
        cpuMeasurement.metric = metric
        
        measurements.insert(batteryPercentageMeasurement)
        measurements.insert(batteryStatusMeasurement)
        measurements.insert(ramMeasurement)
        measurements.insert(vRamMeasurement)
        measurements.insert(cpuMeasurement)
    }
    
    func createAndSaveMetric(frontmostApp: NSRunningApplication, processID: Int32) {
        let foregroundWindowBundleId = frontmostApp.bundleIdentifier
        
        let metric = NSEntityDescription.insertNewObject(forEntityName: "Metric", into: context) as! Metric
        metric.bundleIdentifier = foregroundWindowBundleId
        metric.appName = frontmostApp.localizedName
        metric.bundleURL = frontmostApp.executableURL?.absoluteString
        let foregroundWindowLaunchDate =  NSDate()
        
        metric.timestampStart = foregroundWindowLaunchDate
        
        createAndSaveCurrentSession()
        metric.session = self.currentSession
        
        if (foregroundWindowBundleId != nil && self.browsersId.contains(foregroundWindowBundleId!)) {
            let foregroundWindowTabUrl = BrowserInfoUtils.activeTabURL(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabUrl != nil) {
                metric.tabUrl = foregroundWindowTabUrl!
            }
            
            let foregroundWindowTabTitle = BrowserInfoUtils.activeTabTitle(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabTitle != nil) {
                metric.tabName = foregroundWindowTabTitle!
            }
            prevMetric = currentMetric
            currentMetric = metric
        }
        
        do {
            try self.context.save()
            prevMetric = currentMetric
            currentMetric = metric
            startTimer(processID: processID, metric: metric) // execute every 1sec, get energy info
        } catch {
            print("An error occurred")
        }
    }
    
    func setEndTimeOfPrevMetric() {
        if currentMetric != nil {
            if (currentMetric!.timestampEnd == nil) {
                let metric = currentMetric!
                let endTime = NSDate()
                metric.timestampEnd = endTime
                
                metric.duration = (metric.timestampEnd?.timeIntervalSinceReferenceDate)! - (metric.timestampStart?.timeIntervalSinceReferenceDate)!
                metric.measurements = measurements
                measurements.removeAll()
                
                do {
                    try context.save()
                } catch {
                    print("An error occurred")
                }
            }
        }
    }
    
    func createAndSaveCurrentSession() {
        // save current session
        let session = NSEntityDescription.insertNewObject(forEntityName: "Session", into: context) as! Session
        
        session.operatingSystem = "macOS " + ProcessInfo().operatingSystemVersionString
        if #available(OSX 10.12, *) {
            session.userName = ProcessInfo().fullUserName
        } else {
            session.userName = NSUserName()
        }
        
        session.userLogin = NSUserName()
        session.ipAddress = SessionInfoUtils.getIPAddress()
        
        if let intfIterator = SessionInfoUtils.findEthernetInterfaces() {
            if let macAddress = SessionInfoUtils.getMACAddress(intfIterator) {
                let macAddressAsString = macAddress.map( { String(format:"%02x", $0) } )
                    .joined(separator: ":")
                session.macAddress = macAddressAsString
            } else {
                session.macAddress = ""
            }
            
            IOObjectRelease(intfIterator)
        }
        
        let isNewSession = currentSession == nil || session.operatingSystem != currentSession.operatingSystem || session.userName != currentSession.userName || session.userLogin != currentSession.userLogin || session.ipAddress != currentSession.ipAddress || session.macAddress != currentSession.macAddress
        if (isNewSession) {
            do {
                try context.save()
                currentSession = session
                self.currentWorkingSessionView.updateSession(session: currentSession)
            } catch {
                print("An error occurred")
            }
        }
//        else {
//            context.delete(session)
//            do {
//                try context.save()
//            } catch {
//                print("An error occured")
//            }
//        }
    }
    
    
    @IBAction func updateClicked(_ sender: Any) {
        let updater = SUUpdater.shared()
        updater?.feedURL = URL(string: "some mystery location")
        updater?.checkForUpdates(self)
    }
    
    @IBAction func quitCliked(_ sender: AnyObject) {
        setEndTimeOfPrevMetric()
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func pausePlayClicked(_ sender: AnyObject) {
        if (isPaused) {
            pausePlayBtn.image = #imageLiteral(resourceName: "pauseIcon")
            pausePlayLabel.stringValue = "Pause"
            isPaused = false
            startMetricCollection()
        } else {
            activeApplicationView.pauseTime()
            pausePlayBtn.image = #imageLiteral(resourceName: "playIcon")
            pausePlayLabel.stringValue = "Start"
            isPaused = true
            stopMetricCollection()
        }
    }
    
    @objc func dbChangeBegin() {
        pausePlayBtn.isEnabled = false
        
        isCollecting = false
        if (!isPaused) {
            activeApplicationView.pauseTime()
            pausePlayBtn.image = #imageLiteral(resourceName: "playIcon")
            pausePlayLabel.stringValue = "Start"
        }
    }
    
    @objc func dbChangeEnd() {
        context.reset()
        currentSession = nil
        currentMetric = nil
        prevMetric = nil
        
        pausePlayBtn.isEnabled = true
        if (!isPaused) {
            startMetricCollection()
            pausePlayBtn.image = #imageLiteral(resourceName: "pauseIcon")
            pausePlayLabel.stringValue = "Pause"
            isPaused = false
        }
    }
    
    private func setUpLaunchAtLogin() {
        let appBundleIdentifier = "ru.innometrics.InnoMetricsCollectorHelper"
        if SMLoginItemSetEnabled(appBundleIdentifier as CFString, true) {
            NSLog("Successfully add login item.")
        } else {
            NSLog("Failed to add login item.")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
