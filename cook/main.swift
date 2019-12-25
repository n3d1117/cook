//
//  main.swift
//  ashketchum
//
//  Created by ned on 02/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation

let logger = Logger()
let outputAsJSON = CLI.outputAsJson()
let auth = Authenticator(appleId: CLI.parseArgument(.appleId) ?? "", password: CLI.parseArgument(.password) ?? "")

func _abort(_ error: Error) {
    logger.log(.error, "\(error)")
    if outputAsJSON { logger.json(from: Utils.dictionaryForFailedResult(with: error)) }
    exit(EXIT_FAILURE)
}

func _success(_ JSONValues: [String: String] = [:]) {
    if outputAsJSON { logger.json(from: Utils.dictionaryForSuccess(with: JSONValues)) }
    exit(EXIT_SUCCESS)
}

func main() {

    if CLI.noArgumentsProvided() || CLI.help() {
        Utils.showHelp()
        return _success()
    }
    
    let f = CLI.force()

    // Create certificate
    if CLI.containsRecipe(.createCertificate) {
        logger.log(.info, "Recipe: create certificate")
        var machinePrefix = "", csr = "", pem = "", p12 = "", p12Password = "", usesPem = true
        if let prefix = CLI.parseArgument(.machinePrefix) {
            machinePrefix = prefix
            logger.log(.verbose, "Machine prefix: \(machinePrefix)")
        } else {
            machinePrefix = Utils.defaulMachinePrefix
        }
        if let inputCsr = CLI.parseArgument(.inputCsr) {
            csr = inputCsr
            logger.log(.verbose, "Input CSR: \(csr)")
        }
        if outputAsJSON {
            if CLI.containsArgument(.outputP12) {
                usesPem = false
                p12Password = CLI.parseArgument(.p12Password) ?? ""
            }
        } else if let outputPemPath = CLI.parseArgument(.outputPem) {
            pem = Utils.adjustOutputPath(from: outputPemPath, _extension: "pem")
            logger.log(.verbose, "Output PEM: \(pem)")
        } else if let outputP12Path = CLI.parseArgument(.outputP12) {
            p12 = Utils.adjustOutputPath(from: outputP12Path, _extension: "p12")
            p12Password = CLI.parseArgument(.p12Password) ?? ""
            usesPem = false
            logger.log(.verbose, "Output P12: \(p12), P12 password: \(p12Password)")
        } else {
            return _abort(UsageError.missingOutput)
        }
        CreateCertificate(machinePrefix: machinePrefix, csrPath: csr, pemPath: pem, p12Path: p12, p12Pass: p12Password, inputCsr: csr != "", usesPem: usesPem, force: f).execute()
    }
    
    // Register app id
    else if CLI.containsRecipe(.registerApp) {
        logger.log(.info, "Recipe: register bundle id")
        guard let appName = CLI.parseArgument(.appName) else { return _abort(UsageError.missingAppName) }
        guard let appBundleId = CLI.parseArgument(.appBundleId) else { return _abort(UsageError.missingAppBundleId) }
        logger.log(.verbose, "App name: \(appName), bundle id: \(appBundleId)")
        RegisterBundleId(appName: appName, bundleId: appBundleId, force: f).execute()
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
        var outputProfile = ""
        guard let bundleId = CLI.parseArgument(.bundleId) else { return _abort(UsageError.missingBundleId) }
        logger.log(.verbose, "Bundle id: \(bundleId)")
        if let out = CLI.parseArgument(.outputProfile) {
            outputProfile = Utils.adjustOutputPath(from: out, _extension: "mobileprovision")
            logger.log(.verbose, "Output profile: \(outputProfile)")
        } else {
            guard outputAsJSON else { return _abort(UsageError.missingOutputProfile) }
        }
        UpdateProvisioningProfile(bundleId: bundleId, outputPath: outputProfile, force: f).execute()
    }
        
    // Download provisioning profiles
    else if CLI.containsRecipe(.downloadProvisioningProfiles) {
        logger.log(.info, "Recipe: download provisioning profiles")
        let bundleId = CLI.parseArgument(.bundleId) ?? ""
        logger.log(.verbose, "Bundle id: \(bundleId)")
        var outputProfiles = ""
        if let out = CLI.parseArgument(.outputProfiles) {
            outputProfiles = out
            guard !outputProfiles.hasSuffix(".mobileprovision") else { return _abort(UsageError.outputMustBeAFolder) }
            logger.log(.verbose, "Output profiles: \(outputProfiles)")
        } else {
            guard outputAsJSON else { return _abort(UsageError.missingOutputProfiles) }
        }
        DownloadProvisioningProfiles(bundleId: bundleId, outputPath: outputProfiles).execute()
    }
        
    // Resign .ipa
    else if CLI.containsRecipe(.resignIpa) {
        logger.log(.info, "Recipe: resign ipa")
        var machinePrefix = "", p12Path = "", p12Password = "", outputIpaUrl: URL
        
        guard let ipaPath = CLI.parseArgument(.ipaPath) else { return _abort(UsageError.missingIpaPath) }
        guard ipaPath.hasSuffix(".ipa") else { return _abort(ResignError.ipaPathNotValid) }
        logger.log(.verbose, "ipa path: \(ipaPath)")
        let ipaUrl = URL(fileURLWithPath: ipaPath)
        
        if let outputIpaPath = CLI.parseArgument(.outputIpaPath) {
            guard outputIpaPath.hasSuffix(".ipa") else { return _abort(ResignError.outputIpaPathNotValid) }
            logger.log(.verbose, "output ipa path: \(outputIpaPath)")
            outputIpaUrl = URL(fileURLWithPath: outputIpaPath)
        } else {
            outputIpaUrl = ipaUrl
        }
        
        if let inputP12 = CLI.parseArgument(.inputP12) {
            guard inputP12.hasSuffix(".p12") else { return _abort(ResignError.certIsNotInP12Format) }
            p12Path = inputP12
            logger.log(.verbose, "Input P12: \(p12Path)")
            p12Password = CLI.parseArgument(.p12Password) ?? ""
            logger.log(.verbose, "P12 password: \(p12Password)")
        }
        
        if let prefix = CLI.parseArgument(.machinePrefix) {
            machinePrefix = prefix
            logger.log(.verbose, "Machine prefix: \(machinePrefix)")
        } else {
            machinePrefix = Utils.defaulMachinePrefix
        }

        ResignApp(ipaUrl: ipaUrl, outputIpaUrl: outputIpaUrl, p12Path: p12Path, p12Password: p12Password, machinePrefix: machinePrefix, force: f).execute()
    }
     
    // Install .ipa
    else if CLI.containsRecipe(.installIpa) {
        logger.log(.info, "Recipe: install ipa")
        
        guard let ipaPath = CLI.parseArgument(.ipaPath) else { return _abort(UsageError.missingIpaPath) }
        guard ipaPath.hasSuffix(".ipa") else { return _abort(ResignError.ipaPathNotValid) }
        logger.log(.verbose, "ipa path: \(ipaPath)")
        let ipaUrl = URL(fileURLWithPath: ipaPath)
        
        InstallApp(ipaUrl: ipaUrl).execute()
    }
        
    // Yoda!
    else if CLI.containsRecipe(.yoda) {
        logger.log(.info, "Recipe: yoda")
        
        guard let ipaPath = CLI.parseArgument(.ipaPath) else { return _abort(UsageError.missingIpaPath) }
        guard ipaPath.hasSuffix(".ipa") else { return _abort(ResignError.ipaPathNotValid) }
        logger.log(.verbose, "ipa path: \(ipaPath)")
        let ipaUrl = URL(fileURLWithPath: ipaPath)
        
        Yoda(ipaUrl: ipaUrl).execute()
    }
    
    else {
        Utils.showHelp()
        return _success()
    }

}

main()

RunLoop.main.run()
