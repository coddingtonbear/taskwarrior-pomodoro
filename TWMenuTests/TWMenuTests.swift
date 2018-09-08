//
//  TWMenuTests.swift
//  TWMenuTests
//
//  Created by Jarosław Wojtasik on 27/08/2018.
//  Copyright © 2018 Adam Coddington. All rights reserved.
//

import XCTest
import TWMenu

class TWMenuTests: XCTestCase {
    lazy var tw = TWMenu(arguments: ["rc.data.location=task"], config: "taskrc")
    lazy var menu = tw.menu
    lazy var war = SwiftTaskWarrior(overrides: ["rc.data.location=task"], environment: ["TASKRC": "taskrc"])
    
    override func setUp() {
        super.setUp()
        
        war.show("nag")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(atPath: "task")
        try? FileManager.default.removeItem(atPath: "taskrc")
        super.tearDown()
    }
    
    func testEmptyDataOverride() {
        // Having
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .separator,
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testSimpleTasks() {
        // Having
        _ = addTwoSimpleTasks()
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testFiltering() {
        // Having
        war.config(key: "pomodoro.defaultFilter", val: "-BLOCKED +next")
        
        // add tasks
        guard let id = war.add(["blocker taks 01", "+next"]) else { XCTFail(); return }
        _ = war.add(["blocked task 01", "+next", "depend:\(id)"])
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .separator,
            .enabled("blocker taks 01"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    lazy var pomodoroLogUUID: String = {
        war.log(["PomodoroLog"])
        return war.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
    }()
    
    func testPomsLoggedAndStopped() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids)
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]

        checkMenu(menu, properResults)
    }
    
    func testPomsLoggedWithLongBreakAndStopped() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids, repeat: 3)
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅🍅🍅-🍅🍅"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testPomsLoggedAndActive() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids)
        
        // When
        tw.menuWillOpen(menu)
        tw.select(item: By(title: "simple task no 2"))
        tw.update()
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅🍊"),
            .separator,
            .disabled("Active:  simple task no 2"),
            .enabled("Stop (24:59 remaining)"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testStoppingTaskEarly() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids)
        
        // When
        tw.menuWillOpen(menu)
        tw.select(item: By(title: "simple task no 2"))
        tw.stop()
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testSwitchingIntoAnotherTask() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids)
        
        // When
        tw.menuWillOpen(menu)
        tw.select(item: By(title: "simple task no 2"))
        tw.select(item: By(title: "simple task no 1"))
        tw.update()
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅🍊"),
            .separator,
            .disabled("Active:  simple task no 1"),
            .enabled("Stop (24:59 remaining)"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testFullPomDone() {
        // Having
        let uuids = addTwoSimpleTasks()
        log(tasks: uuids)
        
        // When
        war.config(key: "pomodoro.durationSeconds", val: "1")
        tw.menuWillOpen(menu)
        tw.select(item: By(title: "simple task no 2"))
        tw.timerExpired()
        tw.menuWillOpen(menu)
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅🍅"),
            .separator,
            .enabled("simple task no 1"),
            .enabled("simple task no 2"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    // MARK: - workers
    func addTwoSimpleTasks() -> [String] {
        let ids = add(tasks: ["simple task no 1", "simple task no 2"])
        
        return war.uuids(filter: ids.map { String($0) } )
    }
    
    func add(tasks: [String]) -> [Int] {
        return tasks.map { war.add(description: $0)! }
    }
    
    func log(tasks uuids: [String], repeat count: Int = 1) {
        for _ in 0..<count {
            war.annotate(filter: [pomodoroLogUUID], text: "Pomodoro uuid:\(uuids[0])")
            war.annotate(filter: [pomodoroLogUUID], text: "Pomodoro uuid:\(uuids[1])")
        }
    }
    
    func checkMenu(_ menu: NSMenu, _ properResults: [MenuIemTypes]) {
        let visible = menu.items.filter { !$0.isHidden }
        guard visible.count == properResults.count else { XCTFail(); return }
        present(items: menu.items)
        
        for entry in zip(visible, properResults) {
            XCTAssertEqual(entry.1.isEnabled, entry.0.isEnabled, "is enabled")
            XCTAssertEqual(entry.1.isSeparatorItem, entry.0.isSeparatorItem, "is separator")
            if (!entry.0.isSeparatorItem) {
                XCTAssertEqual(entry.1.title, entry.0.title)
            }
        }
    }
    
    enum MenuIemTypes {
        case enabled(String)
        case disabled(String)
        case separator
        
        var isEnabled: Bool {
            switch self {
            case .enabled(_):
                return true
            case .disabled(_), .separator:
                return false
            }
        }
        
        var isSeparatorItem: Bool {
            switch self {
            case .separator:
                return true
            case .disabled(_), .enabled(_):
                return false
            }
        }
        
        var title: String {
            switch self {
            case .separator:
                return ""
            case .disabled(let text), .enabled(let text):
                return text
            }
        }
    }
}

extension TWMenu {
    func select(item by: By) {
        let task = get(item: by)
        self.setActiveTaskViaMenu(task)
    }
    
    func stop() {
        let stop = get(item: By(titleStart: "Stop"))
        self.stopActiveTask(stop)
    }
    
    func get(item by: By) -> NSMenuItem {
        switch (by) {
        case .title(let itemName):
            return self.menu.items.filter { $0.title == itemName }.first!
        case .titleStart(let itemName):
            return self.menu.items.filter { $0.title.starts(with: itemName) }.first!
        }
    }
    
    func update() {
        self.updateTaskTimer()
    }
}

enum By {
    init (title a: String) { self = .title(a) }
    init (titleStart a: String) { self = .titleStart(a) }
    
    case title(String)
    case titleStart(String)
}

extension NSMenu {
    func print() {
        present(items: self.items)
    }
}

func present(items: [NSMenuItem]) {
    let visible = items.filter { !$0.isHidden }
    print("")
    for entry in visible {
        present(entry: entry)
    }
    print("")
}

func `present`(entry: NSMenuItem) {
    let e = entry.isEnabled ? "E":"D"
    let title = entry.isSeparatorItem ? "---------------------":entry.title
    print("- \(e) \(title) \(e)")
}
