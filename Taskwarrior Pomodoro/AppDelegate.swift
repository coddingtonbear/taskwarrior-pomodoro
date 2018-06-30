//
//  AppDelegate.swift
//  Taskwarrior Pomodoro
//
//  Created by Adam Coddington on 12/5/15.
//  MIT Licensed
//

import Cocoa


let NSAlternateKeyMask = 1 << 19


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    @IBOutlet weak var window: NSWindow!
    
    //MARK: Attributes -
    let taskPath = "/usr/local/bin/task"
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var activeTaskId: String? = nil
    var activeTimer: Timer? = nil
    var activeTimerEnds: Date? = nil
    var activeMenuItem: NSMenuItem? = nil
    var pomodoroDuration: Double = 60 * 25
    var configuration = [String: String]()
    let menu = NSMenu();
    var activeCountdownTimer: Timer? = nil
    var currentPomodorosLogUUID: String?
    var pomsPerLongBreak: Int = 4
    var activeTaskPomodorosLogUUID: String?
    
    let kPomodoroLogEntryDescription = "PomodoroLog"
    let kPomsLongBreakCharacter = "-"
    let kPomsPomDoneCharacter = "🍅"
    let kPomsActiveCharacter = "🍊"

    
    //MARK: Menu Items Tags -
    let kTimerItemTag = 1
    let kActiveTaskSeparator1ItemTag = 2
    let kActiveTaskMenuItemTag = 3
    let kStopTaskMenuItemTag = 4
    let kActiveTaskSeparator2ItemTag = 5
    let kPendingTaskMenuItemTag = 6;
    let kQuitSeparatorMenuItemTag = 7;
    let kQuitMenuItemTag = 8;
    let kSyncSeparatorMenuItemTag = 7;
    let kSyncMenuItemTag = 9;
    let kPomodorosCountMenuItemTag = 10
    
    //MARK: Menu Items Titles -
    let kStopTitleFormat = "Stop (%02u:%02u remaining)"
    let kActiveTitlePrefix = "Active: "

    //MARK: NSApplicationDelegate -
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        configuration = getConfigurationSettings()
        
        if let button = statusItem.button {
            let imageName = { () -> String in
                #if DEBUG
                    return "StatusBarButtonImageDevelopment"
                #else
                    return "StatusBarButtonImage"
                #endif
            }()
            
            button.image = NSImage(named: NSImage.Name(rawValue: imageName))
        }
        
        menu.delegate = self
        statusItem.menu = menu
    }
    
    //MARK: NSMenuDelegate -
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems();
        startCountdownTimer()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        stopCountdownTimer()
    }

    
    //MARK: API -
    func startCountdownTimer() {
        guard activeTimerEnds != nil else { return }
        
        activeCountdownTimer = Timer(timeInterval: 1.0, repeats: true) { _ in self.updateTaskTimer() }
        RunLoop.current.add(activeCountdownTimer!, forMode: .eventTrackingRunLoopMode)
    }
    
    func stopCountdownTimer() {
        activeCountdownTimer?.invalidate();
        activeCountdownTimer = nil
    }
    
    func updateMenuItems(_ sender: Any){
        updateMenuItems()
    }
    
    func updateMenuItems() {
        setupStatsMenuItems()
        setupActiveTaskMenuItem()
        setupSyncMenuItem()
        setupQuitMenuItem()
        setupTaskListMenuItems()
    }
    
    func setupStatsMenuItems() {
        let pomodoros = getPomodorosCountMenuItem()
        
        if let title = getPomodorosCountTitle() {
            pomodoros.isHidden = false
            pomodoros.title = title
        } else {
            pomodoros.isHidden = true
        }
    }
    
    func setupActiveTaskMenuItem() {
        let activeSeparator1MenuItem = getActiveSeparatorMenuItem(1)
        let activeTaskMenuItem = getActiveTaskMenuItem()
        let stopTaskMenuItem = getStopTaskMenuItem()
        _ = getActiveSeparatorMenuItem(2)
        
        
        if activeTaskId != nil {
            activeSeparator1MenuItem.isHidden = false
            activeTaskMenuItem.isHidden = false
            stopTaskMenuItem.isHidden = false
            let taskDescription = getActiveTaskDescription()
            activeTaskMenuItem.title = "\(kActiveTitlePrefix) \(taskDescription)"
            updateTaskTimer()
        } else {
            activeSeparator1MenuItem.isHidden = true
            activeTaskMenuItem.isHidden = true
            stopTaskMenuItem.isHidden = true
        }
    }
    
    func setupSyncMenuItem() {
        guard menu.item(withTag: kSyncMenuItemTag) == nil else { return }
        
        let hidden = configuration["taskd.server"] == nil;
        
        let syncSeparator = separatorWithTag(kSyncSeparatorMenuItemTag)
        syncSeparator.isHidden = hidden;
        
        let syncMenuItem = NSMenuItem(title: "Synchronize", action: #selector(AppDelegate.sync(_:)), keyEquivalent: "s")
        syncMenuItem.tag = kSyncMenuItemTag
        syncMenuItem.isHidden = hidden;
        menu.addItem(syncMenuItem)
    }
    
    func setupQuitMenuItem() {
        guard menu.item(withTag: kQuitMenuItemTag) == nil else { return }
        
        _ = separatorWithTag(kQuitSeparatorMenuItemTag)
        
        let quitMenuItem = NSMenuItem(title: "Quit Taskwarrior Pomodoro", action: #selector(AppDelegate.exitNow), keyEquivalent: "q")
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
                        action: #selector(AppDelegate.setActiveTask(_:)),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = uuid
                    menuItem.tag = kPendingTaskMenuItemTag
                    let index = menu.indexOfItem(withTag: kSyncSeparatorMenuItemTag)
                    menu.insertItem(menuItem, at: index)
                }
            }
        }
    }
    
    func getConfigurationSettings(_ path: String = "~/.taskrc") -> [String: String] {
        var configurationSettings = [String: String]()
        
        let location = NSString(string: path).expandingTildeInPath
        guard let fileContent = try? String(contentsOfFile: location, encoding: .utf8) else { return configurationSettings }
        let fileContentLines = fileContent.split(separator: "\n").map(String.init)
        
        for line in fileContentLines {
            if line.hasPrefix("include ") {
                let pathLine = String(line[line.index(line.startIndex, offsetBy: 8)...])
                for (k, v) in getConfigurationSettings(pathLine) {
                    configurationSettings[k] = v
                }
            } else if let equalIndex = line.index(of: "=" as Character) {
                let configurationKey = line[line.startIndex ..< equalIndex].trimmingCharacters(in: .whitespaces)
                let configurationValue = line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespaces)
                configurationSettings[configurationKey] = configurationValue
            }
        }
        
        return configurationSettings
    }
    
    func getPendingTasks() -> [JSON] {
        var pendingArguments = ["-ACTIVE", "status:Pending"]
        
        if let definedDefaultFilter = configuration["pomodoro.defaultFilter"] {
            pendingArguments = [definedDefaultFilter] + pendingArguments
        }
        
        return getTasksUsingFilter(pendingArguments)
    }
    
    func getTodaysPomodorosLog() -> JSON? {
        let logFilter = ["status:Completed", kPomodoroLogEntryDescription, "entry:today", "limit:1"]
        let tasks = getTasksUsingFilter(logFilter)
        
        let task = tasks[safe: 0]
        currentPomodorosLogUUID = task?["uuid"].string
        return task
    }
    
    func getTasksUsingFilter(_ filter: [String]) -> [JSON] {
        let arguments = ["rc.json.array=off"] + filter + ["export"]
        
        let output = taskCommandWithResult(arguments)
        
        let taskListStrings = output.split(separator: "\n").map(String.init)
        
        let taskList = taskListStrings.map { (string) -> JSON in
            if let dataFromString = string.data(using: .utf8, allowLossyConversion: true) {
                return (try? JSON(data: dataFromString)) ?? JSON.null
            }
            return JSON.null
        }.filter { $0 != JSON.null }
        
        return taskList;
    }
    
    func createTodaysPomodorosLogEntry() -> String? {
        let arguments = ["log", kPomodoroLogEntryDescription]
        taskCommand(arguments)
        
        let log = getTodaysPomodorosLog()
        return log?["uuid"].string
    }
    
    func taskCommandWithResult(_ arguments: [String]) -> String {
        let task = Process()
        task.launchPath = taskPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        
        return output
    }
    
    func taskCommand(_ arguments: [String]) {
        let task = Process()
        task.launchPath = taskPath
        task.arguments = arguments

        task.launch()
        task.waitUntilExit()
    }
    
    func getPomodorosCountTitle() -> String? {
        var title = ""
        var pomsDone = 0
        var pomsActive = isActive() ? 1 : 0
       
        // Allow users to disable the pomodoro count display
        if let countDisplayString = configuration["pomodoro.displayCount"] {
            if let countDisplay = countDisplayString.toBool() {
                if countDisplay == false {
                    return nil;
                }
            }
        }
        
        if let log = getTodaysPomodorosLog() {
             pomsDone = log["annotations"].count
        }
        
        let pomsToDraw = pomsDone + pomsActive
        
        for i in 0..<pomsToDraw {
            if (i + 1) % pomsPerLongBreak == 1 && i != 0 {
                title += kPomsLongBreakCharacter
            }
            
            if pomsDone > 0 {
                title += kPomsPomDoneCharacter
                pomsDone -= 1
            } else if pomsActive > 0 {
                title += kPomsActiveCharacter
                pomsActive -= 1
            }
            
        }
        
        return title.isEmpty ? nil : title
    }
    
    func isActive() -> Bool {
        return activeTaskId != nil
    }
    
    
    func clearOldTasks() {
        while let item = menu.item(withTag: kPendingTaskMenuItemTag) {
            menu.removeItem(item)
        }
    }
    
    func getStopTaskMenuItem() -> NSMenuItem {
        if let item = menu.item(withTag: kStopTaskMenuItemTag) {
            return item;
        }
        
        let stopItem = NSMenuItem(
            title: "Stop",
            action: #selector(AppDelegate.stopActiveTask(_:)),
            keyEquivalent: "s"
        )
        stopItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(NSAlternateKeyMask))
        stopItem.tag = kStopTaskMenuItemTag
        menu.addItem(stopItem)
        
        return stopItem;
    }
    
    func getActiveSeparatorMenuItem(_ index: Int) -> NSMenuItem {
        var tag: Int = 1
        
        switch (index) {
        case 1:
            tag = kActiveTaskSeparator1ItemTag
        case 2:
            tag = kActiveTaskSeparator2ItemTag
        default:
            tag = kActiveTaskSeparator1ItemTag;
        }
        
        let separator = menu.item(withTag: tag) ?? separatorWithTag(tag);
        
        return separator
    }
    
    func getActiveTaskMenuItem() -> NSMenuItem {
        if let item = menu.item(withTag: kActiveTaskMenuItemTag) {
            return item
        }
        
        let taskDescription = getActiveTaskDescription()
        let activeItem = NSMenuItem(
            title: "\(kActiveTitlePrefix) \(taskDescription)",
            action: nil,
            keyEquivalent: ""
        )
        activeItem.isEnabled = false
        activeItem.tag = kActiveTaskMenuItemTag
        menu.addItem(activeItem)
        
        return activeItem
    }
    
    func getPomodorosCountMenuItem() -> NSMenuItem {
        if let item = menu.item(withTag: kPomodorosCountMenuItemTag) {
            return item
        }
        
        let pomsItem = NSMenuItem(
            title: "",
            enabled: false,
            tag: kPomodorosCountMenuItemTag
        )
        
        menu.addItem(pomsItem)
        return pomsItem
    }
    
    func separatorWithTag(_ tag: Int) -> NSMenuItem {
        let separator = NSMenuItem.separator()
        separator.tag = tag
        menu.addItem(separator);
        return separator
    }
    
    func getActiveTaskDescription() -> String {
        if activeTaskId == nil {
            return "N/A"
        }
        
        var description: String = "N/A"
        
        let filter = [activeTaskId!, "limit:1"]
        let tasks = getTasksUsingFilter(filter)
        
        if !tasks.isEmpty {
            let taskData = tasks[0]
            if let thisDescription = taskData["description"].string {
                description = thisDescription
            }
        }
        
        return description
    }
    
    @objc func sync(_ sender: Any) {
        sync()
    }
    
    func sync() {
        taskCommand(["sync"])
    }
    
    @objc func stopActiveTask(_ sender: Any) {
        stopActiveTask()
    }
    
    func stopActiveTask() {
        if activeTimer != nil {
            activeTimer!.invalidate()
            activeTimer = nil
        }
        
        activeTimerEnds = nil;
        updateTaskTimer()

        taskCommand([activeTaskId!, "stop"])
        
        activeTaskId = nil
        updateMenuItems()
    }
    
    func startTaskById(_ taskId: String) {
        activeTaskId = taskId
        
        taskCommand([taskId, "start"])
        activeTaskPomodorosLogUUID = currentPomodorosLogUUID
        
        if activeTaskPomodorosLogUUID == nil {
            activeTaskPomodorosLogUUID = createTodaysPomodorosLogEntry()
        }
        
        updateMenuItems()
    }
    
    func runPostCompletionHooks(_ taskId: String) {
        if let postCompletionCommand = configuration["pomodoro.postCompletionCommand"] {
            let errorPipe = Pipe()
            let errorFile = errorPipe.fileHandleForReading
            
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "\(postCompletionCommand) \(taskId)"]
            task.standardError = errorPipe
            task.launch()
            task.waitUntilExit()
            
            let stderr = stringFromFileAndClose(errorFile)
            
            if task.terminationStatus != 0 {
                let alert:NSAlert = NSAlert();
                alert.messageText = "Post-Hook Error";
                alert.informativeText = "An error was encountered when running your post-hook command: `\(stderr)`.";
                alert.runModal();
            }
        }
    }
    
    fileprivate func stringFromFileAndClose(_ file: FileHandle) -> String {
        let data = file.readDataToEndOfFile()
        file.closeFile()
        let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?
        return output ?? ""
    }
    
    @objc func timerExpired() {
        stopCountdownTimer()
        activeTimer?.invalidate()
        activeTimer = nil

        let taskId = activeTaskId;

        stopActiveTask()
        logPomodoroForTaskDone(taskId)

        let alert:NSAlert = NSAlert();
        alert.messageText = "Break time!";
        alert.informativeText = "Taskwarrior Pomodoro";
        alert.runModal();

        runPostCompletionHooks(taskId!)
    }
    
    func logPomodoroForTaskDone(_ taskId: String?) {
        let uuid = taskId ?? ""
        
        if let logId = activeTaskPomodorosLogUUID {
            taskCommand([logId, "annotate", "\"Pomodoro uuid:\(uuid)\""])
        }
    }
    
    @objc func setActiveTask(_ sender: AnyObject) {
        if activeTaskId != nil{
            stopActiveTask()
        }
        startTaskById(sender.representedObject as! String)
        
        if let configuredPomodoroDuration = configuration["pomodoro.durationSeconds"] {
            if let configuredPomodoroDurationAsDouble = Double(configuredPomodoroDuration) {
                pomodoroDuration = configuredPomodoroDurationAsDouble
            }
        }

        activeTimer = Timer(timeInterval: pomodoroDuration, repeats: false) { _ in self.timerExpired() }
        RunLoop.current.add(activeTimer!, forMode: .defaultRunLoopMode)
        
        let now = Date()
        activeTimerEnds = now.addingTimeInterval(pomodoroDuration);
    }
    
    @objc func updateTaskTimer() {
        guard let finish = activeTimerEnds else { return }
        
        let date = Date()
        
        let minutesFrom = finish.minutes(from: date)
        let secondsFrom = finish.seconds(from: date) - minutesFrom * 60
        
        getStopTaskMenuItem().title = String(format: kStopTitleFormat, minutesFrom, secondsFrom)
    }
    
    @objc func exitNow() {
        NSApplication.shared.terminate(self)
    }
}

