//
//  CLI.swift
//  cook
//
//  Created by ned on 04/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation

enum CLI {
    enum Argument: String, CaseIterable {
        
        // Authentication
        case appleId
        case password
        
        // Certificates
        case machinePrefix = "machine-name"
        case inputCsr = "input-csr"
        case outputPem = "output-pem"
        case outputP12 = "output-p12"
        case p12Password = "p12-password"
        
        // App ids
        case appName = "app-name"
        case appBundleId = "app-bundle-id"
        
        // Devices
        case deviceName = "name"
        case deviceUdid = "udid"
        
        // Provisioning profile
        case bundleId = "bundle-id"
        case outputProfile = "output-profile"
        case outputProfiles = "output-folder"
        
        // Resign ipa
        case ipaPath = "ipa"
        case outputIpaPath = "output-ipa"
        case inputP12 = "p12"
        
        // Anisette server
        case port = "port"
        case secret = "secret"
        case base64AnisetteData = "base64-anisette-data"
        
        func allowedInEnvironmentVariables() -> Bool {
            return self == .appleId || self == .password
        }
        
        func asEnvironmentVariable() -> String {
            switch self {
            case .appleId: return "COOK_APPLEID_EMAIL"
            case .password: return "COOK_APPLEID_PASSWORD"
            default: return ""
            }
        }
    }
    
    enum Recipe: String {
        case createCertificate = "create_certificate"
        case registerApp = "register_app"
        case registerDevice = "register_device"
        case updateProvisioningProfile = "update_profile"
        case downloadProvisioningProfiles = "download_profiles"
        case resignIpa = "resign"
        case anisetteServer = "anisette_server"
    }
    
    static func noArgumentsProvided() -> Bool {
        return CommandLine.arguments.count == 1
    }
    
    static func parseArgument(_ argument: Argument) -> String? {
        if argument.allowedInEnvironmentVariables() {
            if let environmentVariable = ProcessInfo.processInfo.environment[argument.asEnvironmentVariable()] {
                return environmentVariable
            } else {
                return UserDefaults.standard.string(forKey: "-" + argument.rawValue)
            }
        } else {
            return UserDefaults.standard.string(forKey: "-" + argument.rawValue)
        }
    }
    
    static func containsRecipe(_ recipe: Recipe) -> Bool {
        return CommandLine.arguments.contains(recipe.rawValue)
    }
    
    static func containsArgument(_ arg: Argument) -> Bool {
        return CommandLine.arguments.contains("--" + arg.rawValue)
    }
    
    static func help() -> Bool {
        return CommandLine.arguments.contains("-h") || CommandLine.arguments.contains("--help")
    }
    
    static func force() -> Bool {
        return CommandLine.arguments.contains("-f")
    }
    
    static func verbose() -> Bool {
        return CommandLine.arguments.contains("-v") || CommandLine.arguments.contains("--verbose")
    }
    
    static func outputAsJson() -> Bool {
        return CommandLine.arguments.contains("-j") || CommandLine.arguments.contains("--json")
    }
}
