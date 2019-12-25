//
//  InstallApp.swift
//  cook
//
//  Created by ned on 25/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//
struct InstallApp: ExecutableRecipe {
    
    var ipaUrl: URL
    
    var workingDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    
    init(ipaUrl: URL) {
        self.ipaUrl = ipaUrl
    }
    
    func execute() {
        
        do {
            
            var devices: [ALTDevice] = ALTDeviceManager.shared.connectedDevices
            
            while devices.isEmpty {
                logger.log(.info, "No device connected, retrying in 3s...")
                sleep(3)
                devices = ALTDeviceManager.shared.connectedDevices
            }
            
            guard let device = devices.first else { return self.abort(InstallError.noConnectedDevice) }
            
            logger.log(.info, "Found '\(device.name)' with UDID: \(device.identifier)")

            try? FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true, attributes: nil)
            let appBundleURL = try FileManager.default.unzipAppBundle(at: ipaUrl, toDirectory: workingDirectory)
            guard let app = ALTApplication(fileURL: appBundleURL) else { return self.abort(ALTError(.invalidApp)) }
            
            logger.log(.info, "Installing...")
            
            API.installApp(at: app.fileURL, udid: device.identifier) { result in
                switch result {
                case .failure(let error): return self.abort(error)
                case .success(let success):
                    if success {
                        logger.log(.success, "App installed correctly!")
                        self.cleanWorkingDir()
                        return _success()
                    } else {
                        logger.log(.error, "Failed to install app")
                        return self.abort(InstallError.failedToInstall)
                    }
                }
            }
        } catch let error {
            return self.abort(error)
        }
    }
    
    fileprivate func cleanWorkingDir() {
        logger.log(.verbose, "cleaning up working dir: \(workingDirectory.absoluteString)...")
        try? FileManager.default.removeItem(at: workingDirectory)
    }
    
    fileprivate func abort(_ error: Error) {
        cleanWorkingDir()
        return _abort(error)
    }
}
