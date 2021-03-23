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
    
    static let defaulMachinePrefix: String = "cook"
    
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
    
    static func dictionaryForFailedResult(with error: Error) -> [String: String] {
        return ["success": "0", "error": "\(error)"]
    }
    
    static func dictionaryForSuccess(with values: [String: String]) -> [String: String] {
        var dict: [String: String] = ["success": "1"]
        for (key, value) in values {
            dict[key] = value
        }
        return dict
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
        print("#\n#  \(binaryName()) | made with ♡ by ned\n#  https://github.com/n3d1117/cook\n#\n")
    }
    
    static func showHelp() {
        header()
        print("Usage: ./\(binaryName()) [AUTHENTICATION] [RECIPE] [RECIPE_ARGUMENTS]\n")
        print("  -h, --help              prints usage information")
        print("  -v, --verbose           enables verbose mode")
        print("  -j, --json              use json output (all --output-* args are ignored in this mode)\n")
        print("Authentication:\n")
        print("  To authenticate pass the following arguments to any recipe:")
        print("    --appleId             Apple ID Email")
        print("    --password            Apple ID Password\n")
        print("    --2fa-code            Two Factor Authentication code\n")
        print("  or, if you prefer, you can set these environment variables:")
        print("    COOK_APPLEID_EMAIL")
        print("    COOK_APPLEID_PASSWORD\n")
        print("Recipes:\n")
        print("  1) create_certificate   Create certificate with arguments:\n")
        print("    --machine-name        Optional machine name (defaults to 'cook')")
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
        print("    --output-folder       Directory where to save the profiles\n")
        print("  5) resign               Resign ipa file with arguments:\n")
        print("    --ipa                 Path to .ipa file to resign")
        print("    --output-ipa          Optional path to resigned ipa (if not specified, original is overwritten)")
        print("    --p12                 Optional path to P12 certificate to use for resigning")
        print("    --p12-password        Optional P12 password")
        print("    --machine-name        Optional machine name to use when adding certificate (defaults to 'cook', ignored if --p12 is specified)")
        print("    -f                    Revoke certificate (if --p12 is not specified) if needed, register app id if needed\n")
        print("Possible JSON Responses (--json flag):\n")
        print("   'success':             '0' or '1'")
        print("   'error':               Error description (if success is 0)\n")
        print(" create_certificate recipe")
        print("   'pem_cert':            Plain text PEM cert")
        print("   'base64_p12_cert':     Base 64 encoded P12 cert")
        print("   'p12_password':        Plain text P12 password\n")
        print(" update_profile recipe")
        print("   'base64_profile':      Base 64 encoded mobileprovision\n")
        print(" download_profiles recipe")
        print("   'profiles_count':      Number of profiles downloaded")
        print("   'base64_profile_i':    i-th base 64 encoded mobileprovision (0<i<=profiles_count)\n")
        print("SERVER MODE: Listen to a specific port and respond with freshly generated base64 encoded anisette data:\n")
        print("  - Usage: ./\(binaryName()) anisette_server --port 8080 --secret some_custom_secret")
        print("  - Then 127.0.0.1:8080/some_custom_secret returns the following json: {'base64_encoded_data':'data', 'success':'1'}")
        print("  - You can then do ./\(binaryName()) [usual_args] --base64-anisette-data 'data' to use custom anisette data in your requests.\n")
    }
}
