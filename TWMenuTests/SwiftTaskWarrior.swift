//
//  SwiftTaskWarrior.swift
//  TWMenuTests
//
//  Created by Jarosław Wojtasik on 28/08/2018.
//  Copyright © 2018 Adam Coddington. All rights reserved.
//

import Foundation

public class SwiftTaskWarrior {
    // MARK - ### Fields ###
    let overrides: [String]
    let environment: [String: String]
    lazy var myCustomQueue = DispatchQueue(label: "task worker")
    
    public init (overrides: [String] = [], environment: [String: String] = [:] ) {
        self.overrides = overrides
        self.environment = environment
    }
    
    // MARK: - ### Public API ###
    public func add(description: String) -> Int? {
        return add([description])
    }
    
    public func add(_ raw: [String]) -> Int? {
        let out = run(filter: [], cmd: "add", params: raw, "")
        let id = out.components(separatedBy: .whitespaces).last?.trimmingCharacters(in: CharacterSet(charactersIn: ".\n"))
        return Int(id ?? "")
    }
    
    public func next() {
        _ = run(filter: [], cmd: "next", params: [], "")
    }
    
    public func config(key: String, val: String) {
        _ = run(filter: [], cmd: "config", params: ["\(key)", "\(val)"], "yes\n")
    }
    
    public func show() {
        _ = run(filter: [], cmd: "show", params: [], "yes\n")
    }
    
    public func log(_ raw: [String]) {
        _ = run(filter: [], cmd: "log", params: raw, "")
    }
    
    public func annotate(filter: [String], text: String) {
        _ = run(filter: filter, cmd: "annotate", params: [text], "")
    }
    
    public func uuids(filter: [String]) -> [String] {
        let uuids = run(filter: filter, cmd: "uuids", params: [], "")
        let list = uuids.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map { String($0) }
        return list
    }
    
    // MARK: - ### Private API ###
    func run(filter: [String], cmd: String, params: [String], _ input: String) -> String {
        let arguments: [String] = filter + [cmd] + self.overrides + params
        var output: String = ""
        let queueStart = Date()
        myCustomQueue.sync {
            let task = Process()
            task.launchPath = "/usr/local/bin/task"
            task.arguments = arguments
            print("-> task \(task.arguments?.joined(separator: " ") ?? "")")
            print("----------------")
            
            let oPipe = Pipe()
            let iPipe = Pipe()
            iPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
            
            task.standardOutput = oPipe
            task.standardInput = iPipe
            task.environment = self.environment
            task.launch()
            
            let before = Date()
            task.waitUntilExit()
            let took = before.timeIntervalSinceNow
            print("----------------")
            print(": \(-took * 1000) ms")
            let data = oPipe.fileHandleForReading.readDataToEndOfFile()
            output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
            print("^^^^^^^^^^^^")
            print(output)
            print("______")
        }
        print(": \(-queueStart.timeIntervalSinceNow * 1000) ms")
        return output
    }
    
//    func run(cmd: String, params: [String], _ block: @escaping (String)->()) {
//        run(cmd: cmd, params: params, input: "", block)
//    }
    
//    func run(cmd: String, params: [String], input: String, _ block: @escaping (String)->()) {
//        myCustomQueue.async {
//            let task = Process()
//            task.launchPath = "/usr/local/bin/task"
//            task.arguments = [cmd] + self.overrides + params
//            print("-> task \(task.arguments?.joined(separator: " ") ?? "")")
//            print("----------------")
//
//            let oPipe = Pipe()
//            let iPipe = Pipe()
//            iPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
//
//            task.standardOutput = oPipe
//            task.standardInput = iPipe
//            task.environment = self.environment
//            task.launch()
//
//            let before = Date()
//            task.waitUntilExit()
//            let took = before.timeIntervalSinceNow
//            print("----------------")
//            print(": \(-took * 1000) ms")
//            let data = oPipe.fileHandleForReading.readDataToEndOfFile()
//            let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
//            print("^^^^^^^^^^^^")
//            print(output)
//            print("______")
//            block(output)
//        }
//    }
}
