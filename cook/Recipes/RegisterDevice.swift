//
//  RegisterDevice.swift
//  cook
//
//  Created by ned on 06/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct RegisterDevice: ExecutableRecipe {

    var name: String
    var udid: String
    
    init(name: String, udid: String) {
        self.name = name
        self.udid = udid
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
                    
                    logger.log(.info, "Fetching devices...")
                    API.fetchDevices(team: team, session: session) { result in
                        switch result {
                        case .failure(let error): return _abort(error)
                        case .success(let devices):
                            if let _ = devices.first(where: { $0.identifier == self.udid }) {
                                logger.log(.success, "Device is already registered!")
                                return _success()
                            } else {
                                logger.log(.info, "Registering device...")
                                API.registerDevice(name: self.name, udid: self.udid, team: team, session: session) { result in
                                    switch result {
                                    case .failure(let error): return _abort(error)
                                    case .success(_):
                                        logger.log(.success, "Device registered successfully!")
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
