//
//  Logger.swift
//  cook
//
//  Created by ned on 05/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation

struct Logger {
    
    enum LogLevel {
        case verbose, info, success, error
    }
    
    func json(from dictionary: [String: String]) {
        if let jsonData = try? JSONEncoder().encode(dictionary), let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    func log(_ level: LogLevel, _ message: String) {
        guard !outputAsJSON else { return }
        switch level {
        case .verbose: if CLI.verbose() { print("[⠇] \(message)") }
        case .info: print("[*] \(message)")
        case .success: print("[✓] \(message)")
        case .error: print("[ⅹ] \(message)")
        }
    }
}
