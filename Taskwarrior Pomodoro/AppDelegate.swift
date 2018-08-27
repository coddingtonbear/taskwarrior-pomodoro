//
//  AppDelegate.swift
//  Taskwarrior Pomodoro
//
//  Created by Adam Coddington on 12/5/15.
//  MIT Licensed
//

import Cocoa
import Darwin


let NSAlternateKeyMask = 1 << 19

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    lazy var twMenu = TWMenu()
    lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    // MARK: NSApplicationDelegate -
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.menu = twMenu.getMenu()
        
        if let button = statusItem.button {
            button.image = twMenu.image
        }
        
//        twMenu.refreshPendingTasks()
    }
}

