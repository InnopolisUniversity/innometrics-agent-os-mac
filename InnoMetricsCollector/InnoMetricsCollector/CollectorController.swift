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

class CollectorController: NSObject {
    
    // Status Menu Entities
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var loginMenu: NSMenu!
    @IBOutlet weak var collectorView: NSView!
    @IBOutlet weak var metricsCollectorMenuItem: NSMenuItem!
    @IBOutlet weak var currentWorkingSessionView: CurrentWorkingSessionController!
    @IBOutlet weak var currentWorkingSessionMenuItem: NSMenuItem!
    @IBOutlet weak var logInMenuItem: NSMenuItem!
    
    // Collector Entities
    @IBOutlet weak var activeApplicationView: ActiveApplicationController!
    @IBOutlet weak var idleView: IdleController!
    @IBOutlet weak var pausePlayBtn: NSButton!
    @IBOutlet weak var pausePlayLabel: NSTextField!
    @IBOutlet weak var updateBtn: NSButtonCell!
    @IBOutlet weak var sendingIndicator: NSProgressIndicator!
    
    private var currentSession: Session!
    private var currentMetric: Metric?
    private var prevMetric: Metric?
    private var context: NSManagedObjectContext!
    private var isPaused: Bool = false
    private var transferTimer : Timer? = Timer()
    private var processTransferTimer : Timer? = Timer()
    private var measurements = Set<EnergyMeasurement>()
    private var currentIdleMetric: IdleMetric?
    private var dbProcesses: [ActiveProcess]?
    
