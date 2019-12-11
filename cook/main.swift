//
//  main.swift
//  ashketchum
//
//  Created by ned on 02/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation

let logger = Logger()
let auth = Authenticator(appleId: CLI.parseArgument(.appleId) ?? "", password: CLI.parseArgument(.password) ?? "")

func _abort(_ error: Error) {
    logger.log(.error, "\(error)\n")
    exit(EXIT_FAILURE)
}

func main() {

    if CLI.noArgumentsProvided() || CLI.help() {
        Utils.showHelp()
        exit(EXIT_SUCCESS)
    }
    
    let usesTheForce = CLI.force()

    // Create certificate
    if CLI.containsRecipe(.createCertificate) {
        logger.log(.info, "Recipe: create certificate")
        guard let inputCsrPath = CLI.parseArgument(.inputCsr) else { return _abort(UsageError.missingInputCSR) }
        guard var outputPemPath = CLI.parseArgument(.outputPem) else { return _abort(UsageError.missingOutputPEM) }
        outputPemPath = Utils.adjustOutputPath(from: outputPemPath, _extension: "pem")
        logger.log(.verbose, "Input CSR: \(inputCsrPath), output PEM: \(outputPemPath)")
        CreateCertificate(csrPath: inputCsrPath, pemPath: outputPemPath, force: usesTheForce).execute()
    }
    
    // Register app id
    else if CLI.containsRecipe(.registerApp) {
        logger.log(.info, "Recipe: register bundle id")
        guard let appName = CLI.parseArgument(.appName) else { return _abort(UsageError.missingAppName) }
        guard let appBundleId = CLI.parseArgument(.appBundleId) else { return _abort(UsageError.missingAppBundleId) }
        logger.log(.verbose, "App name: \(appName), bundle id: \(appBundleId)")
        RegisterBundleId(appName: appName, bundleId: appBundleId, force: usesTheForce).execute()
    }
    
    // Register device
    else if CLI.containsRecipe(.registerDevice) {
        logger.log(.info, "Recipe: register device")
        guard let name = CLI.parseArgument(.deviceName) else { return _abort(UsageError.missingDeviceName) }
        guard let udid = CLI.parseArgument(.deviceUdid) else { return _abort(UsageError.missingDeviceUdid) }
        logger.log(.verbose, "Device name: \(name), udid: \(udid)")
        RegisterDevice(name: name, udid: udid).execute()
    }
    
    // Update provisioning profile
    else if CLI.containsRecipe(.updateProvisioningProfile) {
        logger.log(.info, "Recipe: update provisioning profile")
        guard let bundleId = CLI.parseArgument(.bundleId) else { return _abort(UsageError.missingBundleId) }
        guard var outputProfile = CLI.parseArgument(.outputProfile) else { return _abort(UsageError.missingOutputProfile) }
        outputProfile = Utils.adjustOutputPath(from: outputProfile, _extension: "mobileprovision")
        logger.log(.verbose, "Bundle id: \(bundleId), output profile: \(outputProfile)")
        UpdateProvisioningProfile(bundleId: bundleId, outputPath: outputProfile, force: usesTheForce).execute()
    }
        
    // Download provisioning profiles
    else if CLI.containsRecipe(.downloadProvisioningProfiles) {
        logger.log(.info, "Recipe: download provisioning profiles")
        let bundleId = CLI.parseArgument(.bundleId) ?? ""
        guard let outputProfiles = CLI.parseArgument(.outputProfiles) else { return _abort(UsageError.missingOutputProfiles) }
        guard !outputProfiles.hasSuffix(".mobileprovision") else { return _abort(UsageError.outputMustBeAFolder) }
        logger.log(.verbose, "Bundle id: \(bundleId), output profiles: \(outputProfiles)")
        DownloadProvisioningProfiles(bundleId: bundleId, outputPath: outputProfiles).execute()
    }
    
    else {
        Utils.showHelp()
        exit(EXIT_FAILURE)
    }

}

main()

RunLoop.main.run()
