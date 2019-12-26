//
//  Yoda.swift
//  cook
//
//  Created by ned on 25/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

struct Yoda: ExecutableRecipe {
    
    var ipaUrl: URL
    
    var workingDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("cook_" + UUID().uuidString)
    
    init(ipaUrl: URL) {
        self.ipaUrl = ipaUrl
    }
    
    func execute() {
        
        do {
            try? FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true, attributes: nil)
            let appBundleURL = try FileManager.default.unzipAppBundle(at: ipaUrl, toDirectory: workingDirectory)
            guard let app = ALTApplication(fileURL: appBundleURL) else { return self.abort(ALTError(.invalidApp)) }
            
            logger.log(.verbose, "App name: \(app.name)")
            logger.log(.verbose, "App bundle identifier: \(app.bundleIdentifier)")
            
            var devices: [ALTDevice] = ALTDeviceManager.shared.connectedDevices
            
            while devices.isEmpty {
                logger.log(.info, "No device connected, retrying in 3s...")
                sleep(3)
                devices = ALTDeviceManager.shared.connectedDevices
            }
            
            guard let device = devices.first else { return self.abort(InstallError.noConnectedDevice) }
            
            logger.log(.info, "Found '\(device.name)' with UDID: \(device.identifier)")
            
            auth.start()
            auth.completionHandler = { account, session, error in
                guard let account = account, let session = session else { return self.abort(error ?? AuthError.unknownAuthFailure) }
                logger.log(.verbose, "Successfully logged in! \(account)")
                
                logger.log(.info, "Fetching team...")
                API.fetchTeam(account: account, session: session) { result in
                    switch result {
                    case .failure(let error): return self.abort(error)
                    case .success(let team):
                        logger.log(.verbose, "Chose team: \(team)")
                        
                        logger.log(.info, "Registering device...")
                        self.register(device: device, team: team, session: session) { result in
                            switch result {
                            case .failure(let error): return self.abort(error)
                            case .success(_):
                                
                                logger.log(.info, "Fetching certificate...")
                                self.fetchCertificate(team: team, session: session) { result in
                                    switch result {
                                    case .failure(let error): return self.abort(error)
                                    case .success(let certificate):
                                        
                                        logger.log(.info, "Fetching app identifier...")
                                        self.fetchAppId(team: team, session: session, appName: app.name, identifier: app.bundleIdentifier) { result in
                                            switch result {
                                            case .failure(let error): return self.abort(error)
                                            case .success(let appId):
                                                
                                                logger.log(.info, "Updating features...")
                                                self.updateFeatures(for: appId, app: app, team: team, session: session) { result in
                                                    switch result {
                                                    case .failure(let error): return self.abort(error)
                                                    case .success(let appId):
                                                        
                                                        logger.log(.info, "Fetching provisioning profile...")
                                                        API.fetchProvisioningProfile(for: appId, team: team, session: session) { result in
                                                            switch result {
                                                            case .failure(let error): return self.abort(error)
                                                            case .success(let profile):
                                                                
                                                                logger.log(.info, "Resigning app...")
                                                                self.resign(app: app, team: team, cert: certificate, profile: profile) { result in
                                                                    switch result {
                                                                    case .failure(let error): return self.abort(error)
                                                                    case .success(let resigned):
                                                                        
                                                                        guard resigned else { return self.abort(ResignError.failedToResign) }
                                                                        
                                                                        logger.log(.info, "Installing...")
                                                                        API.installApp(at: app.fileURL, udid: device.identifier) { result in
                                                                            switch result {
                                                                            case .failure(let error): return self.abort(error)
                                                                            case .success(let installed):
                                                                                guard installed else { return self.abort(InstallError.failedToInstall) }
                                                                                self.cleanWorkingDir()
                                                                                logger.log(.success, "Done!")
                                                                                return _success()
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        
                                                    }
                                                }
                                                
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch let error {
            return self.abort(error)
        }
    }
    
    fileprivate func register(device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTDevice, Error>) -> Void) {
        logger.log(.verbose, "Fetching devices...")
        API.fetchDevices(team: team, session: session) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let devices):
                if let device = devices.first(where: { $0.identifier == device.identifier }) {
                    logger.log(.verbose, "Device is already registered!")
                    completionHandler(.success(device))
                } else {
                    logger.log(.verbose, "Registering device...")
                    API.registerDevice(name: device.name, udid: device.identifier, team: team, session: session) { result in
                        switch result {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success(let device):
                            logger.log(.verbose, "Device registered successfully!")
                            completionHandler(.success(device))
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func fetchCertificate(team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTCertificate, Error>) -> Void) {
        logger.log(.verbose, "Fetching certificates...")
        API.fetchCertificates(team: team, session: session) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let certs):
                if let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.defaulMachinePrefix) ?? false }) {
                    logger.log(.verbose, "Revoking certificate...")
                    API.revokeCertificate(certificate: cert, team: team, session: session) { result in
                        switch result {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success(let revoked):
                            if revoked {
                                logger.log(.verbose, "Certificate revoked successfully...")
                                self.fetchCertificate(team: team, session: session, completionHandler: completionHandler)
                            } else {
                                logger.log(.verbose, "Certificate could not be revoked...")
                                completionHandler(.failure(CertificateError.failedToRevoke))
                            }
                        }
                    }
                } else {
                    logger.log(.verbose, "Creating certificate...")
                    API.createCertificate(machineName: Utils.defaulMachinePrefix, team: team, session: session) { result in
                        switch result {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success(let certAdded):
                            let privateKey: Data? = certAdded.privateKey
                            API.fetchCertificates(team: team, session: session) { result in
                                switch result {
                                case .failure(let error): return self.abort(error)
                                case .success(let certs):
                                    guard let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.defaulMachinePrefix) ?? false && $0.serialNumber == certAdded.serialNumber }) else { return self.abort(CertificateError.missingCertificate) }
                                    cert.privateKey = privateKey
                                    completionHandler(.success(cert))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func fetchAppId(team: ALTTeam, session: ALTAppleAPISession, appName: String, identifier: String, completionHandler: @escaping (Result<ALTAppID, Error>) -> Void) {
        let bundleId = "com.\(team.identifier).\(identifier)"
        API.fetchAppIds(team: team, session: session) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let appIds):
                if let appId = appIds.first(where: { $0.bundleIdentifier == bundleId }) {
                    logger.log(.verbose, "App id with bundle identifier '\(bundleId)' exists!")
                    completionHandler(.success(appId))
                } else {
                    logger.log(.verbose, "App id with bundle identifier '\(bundleId)' doesn't exist, adding...")
                    API.registerAppId(appName: appName, bundleIdentifier: bundleId, team: team, session: session) { result in
                        switch result {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success(let appId):
                            logger.log(.verbose, "Added app id: \(appId)")
                            completionHandler(.success(appId))
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func updateFeatures(for appId: ALTAppID, app: ALTApplication, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTAppID, Error>) -> Void) {
        
        let requiredFeatures = app.entitlements.compactMap { (entitlement, value) -> (ALTFeature, Any)? in
            guard let feature = ALTFeature(entitlement: entitlement) else { return nil }
            return (feature, value)
        }
        
        var features = requiredFeatures.reduce(into: [ALTFeature: Any]()) { $0[$1.0] = $1.1 }
        
        if let applicationGroups = app.entitlements[.appGroups] as? [String], !applicationGroups.isEmpty {
            features[.appGroups] = true
        }
        
        let appId = appId.copy() as! ALTAppID
        appId.features = features
        
        API.updateAppId(appId: appId, team: team, session: session) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let appId): completionHandler(.success(appId))
            }
        }
    }
    
    fileprivate func resign(app: ALTApplication, team: ALTTeam, cert: ALTCertificate, profile: ALTProvisioningProfile, completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        
        let infoPlistURL = app.fileURL.appendingPathComponent("Info.plist")
        guard var infoDictionary = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else { completionHandler(.failure(ALTError(.missingInfoPlist)))
            return
        }
        infoDictionary[kCFBundleIdentifierKey as String] = profile.bundleIdentifier
        do {
            try (infoDictionary as NSDictionary).write(to: infoPlistURL)
        } catch let error {
            completionHandler(.failure(error))
        }
        
        API.resignApp(app: app, team: team, certificate: cert, profile: profile) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let success): completionHandler(.success(success))
            }
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
