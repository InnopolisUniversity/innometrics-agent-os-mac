//
//  CollectorController.swift
//  InnoMetricsCollector
//
//  Created by Denis Zaplatnikov on 11/01/2017.
//  Modified by Dragos Strugar on 11/02/2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa
import Sparkle

class CollectorController: NSObject {
    // Status Menu Entities
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var loginMenu: NSMenu!
    @IBOutlet weak var collectorView: NSView!
    @IBOutlet weak var metricsCollectorMenuItem: NSMenuItem!
    @IBOutlet weak var currentWorkingSessionMenuItem: NSMenuItem!
    @IBOutlet weak var logInMenuItem: NSMenuItem!
    @IBOutlet weak var currentWorkingSessionView: CurrentWorkingSessionController!
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // Collector Entities
    @IBOutlet weak var activeApplicationView: ActiveApplicationController!
    @IBOutlet weak var updateBtn: NSButtonCell!
    
    // Private fields
    private var context: NSManagedObjectContext!
    private var privateContext: NSManagedObjectContext!
    private var processPrivateContext: NSManagedObjectContext!
    
    // Collection Fields
    private var isCollectingBrowserInfo: Bool = false
    
    // Metrics+Session Fields
    private var currentSession: Session!
    private var currentProcessSession: Session!
    private var currentMetric: Metric?
    private var prevMetric: Metric?
    private var currentIdleMetric: IdleMetric?
    
    // Timers for transfer and idle
    private var processTransferTimer = CustomTimer()
    private var metricsTransferTimer = CustomTimer()
    private var idleTimer = CustomTimer(interval: 30, repeats: false)
    private var measurementRecordTimer = CustomTimer(interval: 20)
    
    func setUpGlobalEvents() {
        let throttler = Throttler(minimumDelay: 0.05)

        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationSwitchTriggered), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        _ = AXIsProcessTrustedWithOptions(options)
        
        NSEvent.addGlobalMonitorForEvents (
            matching: CollectorHelper.possibleUserMovements,
            handler: { (event: NSEvent) in throttler.throttle {
                self.handleUserMovement()
            }}
        )
        
        self.updateSession()
        
        // Add timers
        measurementRecordTimer.startTimer {
            self.recordProcesses()
        }
    }
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: Selector(("renderMenuItems")), name: UserDefaults.didChangeNotification, object: nil)
        CollectorHelper.setUpLaunchAtLogin()
        CollectorHelper.setImage(statusItem: statusItem, named: "statusIcon")

        renderMenuItems()
    }
    
    @objc func applicationSwitchTriggered(notification: NSNotification) {
        handleApplicationSwitch()
    }
    
    func handleApplicationSwitch() {
        if (!AuthorizationUtils.isAuthorized()) {
            return
        }
        
        let frontmostApp: NSRunningApplication? = CollectorHelper.getFrontmostApp()
        if frontmostApp == nil { return }
        if frontmostApp?.processIdentifier == nil { return }
        if frontmostApp?.bundleIdentifier == nil { return }
        
        let foregroundPID = frontmostApp!.processIdentifier
        let foregroundWindowBundleId = frontmostApp!.bundleIdentifier!
        
        activeApplicationView.update(application: frontmostApp!)
        
        self.updateSession()
        
        MetricCRUD.createMetric(app: frontmostApp!, pid: foregroundPID, context: self.privateContext, session: self.currentSession, callback: { (newMetric) -> Void in
                self.setEndTimeOfPrevMetric()
                if newMetric != nil {
                    self.prevMetric = self.currentMetric
                    self.currentMetric = newMetric
                    
                    // start timer to determine when it becomes idle
                    self.idleTimer.startTimer {
                        self.markAsIdle()
                    }
                }
            })
    }
    
    func handleUserMovement() {
        if currentMetric != nil {
            
            if currentMetric?.isIdle == 1 {
                handleApplicationSwitch()
            } else {
                self.idleTimer.stopTimer()
                self.idleTimer.startTimer {
                    self.markAsIdle()
                }
            }
        }
    }
    
    func markAsIdle() {
        MetricCRUD.markAsIdle(app: self.currentMetric!, context: self.privateContext, callback: { (newMetric) -> Void in
            self.setEndTimeOfPrevMetric()
            if newMetric != nil {
                self.prevMetric = self.currentMetric
                self.currentMetric = newMetric
            }
        })
    }
    
    func setEndTimeOfPrevMetric() {
        if currentMetric != nil {
            MetricCRUD.setEndTimeOfPrevMetric(m: currentMetric!, context: self.privateContext, callback: { (modifiedMetric) -> Void in
            })
        }
    }
    
    // Processes + Measurements
    func recordProcesses() {
        ProcessCRUD.getAllProcesses(context: self.processPrivateContext, session: self.currentProcessSession, callback: { (processes) -> Void in
        })
    }
    
    // UI things
    @objc func renderMenuItems() {
        statusItem.menu = loginMenu
        if (AuthorizationUtils.isAuthorized()) {
            CollectorHelper.updateUIAuthorized(
                logInMenuItem: logInMenuItem, currentWorkingSessionMenuItem: currentWorkingSessionMenuItem, metricsCollectorMenuItem: metricsCollectorMenuItem,
                currentWorkingSessionView: currentWorkingSessionView, collectorView: collectorView
            )
            
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            self.context = appDelegate.managedObjectContext
            
            // set up bg thread for collecting data
            self.privateContext = {
                let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                moc.persistentStoreCoordinator = appDelegate.persistentStoreCoordinator
                return moc
            }()
            
            // set up bg thread for collecting processes and measurements
            self.processPrivateContext = {
                let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                moc.persistentStoreCoordinator = appDelegate.persistentStoreCoordinator
                return moc
            }()
            
            self.setUpGlobalEvents()
        } else {
            CollectorHelper.updateUIUnuthorized(
                logInMenuItem: logInMenuItem, currentWorkingSessionMenuItem: currentWorkingSessionMenuItem, metricsCollectorMenuItem: metricsCollectorMenuItem,
                currentWorkingSessionView: currentWorkingSessionView, collectorView: collectorView
            )
        }
    }
    
    @IBAction func onClickToLogIn(_ sender: Any) {
        let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)
        let logInController = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("LoginViewController")) as? NSWindowController
        
        logInController!.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateSession() {
        let session = SessionInfoUtils.createAndSaveCurrentSession(currentSession: currentSession, context: self.privateContext)
        let processesSession = SessionInfoUtils.createAndSaveCurrentSession(currentSession: currentProcessSession, context: self.processPrivateContext)
        
        self.currentSession = session
        self.currentProcessSession = processesSession
        self.currentWorkingSessionView.updateSession(session: session!)
    }
    
    @IBAction func updateClicked(_ sender: Any) {
        let updater = SUUpdater.shared()
        updater?.feedURL = URL(string: "")
        updater?.checkForUpdates(self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