    // User Movements Entities
    private let possibleUserMovements: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .smartMagnify, .swipe]
    private var isCollectingBrowserInfo: Bool = false
    private var isCollecting: Bool = true
    private let browsersId: [String] = ["org.chromium.Chromium", "com.google.Chrome.canary", "com.google.Chrome", "com.apple.Safari"]
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // Handles when user is not authenticated
    @IBAction func onClickToLogIn(_ sender: Any) {
        let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)
        let logInController = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("LoginViewController")) as? NSWindowController
        
        logInController!.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func startProcessTransferTimer() {
        if processTransferTimer == nil {
            processTransferTimer = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(self.transferProcesses(sender:)), userInfo: nil, repeats: true)
        }
    }
    
    func stopProcessTimer() {
        if processTransferTimer != nil {
            processTransferTimer!.invalidate()
            processTransferTimer = nil
        }
    }
    
    // TODO: decide on how frequent this should be
    func startTransferTimer() {
      if transferTimer == nil {
        transferTimer = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(self.transferAll(sender:)), userInfo: nil, repeats: true)
      }
    }
    
    func stopTransferTimer() {
        if transferTimer != nil {
            transferTimer!.invalidate()
            transferTimer = nil
        }
    }
    
    // Based on Auhenticated/Not Authenticated, display appropriate menu
    func renderMenuItems() {
        statusItem.menu = loginMenu
        if (AuthorizationUtils.isAuthorized()) {
            CollectorHelper.updateUIAuthorized(
                logInMenuItem: logInMenuItem, currentWorkingSessionMenuItem: currentWorkingSessionMenuItem, metricsCollectorMenuItem: metricsCollectorMenuItem,
                currentWorkingSessionView: currentWorkingSessionView, collectorView: collectorView
            )
            
            // set up the NSManagedObjectContext
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            context = appDelegate.managedObjectContext
            
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationSwitchTriggered), name: NSWorkspace.didActivateApplicationNotification, object: nil)
            
            // Monitor for all possible user's movements (actions)
            NSEvent.addGlobalMonitorForEvents (
                matching: self.possibleUserMovements,
                handler: { (event: NSEvent) in self.handleUserMovement() }
            )
            
            startMetricCollection()
            startProcessTransferTimer()
        } else {
            CollectorHelper.updateUIUnuthorized(
                logInMenuItem: logInMenuItem, currentWorkingSessionMenuItem: currentWorkingSessionMenuItem, metricsCollectorMenuItem: metricsCollectorMenuItem,
                currentWorkingSessionView: currentWorkingSessionView, collectorView: collectorView
            )
        }
    }
    
    @objc func defaultsChanged() {
        renderMenuItems()
        startMetricCollection()
    }
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        setUpLaunchAtLogin()
        
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        self.sendingIndicator.isHidden = true
        
        renderMenuItems()
    }
    
    func startMetricCollection() {
        if (!AuthorizationUtils.isAuthorized()) {
            return
        }
        
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
        if (!isCollecting || !AuthorizationUtils.isAuthorized()) {
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
    
    @objc func transferProcesses(sender: Timer) {
        if (!isCollecting) {
            return
        }
        
        let startChangingDbNotificationName = Notification.Name("db_start_changing")
        let endChangingDbNotificationName = Notification.Name("db_end_changing")
        DistributedNotificationCenter.default().postNotificationName(startChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
        
        // 1. get all processes
        let apps = NSWorkspace.shared.runningApplications
        
        // 2. store all processes
        for p in apps {
            if p.bundleIdentifier == nil {
                continue
            }
            
            let pid = String(p.processIdentifier)
            let comm = String((p.bundleIdentifier?.split(separator: ".").last)!)

            let newProcess = NSEntityDescription.insertNewObject(forEntityName: "ActiveProcess", into: self.context) as! ActiveProcess
        
            newProcess.pid = pid
            newProcess.process_name = comm
            newProcess.session = self.currentSession
            
            // 3: get energy metrics per process
             self.measureEnergyMetrics(process: newProcess, processID: newProcess.pid!)
            
            do {
                try self.context.save()
            } catch {
                print("error with getting individual process")
            }
        }
        
        DistributedNotificationCenter.default().postNotificationName(endChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
    }
    
    @objc func transferAll(sender: Timer) {
        if (!isCollecting) {
            return
        }
        
        stopMetricCollection()
        stopTransferTimer()
        stopProcessTimer()
        
        sendingIndicator.isHidden = false
        sendingIndicator.startAnimation(self)
        
        let metricsController: MetricsController = MetricsController()
        metricsController.fetchNewMetrics()
        
        metricsController.sendMetrics() { (response) in
            DispatchQueue.main.async {
                self.sendingIndicator.stopAnimation(self)
                self.sendingIndicator.isHidden = true
                if (response == 1) {
                    self.clearDatabase()
                } else if (response == 2) {
                    Helpers.dialogOK(question: "Error", text: "You need to relogin to the system.")
                    AuthorizationUtils.saveIsAuthorized(isAuthorized: false)
                } else {
                    Helpers.dialogOK(question: "Error", text: "Something went wrong during sending the data.")
                }
                self.startMetricCollection()
                self.currentMetric = nil
                self.prevMetric = nil
            }
        }
        
        let processesController: ProcessController = ProcessController()
        processesController.fetchNewProcesses()
        
        processesController.sendProcesses() { (response) in
            DispatchQueue.main.async {
                if (response == 1) {
                    self.clearProcessesAndMeasurements()
                    self.startTransferTimer()
                } else if (response == 2) {
                    Helpers.dialogOK(question: "Error", text: "You need to relogin to the system.")
                    AuthorizationUtils.saveIsAuthorized(isAuthorized: false)
                } else {
                    Helpers.dialogOK(question: "Error", text: "Something went wrong during sending the data.")
                }
            }
        }
    }
    
    func clearProcessesAndMeasurements() {
        let startChangingDbNotificationName = Notification.Name("db_start_changing")
        let endChangingDbNotificationName = Notification.Name("db_end_changing")
        DistributedNotificationCenter.default().postNotificationName(startChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let context = appDelegate.managedObjectContext
        do {
            let processesFetch: NSFetchRequest<ActiveProcess> = ActiveProcess.fetchRequest()
            processesFetch.includesPropertyValues = false
            let processesToDelete = try context.fetch(processesFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
            
            for metric in processesToDelete {
                context.delete(metric)
            }
            
            let measurementsFetch: NSFetchRequest<EnergyMeasurement> = EnergyMeasurement.fetchRequest()
            measurementsFetch.includesPropertyValues = false
            let measurementToDelete = try context.fetch(measurementsFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
            
            for metric in measurementToDelete {
                context.delete(metric)
            }
            
            try context.save()
        } catch {
            print (error)
            Helpers.dialogOK(question: "Error!", text: "There has been an error whilst trying to delete the data from a local database. If the issue persists, please contact the responsible persons.")
        }
        DistributedNotificationCenter.default().postNotificationName(endChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
    }
    
    func clearDatabase() {
        let startChangingDbNotificationName = Notification.Name("db_start_changing")
        let endChangingDbNotificationName = Notification.Name("db_end_changing")
        DistributedNotificationCenter.default().postNotificationName(startChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        let context = appDelegate.managedObjectContext
        do {
            
            let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
            metricsFetch.includesPropertyValues = false
            let metricsToDelete = try context.fetch(metricsFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
            
            for metric in metricsToDelete {
                context.delete(metric)
            }
            
            let idleMetricsFetch: NSFetchRequest<IdleMetric> = IdleMetric.fetchRequest()
            idleMetricsFetch.includesPropertyValues = false
            let idleMetricsToDelete = try context.fetch(idleMetricsFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
            
            for idleMetric in idleMetricsToDelete {
                context.delete(idleMetric)
            }
            
            let sessionsFetch: NSFetchRequest<Session> = Session.fetchRequest()
            sessionsFetch.includesPropertyValues = false
            let sessionsToDelete = try context.fetch(sessionsFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]

            for session in sessionsToDelete {
                context.delete(session)
            }
            
            // Save Changes
            try context.save()
            
            self.currentMetric = nil
            self.prevMetric = nil
        } catch {
            print (error)
            Helpers.dialogOK(question: "Error!", text: "There has been an error whilst trying to save the data to a local database. If the issue persists, please contact the responsible persons.")
        }
        DistributedNotificationCenter.default().postNotificationName(endChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
    }
    
    func measureEnergyMetrics(process: ActiveProcess, processID: String) {
        let usesAcPower = Helpers.shell("pmset -g ps").contains("AC Power") ? true : false
        
        let batteryPercentageMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let batteryStatusMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let ramMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let vRamMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let cpuMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        
        let d = NSDate()
        // 1. battery percentage
        let estimatedChargeRemaining = usesAcPower ? "-1" : Helpers.shell("pmset -g batt | grep -Eo \"\\d+%\" | cut -d% -f1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        batteryPercentageMeasurement.alternativeLabel = "EstimatedChargeRemaining"
        batteryPercentageMeasurement.measurementTypeId = "1"
        batteryPercentageMeasurement.value = estimatedChargeRemaining
        batteryPercentageMeasurement.process = process
        batteryPercentageMeasurement.capturedDate = NSDate()
        
        // 2. battery status (charging or not)
        batteryStatusMeasurement.alternativeLabel = "BatteryStatus"
        batteryStatusMeasurement.measurementTypeId = "2"
        batteryStatusMeasurement.value = usesAcPower ? "2" : "1"
        batteryStatusMeasurement.process = process
        batteryStatusMeasurement.capturedDate = d
        
        // 3. ram usage
        let ramUsage = Helpers.shell("ps -p \(processID) -o rss")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ramMeasurement.alternativeLabel = "RAM"
        ramMeasurement.measurementTypeId = "3"
        ramMeasurement.value = Int(ramUsage) != nil ? String(Int(ramUsage)! / 1024) : "0"
        ramMeasurement.process = process
        ramMeasurement.capturedDate = d
        
        // 4. vRAM usage
        let vRamUsage = Helpers.shell("ps -p \(processID) -xm -o vsz")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        vRamMeasurement.alternativeLabel = "vRAM"
        vRamMeasurement.measurementTypeId = "4"
        vRamMeasurement.value = Int(vRamUsage) != nil ? String(Int(vRamUsage)! / 1024) : "0"
        vRamMeasurement.process = process
        vRamMeasurement.capturedDate = d
        
        // 5. CPU usage
        let cpuUsage = Helpers.shell("ps -p \(processID) -xm -o %cpu")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cpuMeasurement.alternativeLabel = "CPU"
        cpuMeasurement.measurementTypeId = "5"
        cpuMeasurement.value = String(cpuUsage)
        cpuMeasurement.process = process
        cpuMeasurement.capturedDate = d
        
        self.measurements.insert(batteryPercentageMeasurement)
        self.measurements.insert(batteryStatusMeasurement)
        self.measurements.insert(ramMeasurement)
        self.measurements.insert(vRamMeasurement)
        self.measurements.insert(cpuMeasurement)
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
            startTransferTimer()
        } catch {
            print("An error occurred \(error)")
        }
    }
    
    func setEndTimeOfPrevMetric() {
        if currentMetric != nil {
            if (currentMetric!.timestampEnd == nil) {
                let metric = currentMetric!
                let endTime = NSDate()
                if (currentMetric != nil) {
                    metric.timestampEnd = endTime
                    metric.duration = (metric.timestampEnd?.timeIntervalSinceReferenceDate)! - (metric.timestampStart?.timeIntervalSinceReferenceDate)!
                    
                    do {
                        try context.save()
                    } catch {
                        print("An error occurred \(error)")
                    }
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
                print("error has occured")
            }
        }
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
