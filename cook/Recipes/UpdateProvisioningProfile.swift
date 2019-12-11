//
//  UpdateProvisioningProfile.swift
//  cook
//
//  Created by ned on 06/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct UpdateProvisioningProfile: ExecutableRecipe {
    
    var bundleId: String
    var outputPath: String
    var force: Bool
    
    init(bundleId: String, outputPath: String, force: Bool) {
        self.bundleId = bundleId
        self.outputPath = outputPath
        self.force = force
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
                    
                    logger.log(.info, "Fetching app ids...")
                    API.fetchAppIds(team: team, session: session) { result in
                        switch result {
                        case .failure(let error): return _abort(error)
                        case .success(let appIds):
                            if let appId = appIds.first(where: { $0.bundleIdentifier == self.bundleId }) {
                                logger.log(.info, "App id with bundle identifier \(self.bundleId) exists!")
                                
                                func save(from appId: ALTAppID) {
                                    logger.log(.info, "Fetching mobileprovision...")
                                    API.fetchProvisioningProfile(for: appId, team: team, session: session) { result in
                                        switch result {
                                        case .failure(let error): return _abort(error)
                                        case .success(let profile):
                                            logger.log(.verbose, "Saving mobileprovision...")
                                            logger.log(.verbose, "Expiration date: \(profile.expirationDate)")
                                            guard !profile.data.isEmpty else { return _abort(ProvisioningError.emptyData) }
                                            Utils.save(data: profile.data, to: self.outputPath)
                                            logger.log(.success, "Done! Saved mobileprovision to \(self.outputPath)")
                                            exit(EXIT_SUCCESS)
                                        }
                                    }
                                }
                                
                                if self.force {
                                    
                                    logger.log(.info, "Forcing removal...")
                                    API.deleteAppId(appId: appId, team: team, session: session) { result in
                                        switch result {
                                        case .failure(let error): return _abort(error)
                                        case .success(let deleted):
                                            if deleted {
                                                logger.log(.verbose, "App id removed successfully, adding it...")
                                                
                                                API.registerAppId(appName: appId.name, bundleIdentifier: appId.bundleIdentifier, team: team, session: session) { result in
                                                    switch result {
                                                    case .failure(let error): return _abort(error)
                                                    case .success(let appId):
                                                        logger.log(.info, "Added app id!")
                                                        return save(from: appId)
                                                    }
                                                }
                                            } else {
                                                logger.log(.error, "Failed to delete app id")
                                                exit(EXIT_FAILURE)
                                            }
                                        }
                                    }
                                    
                                } else {
                                    logger.log(.info, "Renewing app id...")
                                    API.updateAppId(appId: appId, team: team, session: session) { result in
                                        switch result {
                                        case .failure(let error): return _abort(error)
                                        case .success(let appId):
                                            logger.log(.info, "Renewed app id!")
                                            return save(from: appId)
                                        }
                                    }
                                }
                            } else {
                                logger.log(.error, "App id with bundle identifier \(self.bundleId) does not exist!")
                                exit(EXIT_FAILURE)
                            }
                        }
                    }
                    
                }
            }
        }
    }
}
