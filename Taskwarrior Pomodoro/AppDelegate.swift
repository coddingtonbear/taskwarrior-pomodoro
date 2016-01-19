//
//  AppDelegate.swift
//  Taskwarrior Pomodoro
//
//  Created by Adam Coddington on 12/5/15.
//  MIT Licensed
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    @IBOutlet weak var window: NSWindow!
    
    //MARK: Attributes -
    let taskPath = "/usr/local/bin/task"
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
    var activeTaskId: String? = nil
    var activeTimer: NSTimer? = nil
    var activeTimerEnds: NSDate? = nil
    var activeMenuItem: NSMenuItem? = nil
    var pomodoroDuration:Double = 60 * 25
    var configuration: [String: String]? = nil
    let menu = NSMenu();
    var activeCountdownTimer: NSTimer? = nil

    
    //MARK: Menu Items Tags -
    let kTimerItemTag = 1
    let kActiveTaskSeparator1ItemTag = 2
    let kActiveTaskMenuItemTag = 3
    let kStopTaskMenuItemTag = 4
    let kActiveTaskSeparator2ItemTag = 5
    let kPendingTaskMenuItemTag = 6;
    let kQuitSeparatorMenuItemTag = 7;
    let kQuitMenuItemTag = 8;
    
    //MARK: Menu Items Titles -
    let kStopTitleFormat = "Stop (%02u:%02u remaining)"
    let kActiveTitlePrefix = "Active: "

    //MARK: NSApplicationDelegate -
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        configuration = getConfigurationSettings()
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = Selector("printQuote:")
        }
        
        menu.delegate = self
        statusItem.menu = menu
    }
    
    //MARK: NSMenuDelegate -
    func menuWillOpen(menu: NSMenu) {
        updateMenuItems();
        startCountdownTimer()
    }
    
    func menuDidClose(menu: NSMenu) {
        stopCountdownTimer()
    }

    
    //MARK: API -
    func startCountdownTimer() {
        if activeTimerEnds != nil {
            activeCountdownTimer = NSTimer(
                timeInterval: 1.0,
                target: self,
                selector: "updateTaskTimer",
                userInfo: nil,
                repeats: true
            )
            NSRunLoop.currentRunLoop().addTimer(self.activeCountdownTimer!, forMode: NSEventTrackingRunLoopMode)
        }
    }
    
    func stopCountdownTimer() {
        activeCountdownTimer?.invalidate();
        activeCountdownTimer = nil
    }
    
    func updateMenuItems(aNotification: NSNotification){
        updateMenuItems()
    }
    
    func updateMenuItems() {
        configuration = getConfigurationSettings()
        
        setupActiveTaskMenuItem()
        setupQuitMenuItem()
        setupTaskListMenuItems()
    }
    
    func setupActiveTaskMenuItem() {
        let activeSeparator1MenuItem = getActiveSeparatorMenuItem(1)
        let activeTaskMenuItem = getActiveTaskMenuItem()
        let stopTaskMenuItem = getStopTaskMenuItem()
        getActiveSeparatorMenuItem(2)
        
        
        if activeTaskId != nil {
            activeSeparator1MenuItem.hidden = false
            activeTaskMenuItem.hidden = false
            stopTaskMenuItem.hidden = false
            let taskDescription = getActiveTaskDescription()
            activeTaskMenuItem.title = "\(kActiveTitlePrefix) \(taskDescription)"
            updateTaskTimer()
        } else {
            activeSeparator1MenuItem.hidden = true
            activeTaskMenuItem.hidden = true
            stopTaskMenuItem.hidden = true
        }
    }
    
    func setupQuitMenuItem() {
        guard menu.itemWithTag(kQuitMenuItemTag) == nil else {
            return
        }
        
        separatorWithTag(kQuitSeparatorMenuItemTag)
        
        let quitMenuItem = NSMenuItem(title: "Quit Taskwarrior Pomodoro", action: Selector("terminate:"), keyEquivalent: "q")
        quitMenuItem.tag = kQuitMenuItemTag
        menu.addItem(quitMenuItem)
    }
    
    func setupTaskListMenuItems() {
        clearOldTasks()
        
        let tasks = getPendingTasks();
        
        for task in tasks {
            if let description = task["description"].string {
                if let uuid = task["uuid"].string {
                    let menuItem = NSMenuItem(
                        title: description,
                        action: Selector("setActiveTask:"),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = uuid
                    menuItem.tag = kPendingTaskMenuItemTag
                    let index = menu.indexOfItemWithTag(kQuitSeparatorMenuItemTag)
                    menu.insertItem(menuItem, atIndex: index)
                }
            }
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
        var pendingArguments = ["status:Pending"]
        
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
    
    func clearOldTasks() {
        while let item = menu.itemWithTag(kPendingTaskMenuItemTag) {
            menu.removeItem(item)
        }
    }
    
    func getStopTaskMenuItem() -> NSMenuItem {
        if let item = menu.itemWithTag(kStopTaskMenuItemTag) {
            return item;
        }
        
        let stopItem = NSMenuItem(
            title: "Stop",
            action: Selector("stopActiveTask:"),
            keyEquivalent: "s"
        )
        stopItem.tag = kStopTaskMenuItemTag
        menu.addItem(stopItem)
        
        return stopItem;
    }
    
    func getActiveSeparatorMenuItem(index: Int) -> NSMenuItem {
        var tag: Int = 1
        
        switch (index) {
        case 1:
            tag = kActiveTaskSeparator1ItemTag
        case 2:
            tag = kActiveTaskSeparator2ItemTag
        default:
            tag = kActiveTaskSeparator1ItemTag;
        }
        
        let separator = menu.itemWithTag(tag) ?? separatorWithTag(tag);
        
        return separator
    }
    
    func getActiveTaskMenuItem() -> NSMenuItem {
        if let item = menu.itemWithTag(kActiveTaskMenuItemTag) {
            return item
        }
        
        let taskDescription = getActiveTaskDescription()
        let activeItem = NSMenuItem(
            title: "\(kActiveTitlePrefix) \(taskDescription)",
            action: "",
            keyEquivalent: ""
        )
        activeItem.enabled = false
        activeItem.tag = kActiveTaskMenuItemTag
        menu.addItem(activeItem)
        
        return activeItem
    }
    
    func separatorWithTag(tag: Int) -> NSMenuItem {
        let separator = NSMenuItem.separatorItem()
        separator.tag = tag
        menu.addItem(separator);
        return separator
    }
    
    func getActiveTaskDescription() -> String {
        if activeTaskId == nil {
            return "N/A"
        }
        
        var description: String = ""
        
        let task = NSTask()
        task.launchPath = taskPath
        task.arguments = ["rc.json.array=off", activeTaskId!, "export"]
        
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
        
        activeTimerEnds = nil;
        updateTaskTimer()

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
        
        stopActiveTask()
        
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
    
    func updateTaskTimer() {
        let date = NSDate()
        
        let minutesFrom = activeTimerEnds?.minutesFrom(date) ?? 25
        let secondsFrom = (activeTimerEnds?.secondsFrom(date) ?? 1500) - minutesFrom * 60
        
        getStopTaskMenuItem().title = String(format: kStopTitleFormat, minutesFrom, secondsFrom)
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

