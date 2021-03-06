//
//  Authenticator.swift
//  cook
//
//  Created by ned on 04/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

extension Notification.Name {
    static let fetchAnisetteData = Notification.Name("it.ned.FetchAnisetteData")
    static let receivedAnisetteData = Notification.Name("it.ned.ReceivedAnisetteData")
}

class Authenticator {
    
    var completionHandler: ((ALTAccount?, ALTAppleAPISession?, Error?) -> Void)?
    var appleId: String
    var password: String
    
    var customAnisetteData: ALTAnisetteData? = nil
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
    
    init(appleId: String, password: String) {
        self.appleId = appleId
        self.password = password
    }
    
    func start() {
        
        if let anisetteData = customAnisetteData {
            logger.log(.info, "Logging in using custom anisette data...")
            logger.log(.verbose, "customAnisetteData is \(anisetteData)")
            authenticateAndComplete(anisetteData: anisetteData)
        } else {
            // Open Mail.app
            Utils.shell("open", "-j", "-g", "-a", "Mail")
            
            delay(1) {
                DistributedNotificationCenter.default.addObserver(self, selector: #selector(self.received), name: .receivedAnisetteData, object: nil)
                DistributedNotificationCenter.default().postNotificationName(.fetchAnisetteData, object: nil, userInfo: ["uuid": UUID().uuidString], deliverImmediately: true)
            }
        }
    }
    
    @objc func received(_ notification: Notification) {
        
        func abort(_ error: AuthError) {
            completionHandler?(nil, nil, error)
        }
        
        do {
            guard let userInfo = notification.userInfo else { return abort(.missingUserInfoDictionary) }
            guard let archivedData = userInfo["anisetteData"] as? Data else { return abort(.missingAnisetteData) }
            guard let anisetteData = try NSKeyedUnarchiver.unarchivedObject(ofClass: ALTAnisetteData.self, from: archivedData) else { return abort(.malformedAnisetteData) }
            
            if let range = anisetteData.deviceDescription.lowercased().range(of: "(com.apple.mail") {
                var adjustedDescription = anisetteData.deviceDescription[..<range.lowerBound]
                adjustedDescription += "(com.apple.dt.Xcode/3594.4.19)>"
                anisetteData.deviceDescription = String(adjustedDescription)
            }
            logger.log(.info, "Logging in...")
            authenticateAndComplete(anisetteData: anisetteData)
            
        } catch {
            return abort(.unableToUnarchive)
        }
    }
    
    fileprivate func handle2FAVerificationCode(_ completionHandler: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let twoFactorCode = CLI.parseArgument(.twoFactorCode)
            
            guard twoFactorCode != nil else { return _abort(UsageError.missing2FACode) }
            guard twoFactorCode!.count == 6 else { return _abort(AuthError.malformed2FACode) }
                
            logger.log(.verbose, "2fa code is \(twoFactorCode!)")
            completionHandler(twoFactorCode)
        }
    }
    
    fileprivate func authenticateAndComplete(anisetteData: ALTAnisetteData) {
        ALTAppleAPI.shared.authenticate(appleID: self.appleId, password: self.password, anisetteData: anisetteData, verificationHandler: handle2FAVerificationCode, completionHandler: { [weak self] (account, session, error) in
            self?.completionHandler?(account, session, error)
        })
    }
}
