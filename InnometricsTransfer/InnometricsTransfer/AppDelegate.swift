//
//  AppDelegate.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 03.11.16.
//  Copyright © 2016 Denis Zaplatnikov. All rights reserved.
//

import Cocoa
import Sparkle

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var logOutMenuItem: NSMenuItem!
    @IBOutlet weak var window: NSWindow!

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func setUpServerSettings(_ sender: AnyObject) {
        let serverSettingsPopup: NSAlert = NSAlert()
        serverSettingsPopup.messageText = "Please enter server URL"
        serverSettingsPopup.addButton(withTitle: "Save")
        serverSettingsPopup.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 500, height: 24))
        inputTextField.stringValue = ServerPrefs.getServerUrl()
        inputTextField.placeholderString = "https://your-server-url.com"
        serverSettingsPopup.accessoryView = inputTextField
        
        var notCorrectOrCancelled = false
        while (!notCorrectOrCancelled) {
            let answer = serverSettingsPopup.runModal()
            if answer == NSApplication.ModalResponse.alertFirstButtonReturn {
                let enteredString = inputTextField.stringValue
                if ((enteredString.range(of: "\\s+", options: .regularExpression) != nil) || enteredString.count == 0) {
                    let myPopup: NSAlert = NSAlert()
                    myPopup.messageText = "Warning"
                    myPopup.informativeText = "Server URL cannot be empty."
                    myPopup.alertStyle = NSAlert.Style.informational
                    myPopup.addButton(withTitle: "OK")
                    myPopup.runModal()
                } else {
                    ServerPrefs.saveServerUrl(serverUrl: enteredString)
                    notCorrectOrCancelled = true
                }
            } else {
                notCorrectOrCancelled = true
            }
        }
    }
    
    @IBAction func logOutBtn_Clicked(_ sender: AnyObject) {
        let alert: NSAlert = NSAlert()
        alert.messageText = "InnometricsTransfer"
        alert.informativeText = "You are sure you want to log out?"
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: "Log Out")
        alert.addButton(withTitle: "Cancel")
        
        let answer = alert.runModal()
        if answer == NSApplication.ModalResponse.alertFirstButtonReturn {
            logOutMenuItem.isEnabled = false
            AuthorizationUtils.saveIsAuthorized(isAuthorized: false)
            AuthorizationUtils.saveAuthorizationToken(token: nil)
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let avc = storyboard.instantiateController(withIdentifier:"AuthorizationController") as! AuthorizationController
            NSApplication.shared.mainWindow?.contentViewController = avc
        }
    }
    
    // MARK: - Core Data stack
    lazy var applicationDocumentsDirectory: Foundation.URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.apple.toolsQA.CocoaApp_CD" in the user's Application Support directory.
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent("com.apple.toolsQA.CocoaApp_CD")
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "InnoMetricsTransfer", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        let fileManager = FileManager.default
        var failError: NSError? = nil
        var shouldFail = false
        var failureReason = "There was an error creating or loading the application's saved data."
        
        // Make sure the application files directory is there
        do {
            let properties = try self.applicationDocumentsDirectory.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
            if !properties.isDirectory! {
                failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
                shouldFail = true
            }
        } catch  {
            let nserror = error as NSError
            if nserror.code == NSFileReadNoSuchFileError {
                do {
                    try fileManager.createDirectory(atPath: self.applicationDocumentsDirectory.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    failError = nserror
                }
            } else {
                failError = nserror
            }
        }
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = nil
        if failError == nil {
            coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            let url = self.applicationDocumentsDirectory.appendingPathComponent("InnoMetricsCollector.storedata")

            do {
                try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                
                /*
                 Typical reasons for an error here include:
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                failError = error as NSError
            }
        }
        
        if shouldFail || (failError != nil) {
            // Report any error we got.
            if let error = failError {
                NSApplication.shared.presentError(error)
                fatalError("Unresolved error: \(error), \(error.userInfo)")
            }
            fatalError("Unsresolved error: \(failureReason)")
        } else {
            return coordinator!
        }
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving and Undo support
    
    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return managedObjectContext.undoManager
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !managedObjectContext.hasChanges {
            return .terminateNow
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            let nserror = error as NSError
            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == NSApplication.ModalResponse.alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = sender.windows.first {
            if (flag) {
                window.orderFront(nil)
            }
            else {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

