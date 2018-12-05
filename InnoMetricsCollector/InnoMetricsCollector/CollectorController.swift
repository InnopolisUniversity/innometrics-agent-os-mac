//
//  CollectorController.swift
//  InnoMetricsCollector
//
//  Created by Denis Zaplatnikov on 11/01/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Cocoa
import ServiceManagement

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
    
    private var currentSession: Session!
    private var currentMetric: Metric?
    private var prevMetric: Metric?
    private var context: NSManagedObjectContext!
    private var isPaused: Bool = false
    
    private var currentIdleMetric: IdleMetric?
    private let possibleUserMovements: NSEventMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    
    private var isCollectingBrowserInfo: Bool = false
    private var isCollecting: Bool = true
    
    private let browsersId: [String] = ["org.chromium.Chromium", "com.google.Chrome.canary", "com.google.Chrome", "com.apple.Safari"]
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
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
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        context = appDelegate.managedObjectContext
        
        let transferAppIdentifier = "com.denzap.InnometricsTransfer"
        let startChangingDbNotificationName = Notification.Name("db_start_changing")
        let endChangingDbNotificationName = Notification.Name("db_end_changing")
        
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(dbChangeBegin), name: startChangingDbNotificationName, object: transferAppIdentifier)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(dbChangeEnd), name: endChangingDbNotificationName, object: transferAppIdentifier)
        
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(applicationSwitchTriggered), name: NSNotification.Name.NSWorkspaceDidActivateApplication, object: nil)
        
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
    
    func applicationSwitchTriggered(notification: NSNotification) {
        handleApplicationSwitch()
    }
    
    func handleApplicationSwitch() {
        if (!isCollecting) {
            return
        }
        
        let frontmostApp = NSWorkspace.shared().frontmostApplication
        if (frontmostApp == nil) {
            return
        }
        
        let foregroundWindowBundleId = frontmostApp?.bundleIdentifier
        if (foregroundWindowBundleId == "com.denzap.InnoMetricsCollector") {
            return
        }
        
        setEndTimeOfPrevMetric()
        activeApplicationView.update(application: frontmostApp!)
        
        createAndSaveMetric(frontmostApp: frontmostApp!)
        
        if (browsersId.contains(foregroundWindowBundleId!)) {
            
            // background func
            let backgroundQueue = DispatchQueue(label: "com.app.InnoMetricsCollector", qos: .background, target: nil)
            
            backgroundQueue.async {
                self.isCollectingBrowserInfo = true
                while (self.isCollectingBrowserInfo) {
                    sleep(5)
                    let fronmostApp = NSWorkspace.shared().frontmostApplication
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
                    self.createAndSaveMetric(frontmostApp: fronmostApp!)
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
    
    
    func createAndSaveMetric(frontmostApp: NSRunningApplication) {
        let foregroundWindowBundleId = frontmostApp.bundleIdentifier
        
        let metric = NSEntityDescription.insertNewObject(forEntityName: "Metric", into: context) as! Metric
        metric.bundleIdentifier = foregroundWindowBundleId
        metric.appName = frontmostApp.localizedName
        metric.bundleURL = frontmostApp.executableURL?.absoluteString
        let foregroundWindowLaunchDate =  NSDate()
        
        metric.timestampStart = foregroundWindowLaunchDate
        
        createAndSaveCurrentSession()
        metric.session = self.currentSession
        
        if (self.browsersId.contains(foregroundWindowBundleId!)) {
            let foregroundWindowTabUrl = BrowserInfoUtils.activeTabURL(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabUrl != nil) {
                metric.tabUrl = foregroundWindowTabUrl!
            }
            
            let foregroundWindowTabTitle = BrowserInfoUtils.activeTabTitle(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabTitle != nil) {
                metric.tabName = foregroundWindowTabTitle!
            }
            prevMetric = currentMetric
            currentMetric = metric//self.metrics.insert(metric, at: 0)
        }
        
        do {
            try self.context.save()
            prevMetric = currentMetric
            currentMetric = metric
            //self.metrics.insert(metric, at: 0)
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
    
    @IBAction func quitCliked(_ sender: AnyObject) {
        setEndTimeOfPrevMetric()
        NSApplication.shared().terminate(self)
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
    
    func dbChangeBegin() {
        pausePlayBtn.isEnabled = false
        
        isCollecting = false
        if (!isPaused) {
            activeApplicationView.pauseTime()
            pausePlayBtn.image = #imageLiteral(resourceName: "playIcon")
            pausePlayLabel.stringValue = "Start"
        }
    }
    
    func dbChangeEnd() {
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
        let appBundleIdentifier = "com.denzap.InnoMetricsCollectorHelper"
        if SMLoginItemSetEnabled(appBundleIdentifier as CFString, true) {
            //if autoLaunch {
                NSLog("Successfully add login item.")
            //} else {
                //NSLog("Successfully remove login item.")
            //}
            
        } else {
            NSLog("Failed to add login item.")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
