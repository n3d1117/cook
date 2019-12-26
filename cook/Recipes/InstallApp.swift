//
//  InstallApp.swift
//  cook
//
//  Created by ned on 25/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//
struct InstallApp: ExecutableRecipe {
    
    var ipaUrl: URL

    init(ipaUrl: URL) {
        self.ipaUrl = ipaUrl
    }
    
    func execute() {
        
        var devices: [ALTDevice] = ALTDeviceManager.shared.connectedDevices
        
        while devices.isEmpty {
            logger.log(.info, "No device connected, retrying in 3s...")
            sleep(3)
            devices = ALTDeviceManager.shared.connectedDevices
        }
        
        guard let device = devices.first else { return _abort(InstallError.noConnectedDevice) }
        
        logger.log(.info, "Found '\(device.name)' with UDID: \(device.identifier)")

        logger.log(.info, "Installing...")
        
        API.installApp(at: ipaUrl, udid: device.identifier) { result in
            switch result {
            case .failure(let error): return _abort(error)
            case .success(let success):
                if success {
                    logger.log(.success, "App installed correctly!")
                    return _success()
                } else {
                    logger.log(.error, "Failed to install app")
                    return _abort(InstallError.failedToInstall)
                }
            }
        }
    }
}
