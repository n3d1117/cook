//
//  Logger.swift
//  cook
//
//  Created by ned on 05/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

struct Logger {
    
    enum LogLevel {
        case verbose, info, success, error
    }
    
    func log(_ level: LogLevel, _ message: String) {
        switch level {
        case .verbose: if CLI.verbose() { print("[⠇] \(message)") }
        case .info: print("[*] \(message)")
        case .success: print("[✓] \(message)")
        case .error: print("[ⅹ] \(message)")
        }
    }
}
