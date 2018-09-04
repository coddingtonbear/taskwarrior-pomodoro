//
//  TWMenu.swift
//  Taskwarrior Pomodoro
//
//  Created by Jarosław Wojtasik on 23/08/2018.
//  Copyright © 2018 Adam Coddington. All rights reserved.
//

import Cocoa

public class TWMenu: NSObject, NSMenuDelegate, NSUserNotificationCenterDelegate {
    
    // Leave for later detections
    var taskPath = ""
    //MARK: - Attributes
    
    let menu = NSMenu()
    let overrides: [String]
    
    var activeTaskId: String? = nil
    var activeTimer: Timer? = nil
    var activeTimerEnds: Date? = nil
    var activeMenuItem: NSMenuItem? = nil
    var pomodoroDuration: Double = 60 * 25
    var configuration: [String: String]? = nil
    var activeCountdownTimer: Timer? = nil
    var currentPomodorosLogUUID: String?
    var pomsPerLongBreak: Int = 4
    var activeTaskPomodorosLogUUID: String?
    var pendingTasksMtime: Date? = nil
    var pendingTasks: [JSON] = []
    
    
    let kPomodoroLogEntryDescription = "PomodoroLog"
    let kPomsLongBreakCharacter = "-"
    let kPomsPomDoneCharacter = "🍅"
    let kPomsActiveCharacter = "🍊"
    
    public private(set) var image: NSImage? = {
        #if DEBUG
        let imageName = "StatusBarButtonImageDevelopment"
        #else
        let imageName = "StatusBarButtonImage"
        #endif
        return NSImage(named: NSImage.Name(rawValue: imageName))
    }()
    
    
    //MARK: - Menu Items Tags
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
    
    //MARK: - Menu Items Titles
    let kStopTitleFormat = "Stop (%02u:%02u remaining)"
    let kActiveTitlePrefix = "Active: "
    
    public init(arguments: [String]) {
        self.overrides = arguments
        super.init()
    }
    
    public override init() {
        self.overrides = []
        super.init()
    }
    
