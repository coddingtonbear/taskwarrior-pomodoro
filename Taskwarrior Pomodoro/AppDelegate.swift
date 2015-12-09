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
    var activeTimer: NSTimer? = nil
    var activeTimerEnds: NSDate? = nil
    var activeMenuItem: NSMenuItem? = nil
    var pomodoroDuration:Double = 60 * 25
    var configuration: [String: String]? = nil

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        configuration = getConfigurationSettings()
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = Selector("printQuote:")
        }
        
        NSTimer.scheduledTimerWithTimeInterval(
            5,
            target: self,
            selector: "updateActiveMenuItem",
            userInfo: nil,
            repeats: true
        )
        
        updateMenuItems()
    }
    
    func updateActiveMenuItem() {
        let date = NSDate()
        if activeMenuItem != nil && activeTimerEnds != nil{
            let minutesFrom = activeTimerEnds!.minutesFrom(date) + 1
            activeMenuItem!.title = "Stop (\(minutesFrom) minutes remaining)"
        }
    }
    
    func getConfigurationSettings() -> [String: String] {
        var configurationSettings = [String: String]()
        
        let location = NSString(string: "~/.taskrc").stringByExpandingTildeInPath
        let fileContent = try? NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding) as String
        let fileContentLines = fileContent?.characters.split{$0 == "\n"}.map(String.init)
        
        for line in fileContentLines! {
            if line.hasPrefix("pomodoro") {
                var dotIndex: String.CharacterView.Index? = nil;
                var equalIndex: String.CharacterView.Index? = nil;
                
                if let idx = line.characters.indexOf("." as Character) {
                    dotIndex = idx
                }
                if let idx = line.characters.indexOf("=" as Character) {
                    equalIndex = idx
                }
                
                if dotIndex != nil && equalIndex != nil {
                    let configurationKey = line.substringWithRange(
                        Range(start: dotIndex!.successor(), end: equalIndex!)
                    ).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                    let configurationValue = line.substringFromIndex(
                        equalIndex!.successor()
                    ).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                    configurationSettings[configurationKey] = configurationValue
                }
            }
        }
        
        return configurationSettings
    }
    
    func getPendingTasks() -> [JSON] {
        var pendingArguments = ["status:pending"]
        
        if let definedDefaultFilter = configuration!["defaultFilter"] {
            print(definedDefaultFilter)
            pendingArguments = [definedDefaultFilter] + pendingArguments
        }
        
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = ["rc.json.array=off"] + pendingArguments + ["export"]
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
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
    
    func updateMenuItems(aNotification: NSNotification){
        updateMenuItems()
    }
    
    func updateMenuItems() {
        let menu = NSMenu()
        let tasks = getPendingTasks();

        configuration = getConfigurationSettings()
        
        menu.addItem(NSMenuItem(title: "Refresh Tasks", action: Selector("updateMenuItems:"), keyEquivalent: "r"))
        if activeTaskId != nil {
            menu.addItem(NSMenuItem.separatorItem())
            let taskDescription = getActiveTaskDescription()
            let activeTaskItem = NSMenuItem(
                title: "Active: \(taskDescription)",
                action: "",
                keyEquivalent: ""
            )
            activeTaskItem.enabled = false
            
            menu.addItem(activeTaskItem)
            activeMenuItem = NSMenuItem(title: "Stop", action: Selector("stopActiveTask:"), keyEquivalent: "s")
            menu.addItem(activeMenuItem!)
        }
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
    
    func getActiveTaskDescription() -> String {
        var description: String = ""
        
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = [activeTaskId!, "export"]
        
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        if let dataFromString = output.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true) {
            let taskData = JSON(data: dataFromString)
            if let thisDescription = taskData["description"].string {
                description = thisDescription
            }
        }
        
        return description
    }
    
    func stopActiveTask(aNotification: NSNotification) {
        stopActiveTask()
    }
    
    func stopActiveTask() {
        if activeTimer != nil {
            activeTimer!.invalidate()
            activeTimer = nil
        }

        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = [activeTaskId!, "stop"]
        task.launch()
        task.waitUntilExit()
        
        activeTaskId = nil
        updateMenuItems()
    }
    
    func startTaskById(taskId: String) {
        activeTaskId = taskId
        
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = [taskId, "start"]
        task.launch()
        task.waitUntilExit()
        
        updateMenuItems()
    }
    
    func timerExpired() {
        if activeTimer != nil {
            activeTimer!.invalidate()
            activeTimer = nil
        }
        
        let alert:NSAlert = NSAlert();
        alert.messageText = "Break time!";
        alert.informativeText = "Taskwarrior Pomodoro";
        alert.runModal();
    }
    
    func setActiveTask(sender: AnyObject) {
        if activeTaskId != nil{
            stopActiveTask()
        }
        startTaskById(sender.representedObject as! String)
        
        activeTimer = NSTimer.scheduledTimerWithTimeInterval(
            pomodoroDuration,
            target: self,
            selector: "timerExpired",
            userInfo: nil,
            repeats: false
        )
        
        let now = NSDate()
        activeTimerEnds = now.dateByAddingTimeInterval(pomodoroDuration);
    }
}

extension NSDate {
    func yearsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Year, fromDate: date, toDate: self, options: []).year
    }
    func monthsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Month, fromDate: date, toDate: self, options: []).month
    }
    func weeksFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.WeekOfYear, fromDate: date, toDate: self, options: []).weekOfYear
    }
    func daysFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Day, fromDate: date, toDate: self, options: []).day
    }
    func hoursFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Hour, fromDate: date, toDate: self, options: []).hour
    }
    func minutesFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Minute, fromDate: date, toDate: self, options: []).minute
    }
    func secondsFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(.Second, fromDate: date, toDate: self, options: []).second
    }
    func offsetFrom(date:NSDate) -> String {
        if yearsFrom(date)   > 0 { return "\(yearsFrom(date))y"   }
        if monthsFrom(date)  > 0 { return "\(monthsFrom(date))M"  }
        if weeksFrom(date)   > 0 { return "\(weeksFrom(date))w"   }
        if daysFrom(date)    > 0 { return "\(daysFrom(date))d"    }
        if hoursFrom(date)   > 0 { return "\(hoursFrom(date))h"   }
        if minutesFrom(date) > 0 { return "\(minutesFrom(date))m" }
        if secondsFrom(date) > 0 { return "\(secondsFrom(date))s" }
        return ""
    }
}

