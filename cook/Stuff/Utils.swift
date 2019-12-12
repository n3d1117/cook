//
//  Utils.swift
//  cook
//
//  Created by ned on 05/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation

func delay(_ delay: Double, closure: @escaping () -> Void) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}

protocol ExecutableRecipe {
    func execute()
}

enum Utils {
    
    static let machinePrefix: String = "appdb - "
    
    static func binaryName() -> String {
        guard let fullName = CommandLine.arguments.first else { return "cook" }
        return fullName.components(separatedBy: "/").last ?? "cook"
    }
    
    static func save(data: Data, to path: String) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
        } catch let error {
            return _abort(error)
        }
    }
    
    static func adjustOutputPath(from path: String, _extension: String) -> String {
        var output: String = path
        if !path.hasSuffix("." + _extension) {
            let suffix: String = "\(UUID().uuidString)." + _extension
            if path.hasSuffix("/") {
                output = path + suffix
            } else {
                output = path + "/" + suffix
            }
        }
        return output
    }
    
    @discardableResult
    static func shell(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
    
    static func header() {
        print("#\n# \(binaryName()) | by ned\n# https://github.com/n3d1117/cook\n#\n")
    }

    static func showHelp() {
        header()
        print("Usage: ./\(binaryName()) [AUTH] [RECIPE]\n")
        print("  -h, --help              prints usage information")
        print("  -v, --verbose           enables verbose mode\n")
        print("Authentication:\n")
        print("  To authenticate pass the following arguments to any recipe:")
        print("    --appleId             Apple ID Email")
        print("    --password            Apple ID Password\n")
        print("  or, if you prefer, you can set these environment variables:")
        print("    COOK_APPLEID_EMAIL")
        print("    COOK_APPLEID_PASSWORD\n")
        print("Recipes:\n")
        print("  1) create_certificate   Create certificate with arguments:\n")
        print("    --input-csr           Optional path to CSR file")
        print("    --output-pem          Path/Directory where to save output PEM file")
        print("    --output-p12          Path/Directory where to save output p12 file")
        print("    --p12-password        Optional P12 password, defaults to blank")
        print("    -f                    Force certificate revocation if needed\n")
        print("  2) register_app         Register app with arguments:\n")
        print("    --app-name            App name to register")
        print("    --app-bundle-id       Bundle identifier to register")
        print("    -f                    Force removal of previous app if needed\n")
        print("  3) register_device      Register device with arguments:\n")
        print("    --name                Device name (use quotes if it contains spaces)")
        print("    --udid                Device udid\n")
        print("  4) update_profile       Update & download provisioning profile with arguments:\n")
        print("    --bundle-id           Bundle identifier of the app")
        print("    --output-profile      Path/Directory where to save updated profile")
        print("    -f                    Force remove app ID and then readd it\n")
        print("  5) download_profiles    Download provisioning profiles with arguments:\n")
        print("    --bundle-id           Optional, to specify an app's identifier (defaults to all apps)")
        print("    --output-folder       Directory where to save the profiles\n\n")
    }
}
