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
        present(items: menu.items)
    }
    
    func testSimpleTasks() {
        // Having
        _ = war.add(description: "simple task no 1")
        _ = war.add(description: "simple task no 2")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)
        
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
        present(items: menu.items)
        let properResults: [MenuIemTypes] = [
            .separator,
            .enabled("blocker taks 01"),
            .separator,
            .enabled("Quit Taskwarrior Pomodoro")
        ]
        
        checkMenu(menu, properResults)
    }
    
    func testPomsLoggedAndStopped() {
        // Having
        guard let id1 = war.add(description: "simple task no 1") else { XCTFail(); return }
        guard let id2 = war.add(description: "simple task no 2") else { XCTFail(); return }
        war.log(["PomodoroLog"])
        let uuid = war.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
        let uuid1 = war.uuids(filter: ["\(id1)"]).first!
        let uuid2 = war.uuids(filter: ["\(id2)"]).first!
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)

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
        guard let id1 = war.add(description: "simple task no 1") else { XCTFail(); return }
        guard let id2 = war.add(description: "simple task no 2") else { XCTFail(); return }
        war.log(["PomodoroLog"])
        let uuid = war.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
        let uuid1 = war.uuids(filter: ["\(id1)"]).first!
        let uuid2 = war.uuids(filter: ["\(id2)"]).first!
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        
        // When
        tw.menuWillOpen(menu)
        
        // Then
        present(items: menu.items)
        
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
        guard let id1 = war.add(description: "simple task no 1") else { XCTFail(); return }
        guard let id2 = war.add(description: "simple task no 2") else { XCTFail(); return }
        war.log(["PomodoroLog"])
        let uuid = war.uuids(filter: ["status:Completed", "PomodoroLog", "entry:today", "limit:1"]).first!
        let uuid1 = war.uuids(filter: ["\(id1)"]).first!
        let uuid2 = war.uuids(filter: ["\(id2)"]).first!
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid1)")
        war.annotate(filter: [uuid], text: "Pomodoro uuid:\(uuid2)")
        
        // When
        tw.menuWillOpen(menu)
        let items: [NSMenuItem] = menu.items
        let filtered: [NSMenuItem] = items.filter { !$0.isHidden }.map { $0 as NSMenuItem }
        let item = filtered[3]
        tw.setActiveTaskViaMenu( item )
        
        // Then
        present(items: menu.items)
        
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
    
    // MARK: - workers
    func present(items: [NSMenuItem]) {
        let visible = menu.items.filter { !$0.isHidden }
        print("")
        for entry in visible {
            present(entry: entry)
        }
        print("")
    }
    
    func checkMenu(_ menu: NSMenu, _ properResults: [MenuIemTypes]) {
        let visible = menu.items.filter { !$0.isHidden }
        guard visible.count == properResults.count else { XCTFail(); return }
        
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
    
    func `present`(entry: NSMenuItem) {
        let e = entry.isEnabled ? "E":"D"
        let title = entry.isSeparatorItem ? "---------------------":entry.title
        print("- \(e) \(title) \(e)")
    }
    
}
