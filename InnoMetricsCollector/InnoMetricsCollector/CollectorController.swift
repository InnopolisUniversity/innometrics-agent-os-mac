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
    @IBOutlet weak var idleView: IdleController!
    @IBOutlet weak var pausePlayBtn: NSButton!
    @IBOutlet weak var pausePlayLabel: NSTextField!
    @IBOutlet weak var updateBtn: NSButtonCell!
    @IBOutlet weak var sendingIndicator: NSProgressIndicator!
    
    // Private fields
    private var context: NSManagedObjectContext!
    private var privateContext: NSManagedObjectContext!
    
    // Collection Fields
    private var isPaused: Bool = false
    private var isCollectingBrowserInfo: Bool = false
    private var isCollecting: Bool = true
    
    // Metrics+Session Fields
    private var currentSession: Session!
    private var currentMetric: Metric?
    private var prevMetric: Metric?
    private var currentIdleMetric: IdleMetric?
    
    // Process fields
    private var measurements = Set<EnergyMeasurement>()
    private var dbProcesses: [ActiveProcess]?
    
    // Timers for transfer
    private var processTransferTimer = CustomTimer()
    private var metricsTransferTimer = CustomTimer()
    
    func setUpGlobalEvents() {
        let throttler = Throttler(minimumDelay: 0.05)

        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationSwitchTriggered), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        NSEvent.addGlobalMonitorForEvents (
            matching: CollectorHelper.possibleUserMovements,
            handler: { (event: NSEvent) in throttler.throttle {
                self.handleUserMovement()
            }}
        )
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
        if (!isCollecting || !AuthorizationUtils.isAuthorized()) {
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
                print("got a new metric", newMetric!.appName!)
                self.setEndTimeOfPrevMetric()
                self.prevMetric = self.currentMetric
                self.currentMetric = newMetric
            })
    }
    
    func handleUserMovement() {
        if (!isCollecting) {
            return
        }
        
        // print("user movement")
    }
    
    
    func setEndTimeOfPrevMetric() {
        if currentMetric != nil {
            MetricCRUD.setEndTimeOfPrevMetric(m: currentMetric!, context: self.privateContext, callback: { (modifiedMetric) -> Void in
            })
        }
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
    
    func blockUI() {
        self.pausePlayBtn.isEnabled = false
        if (!self.isPaused) {
            activeApplicationView.pauseTime()
            pausePlayBtn.image = #imageLiteral(resourceName: "playIcon")
            pausePlayLabel.stringValue = "Start"
        }
    }
    
    func releaseUI() {
        self.pausePlayBtn.isEnabled = true
        if (!isPaused) {
            pausePlayBtn.image = #imageLiteral(resourceName: "pauseIcon")
            pausePlayLabel.stringValue = "Pause"
            isPaused = false
        }
    }
    
    func updateSession() {
        let session = SessionInfoUtils.createAndSaveCurrentSession(currentSession: currentSession, context: self.privateContext)
        self.currentSession = session
        self.currentWorkingSessionView.updateSession(session: session!)
    }
    
    @IBAction func updateClicked(_ sender: Any) {
        let updater = SUUpdater.shared()
        updater?.feedURL = URL(string: "")
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
        } else {
            activeApplicationView.pauseTime()
            pausePlayBtn.image = #imageLiteral(resourceName: "playIcon")
            pausePlayLabel.stringValue = "Start"
            isPaused = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
