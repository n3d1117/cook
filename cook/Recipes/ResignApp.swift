//
//  ResignApp.swift
//  cook
//
//  Created by ned on 23/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct ResignApp: ExecutableRecipe {
    
    var ipaUrl: URL
    var outputIpaUrl: URL
    var machinePrefix: String
    var p12Path: String
    var p12Password: String
    var force: Bool
    
    var workingDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    
    init(ipaUrl: URL, outputIpaUrl: URL, p12Path: String, p12Password: String, machinePrefix: String, force: Bool) {
        self.ipaUrl = ipaUrl
        self.outputIpaUrl = outputIpaUrl
        self.machinePrefix = machinePrefix
        self.p12Path = p12Path
        self.p12Password = p12Password
        self.force = force
    }
    
    func execute() {
        
        logger.log(.verbose, "Working directory: \(workingDirectory.absoluteString)")

        do {
            try? FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true, attributes: nil)
            let appBundleURL = try FileManager.default.unzipAppBundle(at: ipaUrl, toDirectory: workingDirectory)
            guard let app = ALTApplication(fileURL: appBundleURL) else { return self.abort(ALTError(.invalidApp)) }
            
            logger.log(.verbose, "App name: \(app.name)")
            logger.log(.verbose, "App bundle identifier: \(app.bundleIdentifier)")
            
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
                        
                        self.fetchCertificate(team: team, session: session) { result in
                            switch result {
                            case .failure(let error): return self.abort(error)
                            case .success(let cert):
                                logger.log(.verbose, "Fetched certificate: \(cert)")
                                
                                logger.log(.info, "Fetching app ids...")
                                self.fetchAppId(team: team, session: session, appName: app.name, bundleId: app.bundleIdentifier) { result in
                                    switch result {
                                    case .failure(let error): return self.abort(error)
                                    case .success(let appId):
                                        
                                        logger.log(.info, "Fetching provisioning profile...")
                                        API.fetchProvisioningProfile(for: appId, team: team, session: session) { result in
                                            switch result {
                                            case .failure(let error): return self.abort(error)
                                            case .success(let profile):
                                                logger.log(.verbose, "Got profile: \(profile)...")
                                                
                                                logger.log(.info, "Resigning...")
                                                API.resignApp(app: app, team: team, certificate: cert, profile: profile) { result in
                                                    switch result {
                                                    case .failure(let error): return self.abort(error)
                                                    case .success(let success):
                                                        if success {
                                                            logger.log(.info, "App resigned successfully, repackaging...")
                                                            
                                                            let resignedIpaUrl = try! FileManager.default.zipAppBundle(at: appBundleURL)
                                                
                                                            if FileManager.default.fileExists(atPath: self.outputIpaUrl.path) {
                                                                try! FileManager.default.removeItem(at: self.outputIpaUrl)
                                                            }
                                                            try! FileManager.default.moveItem(at: resignedIpaUrl, to: self.outputIpaUrl)
                                                            
                                                            logger.log(.success, "Done! Resigned .ipa is at \(self.outputIpaUrl.path)")
                                                            
                                                            self.cleanWorkingDir()
                                                            return _success()
                                                        } else {
                                                            return self.abort(ResignError.failedToResign)
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
    
    fileprivate func cleanWorkingDir() {
        logger.log(.verbose, "cleaning up working dir: \(workingDirectory.absoluteString)...")
        try? FileManager.default.removeItem(at: workingDirectory)
    }
    
    fileprivate func abort(_ error: Error) {
        cleanWorkingDir()
        return _abort(error)
    }
    
    fileprivate func fetchCertificate(team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTCertificate, Error>) -> Void) {
        if !self.p12Path.isEmpty {
            logger.log(.info, "Using local p12 certificate...")
            let certUrl = URL(fileURLWithPath: p12Path)
            guard let encodedCertData = try? Data(contentsOf: certUrl) else { return self.abort(ResignError.invalidP12) }
            guard let cert = ALTCertificate(p12Data: encodedCertData, password: self.p12Password) else { return self.abort(ResignError.invalidP12) }
            completionHandler(.success(cert))
        } else {
            logger.log(.info, "Fetching certificates...")
            API.fetchCertificates(team: team, session: session) { result in
                switch result {
                case .failure(let error): completionHandler(.failure(error))
                case .success(let certs):
                    if let cert = certs.first(where: { $0.machineName?.hasPrefix(self.machinePrefix) ?? false }) {
                        if self.force {
                            logger.log(.info, "Certificate already exists, revoking...")
                            logger.log(.verbose, "Revoking certificate \(cert)...")
                            API.revokeCertificate(certificate: cert, team: team, session: session) { result in
                                switch result {
                                case .failure(let error): completionHandler(.failure(error))
                                case .success(let revoked):
                                    if revoked {
                                        logger.log(.info, "Certificate revoked successfully...")
                                        self.fetchCertificate(team: team, session: session, completionHandler: completionHandler)
                                    } else {
                                        logger.log(.verbose, "Certificate could not be revoked...")
                                        completionHandler(.failure(CertificateError.failedToRevoke))
                                    }
                                }
                            }
                        } else {
                            logger.log(.info, "Certificate already exists! Aborting... (Use -f to force revoke)")
                            return self.abort(CertificateError.certificateAlreadyExists)
                        }
                    } else {
                        logger.log(.info, "Creating certificate...")
                        API.createCertificate(machineName: self.machinePrefix, team: team, session: session) { result in
                            switch result {
                            case .failure(let error): completionHandler(.failure(error))
                            case .success(let certAdded):
                                let privateKey: Data? = certAdded.privateKey
                                API.fetchCertificates(team: team, session: session) { result in
                                    switch result {
                                    case .failure(let error): return self.abort(error)
                                    case .success(let certs):
                                        guard let cert = certs.first(where: { $0.machineName?.hasPrefix(self.machinePrefix) ?? false }) else { return self.abort(CertificateError.missingCertificate) }
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
    }
    
    fileprivate func fetchAppId(team: ALTTeam, session: ALTAppleAPISession, appName: String, bundleId: String, completionHandler: @escaping (Result<ALTAppID, Error>) -> Void) {
        API.fetchAppIds(team: team, session: session) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let appIds):
                if let appId = appIds.first(where: { $0.bundleIdentifier == bundleId }) {
                    logger.log(.info, "App id with bundle identifier '\(appId.bundleIdentifier)' exists!")
                    completionHandler(.success(appId))
                } else {
                    if !self.force {
                        logger.log(.info, "App id with bundle identifier '\(bundleId)' doesn't exist! Aborting... (Use -f to add it automatically)")
                        completionHandler(.failure(AppIdError.missingAppId))
                    } else {
                        logger.log(.info, "App id with bundle identifier '\(bundleId)' doesn't exist, adding...")
                        API.registerAppId(appName: appName, bundleIdentifier: bundleId, team: team, session: session) { result in
                            switch result {
                            case .failure(let error): completionHandler(.failure(error))
                            case .success(let appId):
                                logger.log(.info, "Added app id: \(appId)")
                                completionHandler(.success(appId))
                            }
                        }
                    }
                }
            }
        }
    }
}
