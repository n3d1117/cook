//
//  DownloadProvisioningProfiles.swift
//  cook
//
//  Created by ned on 07/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct DownloadProvisioningProfiles: ExecutableRecipe {
    
    var optionalBundleId: String
    var outputPath: String
    
    init(bundleId: String, outputPath: String) {
        self.optionalBundleId = bundleId
        self.outputPath = outputPath
    }
    
    func execute() {
        auth.start()
        auth.completionHandler = { account, session, error in
            guard let account = account, let session = session else { return _abort(error ?? AuthError.unknownAuthFailure) }
            
            logger.log(.verbose, "Successfully logged in! \(account)")
            
            logger.log(.info, "Fetching team...")
            API.fetchTeam(account: account, session: session) { result in
                switch result {
                case .failure(let error): return _abort(error)
                case .success(let team):
                    logger.log(.verbose, "Chose team: \(team)")
                    
                    func saveAllProfiles(for appIds: [ALTAppID]) {
                        
                        let taskGroup = DispatchGroup()
                        var encodedProfiles: [String] = []
                        
                        for appId in appIds {
                            logger.log(.info, "Fetching mobileprovision...")
                            
                            taskGroup.enter()
                            API.fetchProvisioningProfile(for: appId, team: team, session: session) { result in
                                
                                defer { taskGroup.leave() }
                                
                                switch result {
                                case .failure(let error):
                                    logger.log(.info, "Failed to download one profile: \(error)")
                                case .success(let profile):
                                    logger.log(.verbose, "Saving mobileprovision...")
                                    logger.log(.verbose, "Expiration date: \(profile.expirationDate)")
                                    guard !profile.data.isEmpty else { return _abort(ProvisioningError.emptyData) }
                                    if outputAsJSON {
                                        encodedProfiles.append(profile.data.base64EncodedString())
                                    } else {
                                        let outputFilePath = Utils.adjustOutputPath(from: self.outputPath, _extension: "mobileprovision")
                                        Utils.save(data: profile.data, to: outputFilePath)
                                    }
                                }
                            }
                        }
                        
                        taskGroup.notify(queue: .main) {
                            if outputAsJSON {
                                var dict: [String: String] = [:]
                                dict["profiles_count"] = "\(encodedProfiles.count)"
                                for (index, profile) in encodedProfiles.enumerated() {
                                    dict["base64_profile_\(index+1)"] = profile
                                }
                                return _success(dict)
                            } else {
                                logger.log(.success, "Done! All profiles have been saved to \(self.outputPath)")
                                return _success()
                            }
                        }
                    }
                    
                    logger.log(.info, "Fetching app ids...")
                    API.fetchAppIds(team: team, session: session) { result in
                        switch result {
                        case .failure(let error): return _abort(error)
                        case .success(var appIds):
                            if appIds.isEmpty { return _abort(AppIdError.missingAppId) }
                            
                            if !self.optionalBundleId.isEmpty {
                                logger.log(.info, "Looking for a matching bundle id...")
                                guard let appId = appIds.first(where: { $0.bundleIdentifier == self.optionalBundleId }) else {
                                    return _abort(AppIdError.missingAppId)
                                }
                                appIds = [appId]
                            }
                            return saveAllProfiles(for: appIds)
                        }
                    }
                }
            }
        }
    }
}