extension Date {
    func yearsFrom(_ date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.year, from: date, to: self, options: []).year!
    }
    func monthsFrom(_ date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.month, from: date, to: self, options: []).month!
    }
    func weeksFrom(_ date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.weekOfYear, from: date, to: self, options: []).weekOfYear!
    }
    func daysFrom(_ date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.day, from: date, to: self, options: []).day!
    }
    func hoursFrom(_ date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.hour, from: date, to: self, options: []).hour!
    }
    func minutes(from date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.minute, from: date, to: self, options: []).minute!
    }
    func seconds(from date:Date) -> Int{
        return (Calendar.current as NSCalendar).components(.second, from: date, to: self, options: []).second!
    }
    func offset(from date:Date) -> String {
        if yearsFrom(date)   > 0 { return "\(yearsFrom(date))y"   }
        if monthsFrom(date)  > 0 { return "\(monthsFrom(date))M"  }
        if weeksFrom(date)   > 0 { return "\(weeksFrom(date))w"   }
        if daysFrom(date)    > 0 { return "\(daysFrom(date))d"    }
        if hoursFrom(date)   > 0 { return "\(hoursFrom(date))h"   }
        if minutes(from: date) > 0 { return "\(minutes(from: date))m" }
        if seconds(from: date) > 0 { return "\(seconds(from: date))s" }
        return ""
    }
}

extension NSMenuItem {
    convenience init(title: String, enabled: Bool, tag: NSInteger) {
        self.init(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        
        self.isEnabled = enabled
        self.tag = tag
    }
}

extension Array {
    subscript (safe index: Int) -> Element? {
        return (0..<count).contains(index) ? self[index] : nil
    }
}

extension String {
    func toBool() -> Bool? {
        switch self {
        case "True", "true", "yes", "1":
            return true
        case "False", "false", "no", "0":
            return false
        default:
            return nil
        }
    }
}

