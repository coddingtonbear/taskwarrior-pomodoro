//
//  TWMenuTests.swift
//  TWMenuTests
//
//  Created by Jarosław Wojtasik on 27/08/2018.
//  Copyright © 2018 Adam Coddington. All rights reserved.
//

import XCTest
@testable import TWMenu

class TWMenuTests: XCTestCase {
    lazy var tw = TWMenu(arguments: ["rc.data.location=task"])
    lazy var menu = tw.getMenu("taskrc")
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
        let menu = tw.getMenu("task")
        
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
        log(tasks: uuids, count: 1)
        
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
        log(tasks: uuids, count: 3)
        
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
        log(tasks: uuids, count: 1)
        
        // When
        tw.menuWillOpen(menu)
        let taskItem = menu.items.filter { $0.title == "simple task no 2" }.first!
        tw.setActiveTaskViaMenu( taskItem )
        
        // Then
        let properResults: [MenuIemTypes] = [
            .disabled("🍅🍅🍊"),
            .separator,
            .disabled("Active:  simple task no 2"),
            .enabled("Stop (25:00 remaining)"),
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
        log(tasks: uuids, count: 1)
        
        // When
        tw.menuWillOpen(menu)
        // - Activate
        let taskItem = menu.items.filter { $0.title == "simple task no 2" }.first!
        tw.setActiveTaskViaMenu( taskItem )
        
        // - Stop
        menu.print()
        let stopItem = menu.items.filter { $0.title.starts(with: "Stop") }.first!
        tw.stopActiveTask( stopItem )
        
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
    
    // MARK: - workers
    func addTwoSimpleTasks() -> [String] {
        let ids = add(tasks: ["simple task no 1", "simple task no 2"])
        
        return war.uuids(filter: ids.map { String($0) } )
    }
    
    func add(tasks: [String]) -> [Int] {
        return tasks.map { war.add(description: $0)! }
    }
    
    func log(tasks uuids: [String], count: Int) {
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
