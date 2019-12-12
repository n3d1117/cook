//
//  RegisterBundleId.swift
//  cook
//
//  Created by ned on 05/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct RegisterBundleId: ExecutableRecipe {
    
    var appName: String
    var bundleId: String
    var force: Bool
    
    init(appName: String, bundleId: String, force: Bool) {
        self.appName = appName
        self.bundleId = bundleId
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
                    
                    func register() {
                        logger.log(.info, "Registering app id...")
                        API.registerAppId(appName: self.appName, bundleIdentifier: self.bundleId, team: team, session: session) { result in
                            switch result {
                            case .failure(let error): return _abort(error)
                            case .success(let appId):
                                logger.log(.success, "Added app id: \(appId)")
                                exit(EXIT_SUCCESS)
                            }
                        }
                    }
                    
                    logger.log(.info, "Fetching app ids...")
                    API.fetchAppIds(team: team, session: session) { result in
                        switch result {
                        case .failure(let error): return _abort(error)
                        case .success(let appIds):
                            if let appId = appIds.first(where: { $0.bundleIdentifier == self.bundleId }) {
                                logger.log(.info, "App id with bundle identifier \(self.bundleId) already exists!")
                                if self.force {
                                    
                                    logger.log(.info, "Forcing removal...")
                                    API.deleteAppId(appId: appId, team: team, session: session) { result in
                                        switch result {
                                        case .failure(let error): return _abort(error)
                                        case .success(let deleted):
                                            if deleted {
                                                logger.log(.verbose, "App id removed successfully, resistering...")
                                                return register()
                                            } else {
                                                logger.log(.error, "Failed to delete app id")
                                                return _abort(AppIdError.failedToDeleteAppId)
                                            }
                                        }
                                    }
                                    
                                } else {
                                    logger.log(.success, "Nothing to do, exiting... (use -f to force delete)")
                                    exit(EXIT_SUCCESS)
                                }
                            } else {
                                return register()
                            }
                        }
                    }
                    
                }
            }
        }
    }
}
