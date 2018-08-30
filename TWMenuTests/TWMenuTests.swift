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
    lazy var tw = TWMenu(arguments: ["rc.data.location=task"])
    lazy var menu = tw.getMenu("taskrc")
    lazy var task = SwiftTaskWarrior(overrides: ["rc.data.location=task"], environment: ["TASKRC": "taskrc"])
    
    override func setUp() {
        super.setUp()
        
        task.show()
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
        let properResults = [
            (enabled: false, separator: true, ""),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
        present(items: menu.items)
    }
    
    func testSimpleTasks() {
        // Having
        _ = task.add(description: "simple task no 1")
        _ = task.add(description: "simple task no 2")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)
        
        let properResults = [
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "simple task no 1"),
            (enabled: true,  separator: false, "simple task no 2"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testFiltering() {
        // Having
        task.config(key: "pomodoro.defaultFilter", val: "-BLOCKED +next")
        
        // add tasks
        guard let id = task.add(["blocker taks 01", "+next"]) else { XCTFail(); return }
        _ = task.add(["blocked task 01", "+next", "depend:\(id)"])
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)
        let properResults = [
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "blocker taks 01"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testPomsLoggedAndStopped() {
        // Having
        guard let id1 = task.add(description: "simple task no 1") else { XCTFail(); return }
        guard let id2 = task.add(description: "simple task no 2") else { XCTFail(); return }
        task.log(["PomodoroLog"])
        let uuid = task.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
        let uuid1 = task.uuids(filter: ["\(id1)"]).first!
        let uuid2 = task.uuids(filter: ["\(id2)"]).first!
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)

        let properResults = [
            (enabled: false, separator: false, "🍅🍅"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "simple task no 1"),
            (enabled: true,  separator: false, "simple task no 2"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "Quit Taskwarrior Pomodoro")
        ]

        checkMenu(menu, properResults)
    }
    
    func testPomsLoggedWithLongBreakAndStopped() {
        // Having
        guard let id1 = task.add(description: "simple task no 1") else { XCTFail(); return }
        guard let id2 = task.add(description: "simple task no 2") else { XCTFail(); return }
        task.log(["PomodoroLog"])
        let uuid = task.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
        let uuid1 = task.uuids(filter: ["\(id1)"]).first!
        let uuid2 = task.uuids(filter: ["\(id2)"]).first!
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        task.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)
        
        let properResults = [
            (enabled: false, separator: false, "🍅🍅🍅🍅-🍅🍅"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "simple task no 1"),
            (enabled: true,  separator: false, "simple task no 2"),
            (enabled: false, separator: true, ""),
            (enabled: true,  separator: false, "Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    // MARK: - workers
    func present(items: [NSMenuItem]) {
        let visible = menu.items.filter { !$0.isHidden }
        print("")
        for entry in visible {
            present(entry: entry)
        }
        print("")
    }
    
    func checkMenu(_ menu: NSMenu, _ properResults: [(enabled: Bool, separator: Bool, title: String)]) {
        let visible = menu.items.filter { !$0.isHidden }
        guard visible.count == properResults.count else { XCTFail(); return }
        
        for entry in zip(visible, properResults) {
            XCTAssertEqual(entry.1.enabled, entry.0.isEnabled, "is enabled")
            XCTAssertEqual(entry.1.separator, entry.0.isSeparatorItem, "is separator")
            if (!entry.0.isSeparatorItem) {
                XCTAssertEqual(entry.1.title, entry.0.title)
            }
        }
    }
    
    func `present`(entry: NSMenuItem) {
        let e = entry.isEnabled ? "E":"D"
        let title = entry.isSeparatorItem ? "---------------------":entry.title
        print("- \(e) \(title) \(e)")
    }
    
}