    // MARK: - ### NSUserNotificationCenterDelegate ###
    public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        let taskId = notification.userInfo!["taskId"] as! String
        setActiveTask(taskId)
    }
    
    //MARK: - ### NSMenuDelegate ###
    public func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems();
        startCountdownTimer()
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        stopCountdownTimer()
    }
    
    
    //MARK: - ### Public API ###
    public func getMenu(_ path: String = "~/.taskrc") -> NSMenu {
        NSUserNotificationCenter.default.delegate = self
        menu.autoenablesItems = false
        
        do {
            configuration = try getConfigurationSettings(path)
        } catch FileError.fileNotFound(let file_path) {
            let alert: NSAlert = NSAlert();
            alert.messageText = "Configuration file not found";
            alert.informativeText = "Your taskwarrior configuration file could not be found at \(file_path).";
            alert.runModal();
            exit(1);
        } catch FileError.fileEmpty {
            // This is probably fine
        } catch {
            let alert: NSAlert = NSAlert();
            alert.messageText = "Unexpected error";
            alert.informativeText = "An error was encountered while loading your configuration.";
            alert.runModal();
            exit(1);
        }
        
        let fileManager = FileManager.default
        var pathOptions = [
            "/usr/local/bin/task",
            "/usr/bin/task",
            "/opt/local/bin/task",
            ]
        if let configuredPath = configuration!["pomodoro.taskwarrior_path"] {
            pathOptions = [configuredPath]
        }
        
        for pathOption in pathOptions {
            if fileManager.fileExists(atPath: pathOption) {
                taskPath = pathOption
                break
            }
        }
        if taskPath == "" {
            let pathOptionsString = pathOptions.joined(separator: ", ")
            fatalError(
                "Could not find taskwarrior in \(pathOptionsString)"
            )
        }
        
        menu.delegate = self
        return menu
    }
    
    //MARK: - ### Private API ###
    func startCountdownTimer() {
        if activeTimerEnds != nil {
            activeCountdownTimer = Timer(
                timeInterval: 1.0,
                target: self,
                selector: #selector(TWMenu.updateTaskTimer),
                userInfo: nil,
                repeats: true
            )
            RunLoop.current.add(self.activeCountdownTimer!, forMode: RunLoopMode.eventTrackingRunLoopMode)
        }
    }
    
    func stopCountdownTimer() {
        activeCountdownTimer?.invalidate();
        activeCountdownTimer = nil
    }
    
    func updateMenuItems(_ sender: Any) {
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
        guard menu.item(withTag: kSyncMenuItemTag) == nil else {
            return
        }
        
        var hidden = true;
        if configuration!["taskd.server"] != nil {
            hidden = false;
        }
        
        let syncSeparator = separatorWithTag(kSyncSeparatorMenuItemTag)
        syncSeparator.isHidden = hidden;
        
        let syncMenuItem = NSMenuItem(title: "Synchronize", action: #selector(TWMenu.sync(_:)), keyEquivalent: "s")
        syncMenuItem.tag = kSyncMenuItemTag
        syncMenuItem.isHidden = hidden;
        syncMenuItem.target = self
        menu.addItem(syncMenuItem)
    }
    
    func setupQuitMenuItem() {
        guard menu.item(withTag: kQuitMenuItemTag) == nil else {
            return
        }
        
        _ = separatorWithTag(kQuitSeparatorMenuItemTag)
        
        let quitMenuItem = NSMenuItem(title: "Quit Taskwarrior Pomodoro", action: #selector(TWMenu.exitNow(_:)), keyEquivalent: "q")
        quitMenuItem.tag = kQuitMenuItemTag
        quitMenuItem.target = self
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
                        action: #selector(TWMenu.setActiveTaskViaMenu(_:)),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = uuid
                    menuItem.tag = kPendingTaskMenuItemTag
                    menuItem.target = self
                    let index = menu.indexOfItem(withTag: kSyncSeparatorMenuItemTag)
                    menu.insertItem(menuItem, at: index)
                    menuItem.isEnabled = true
                }
            }
        }
    }
    
    func getConfigurationSettings(_ path: String = "~/.taskrc") throws -> [String: String] {
        var configurationSettings = [String: String]()
        
        let location = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: location) {
            throw FileError.fileNotFound(file_path: location as NSString)
        }
        guard let fileContent = try? String(contentsOfFile: location, encoding: .utf8) else {
            return configurationSettings
        }
        let fileContentLines = fileContent.split(separator: "\n").map(String.init)
        
        for line in fileContentLines {
            if line.hasPrefix("include ") {
                var pathLine = line;
                let prefixRange = line.startIndex..<line.index(line.startIndex, offsetBy: 8)
                pathLine.removeSubrange(prefixRange)
                do {
                    for (k, v) in try getConfigurationSettings(pathLine) {
                        configurationSettings[k] = v
                    }
                } catch FileError.fileNotFound(let file_path) {
                    print("File '\(file_path)' not found")
                } catch FileError.fileEmpty {
                    //ignore
                }
            } else if let equalIndex = line.index(of: "=" as Character) {
                let configurationKey = line[line.startIndex..<equalIndex].trimmingCharacters(in: .whitespaces)
                let configurationValue = line[line.index(after: equalIndex)...].trimmingCharacters(in: .whitespaces)
                
                configurationSettings[configurationKey] = configurationValue
            }
        }
        if configurationSettings.count == 0 {
            throw FileError.fileEmpty
        }
        return configurationSettings
    }
    
    func pendingTasksAreOutOfDate() -> Bool {
        let fileManager = FileManager.default
        
        if let dataLocation = configuration!["data.location"] {
            let path = NSString(string: dataLocation + "/pending.data").expandingTildeInPath
            let attrs: NSDictionary
            do {
                attrs = try fileManager.attributesOfItem(atPath: path) as NSDictionary
            } catch _ {
                print("Error encountered getting attributes of pending.data")
                return true
            }
            let modificationDate = attrs[FileAttributeKey.modificationDate] as! Date
            
            
            if pendingTasksMtime == nil || pendingTasksMtime!.compare(modificationDate) == ComparisonResult.orderedAscending {
                pendingTasksMtime = modificationDate
                return true
            }
            return false
        }
        
        return true
    }
    
    func getPendingTasks() -> [JSON] {
        if pendingTasksAreOutOfDate() {
            refreshPendingTasks()
        }
        
        return pendingTasks
    }
    
    func refreshPendingTasks() {
        let pendingArguments = getPendingArguments()
        var tasks = getTasksUsingFilter(pendingArguments)
        tasks = getSortedTasks(tasks);
        
        pendingTasks = tasks
    }
    
    func getPendingArguments() -> [String] {
        var pendingArguments = ["status:Pending"]
        
        if let definedDefaultFilter = configuration!["pomodoro.defaultFilter"] {
            pendingArguments = [definedDefaultFilter] + pendingArguments
        }
        
        return pendingArguments
    }
    
    func getSortedTasks(_ tasks: [JSON]) -> [JSON] {
        var sortedTasks = tasks
        
        if let sortList = configuration!["pomodoro.default.sort"] {
            sortedTasks = sortTasks(sortedTasks, withList: sortList)
        }
        
        return sortedTasks
    }
    
    func sortTasks(_ tasks: [JSON], withList list: String) -> [JSON] {
        let theList = processSortingList(list)
        
        let sortedTasks = tasks.sorted {
            var sorted: Bool = false
            
            for (field, ascending) in theList {
                if $0[field].type == .null && $1[field].type == .null {
                    continue
                }
                if $0[field] == $1[field] {
                    continue
                }
                if $1[field].type == .null {
                    sorted = !ascending;
                    break
                }
                if $0[field].type == .null {
                    sorted = ascending;
                    break
                }
                
                if (ascending) {
                    sorted = $0[field] < $1[field];
                    break
                } else {
                    sorted = $0[field] > $1[field];
                    break
                }
            }
            
            return sorted
        }
        
        return sortedTasks
    }
    
    func processSortingList(_ list: String) -> [(String, Bool)] {
        var processedList = [(String, Bool)]()
        
        let rawList = list.split(separator: ",").map(String.init)
        for element in rawList {
            processedList.append(processSortFilter(element))
        }
        
        return processedList
    }
    
    func processSortFilter(_ sort: String) -> (String, Bool) {
        var sortAscending = true
        
        let noSolidus = sort.trimmingCharacters(in: CharacterSet(charactersIn: "\\/"))
        
        switch (noSolidus.last!) {
        case "+":
            sortAscending = true
        case "-":
            sortAscending = false
        default:
            sortAscending = true
        }
        
        let trimmedSort = noSolidus.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        
        return (trimmedSort, sortAscending)
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
            }.filter {
                $0 != JSON.null
        }
        
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
        task.arguments = overrides + arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        print("r> \(arguments)")
        let took = measure {
            task.launch()
            task.waitUntilExit()
        }
        print("-> \(took) s")
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        
        return output
    }
    
    func taskCommand(_ arguments: [String]) {
        let task = Process()
        task.launchPath = taskPath
        task.arguments = overrides + arguments
        
        print("n> \(arguments)")
        let took = measure {
            task.launch()
            task.waitUntilExit()
        }
        print("-> \(took) s")
        
    }
    
    func getPomodorosCountTitle() -> String? {
        var title = ""
        var pomsDone = 0
        var pomsActive = isActive() ? 1 : 0
        
        // Allow users to disable the pomodoro count display
        if let countDisplayString = configuration!["pomodoro.displayCount"] {
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
            action: #selector(TWMenu.stopActiveTask(_:)),
            keyEquivalent: "s"
        )
        stopItem.keyEquivalentModifierMask = .option
        stopItem.tag = kStopTaskMenuItemTag
        stopItem.target = self
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
        if let postCompletionCommand = configuration!["pomodoro.postCompletionCommand"] {
            let errorPipe = Pipe()
            let errorFile = errorPipe.fileHandleForReading
            
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "\(postCompletionCommand) \(taskId)"]
            task.standardError = errorPipe
            print("h> \(task.arguments ?? ["-"])")
            task.launch()
            task.waitUntilExit()
            
            let stderr = stringFromFileAndClose(errorFile)
            
            if task.terminationStatus != 0 {
                let alert: NSAlert = NSAlert();
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
        if activeTimer != nil {
            activeTimer!.invalidate()
            activeTimer = nil
        }
        
        let taskId = activeTaskId;
        
        stopActiveTask()
        logPomodoroForTaskDone(taskId)
        
        // create a User Notification
        let notification = NSUserNotification.init()
        notification.title = "Break time!"
        notification.informativeText = "You've completed your pomodoro."
        notification.userInfo = ["taskId": taskId!]
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.hasActionButton = true
        notification.actionButtonTitle = "Start Another"
        
        // Deliver the notification through the User Notification Center
        NSUserNotificationCenter.default.deliver(notification)
        
        runPostCompletionHooks(taskId!)
    }
    
    func logPomodoroForTaskDone(_ taskId: String?) {
        let uuid = taskId ?? ""
        
        if let logId = activeTaskPomodorosLogUUID {
            taskCommand([logId, "annotate", "\"Pomodoro uuid:\(uuid)\""])
        }
    }
    
    func setActiveTask(_ taskId: String) {
        if activeTaskId != nil {
            stopActiveTask()
        }
        startTaskById(taskId)
        
        if let configuredPomodoroDuration = configuration!["pomodoro.durationSeconds"] {
            if let configuredPomodoroDurationAsDouble = Double(configuredPomodoroDuration) {
                pomodoroDuration = configuredPomodoroDurationAsDouble
            }
        }
        
        activeTimer = Timer(timeInterval: pomodoroDuration, target: self, selector: #selector(TWMenu.timerExpired), userInfo: nil, repeats: false)
        RunLoop.current.add(activeTimer!, forMode: .commonModes)
        
        let now = Date()
        activeTimerEnds = now.addingTimeInterval(pomodoroDuration);
    }
    
    // MARK: - Actions
    @objc func setActiveTaskViaMenu(_ sender: AnyObject) {
        setActiveTask(sender.representedObject as! String)
    }
    
    @objc func updateTaskTimer() {
        let date = Date()
        
        let minutesFrom = activeTimerEnds?.minutesFrom(date) ?? 25
        let secondsFrom = (activeTimerEnds?.secondsFrom(date) ?? 1500) - minutesFrom * 60
        
        getStopTaskMenuItem().title = String(format: kStopTitleFormat, minutesFrom, secondsFrom)
    }
    
    @objc func exitNow(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
}

func measure(block: ()->()) -> TimeInterval {
    let then = Date()
    block()
    return then.timeIntervalSinceNow * -1000.0
}

enum FileError: Error {
    case fileNotFound(file_path: NSString)
    case fileEmpty
}

extension Date {
    func yearsFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.year, from: date, to: self, options: []).year!
    }
    
    func monthsFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.month, from: date, to: self, options: []).month!
    }
    
    func weeksFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.weekOfYear, from: date, to: self, options: []).weekOfYear!
    }
    
    func daysFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.day, from: date, to: self, options: []).day!
    }
    
    func hoursFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.hour, from: date, to: self, options: []).hour!
    }
    
    func minutesFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.minute, from: date, to: self, options: []).minute!
    }
    
    func secondsFrom(_ date: Date) -> Int {
        return (Calendar.current as NSCalendar).components(.second, from: date, to: self, options: []).second!
    }
    
    func offsetFrom(_ date: Date) -> String {
        if yearsFrom(date) > 0 {
            return "\(yearsFrom(date))y"
        }
        if monthsFrom(date) > 0 {
            return "\(monthsFrom(date))M"
        }
        if weeksFrom(date) > 0 {
            return "\(weeksFrom(date))w"
        }
        if daysFrom(date) > 0 {
            return "\(daysFrom(date))d"
        }
        if hoursFrom(date) > 0 {
            return "\(hoursFrom(date))h"
        }
        if minutesFrom(date) > 0 {
            return "\(minutesFrom(date))m"
        }
        if secondsFrom(date) > 0 {
            return "\(secondsFrom(date))s"
        }
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
    subscript(safe index: Int) -> Element? {
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
