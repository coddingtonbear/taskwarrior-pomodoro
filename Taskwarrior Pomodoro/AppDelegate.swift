//
//  AppDelegate.swift
//  Taskwarrior Pomodoro
//
//  Created by Adam Coddington on 12/5/15.
//  Copyright © 2015 Adam Coddington. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    
    let taskPath = "/usr/local/bin/task"
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
    var activeTaskId: String? = nil

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = Selector("printQuote:")
        }
        
        updateMenuItems()
    }
    
    func getPendingTasks() -> [JSON] {
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = ["export", "status:pending"]
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        
        let taskListStrings = output.characters.split{$0 == "\n"}.map(String.init)
        
        var taskList = [JSON]()
        for taskListString in taskListStrings {
            if let dataFromString = taskListString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true) {
                let taskData = JSON(data: dataFromString)
                taskList.append(taskData)
            }
        }
        
        return taskList;
    }
    
    func updateMenuItemsClick(aNotification: NSNotification){
        updateMenuItems()
    }
    
    func updateMenuItems() {
        let menu = NSMenu()
        let tasks = getPendingTasks();
        
        
        menu.addItem(NSMenuItem(title: "Refresh Tasks", action: Selector("updateMenuItemsClick:"), keyEquivalent: "r"))
        if tasks.count > 0 {
            menu.addItem(NSMenuItem.separatorItem())
        }
        for task in tasks {
            if let description = task["description"].string {
                if let uuid = task["uuid"].string {
                    let menuItem = NSMenuItem(
                        title: description,
                        action: Selector("setActiveTask:"),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = uuid
                    menu.addItem(menuItem)
                }
            }
        }
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItem(NSMenuItem(title: "Quit Taskwarrior Pomodoro", action: Selector("terminate:"), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func stopActiveTask() {
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = [activeTaskId!, "stop"]
        task.launch()
    }
    
    func startTaskById(taskId: String) {
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = [taskId, "stop"]
        task.launch()
    }
    
    func setActiveTask(sender: AnyObject) {
        if activeTaskId != nil{
            stopActiveTask()
        }
        activeTaskId = sender.representedObject as! String
        startTaskById(activeTaskId!)
        print(activeTaskId)
    }
}

