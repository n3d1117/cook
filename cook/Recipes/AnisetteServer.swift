//
//  AnisetteServer.swift
//  cook
//
//  Created by ned on 22/03/21.
//

import Foundation
import Swifter
import AltSign

class AnisetteFetcher {
    
    var completionHandler: ((Result<ALTAnisetteData, Error>) -> Void)?
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
    
    init() {
        Utils.shell("open", "-j", "-g", "-a", "Mail")
    }
    
    func fetch(completion: @escaping (Result<ALTAnisetteData, Error>) -> Void) {
        self.completionHandler = completion
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(self.received), name: .receivedAnisetteData, object: nil)
        DistributedNotificationCenter.default().postNotificationName(.fetchAnisetteData, object: nil, userInfo: ["uuid": UUID().uuidString], deliverImmediately: true)
    }
    
    @objc func received(_ notification: Notification) {
        
        func abort(_ error: AuthError) {
            completionHandler?(.failure(error))
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
            
            completionHandler?(.success(anisetteData))
            
        } catch {
            return abort(.unableToUnarchive)
        }
    }
}

struct AnisetteServer: ExecutableRecipe {
    
    var port: in_port_t
    var secret: String
    
    init(port: in_port_t, secret: String) {
        self.port = port
        self.secret = secret
    }
    
    func execute() {
        
        var anisetteData: ALTAnisetteData?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        let server = HttpServer()
        let fetcher = AnisetteFetcher()
        
        server[secret] = { request in
            
            fetcher.fetch { result in
                switch result {
                case .success(let data): anisetteData = data
                case .failure(let e): error = e
                }
                semaphore.signal()
            }
            semaphore.wait()
            
            if let error = error {
                return .ok(.json(["success": "0", "error": "\(error.localizedDescription)"]))
            } else if let anisetteData = anisetteData {
                let base64encoded: String = try! JSONSerialization.data(withJSONObject: anisetteData.json(), options: .withoutEscapingSlashes).base64EncodedString()
                return .ok(.json(["success": "1", "base64_encoded_data": base64encoded]))
            }
            
            return .ok(.json(["success": "0", "error": "idek"]))
        }
        
        do {
            logger.log(.info, "Starting server at http://127.0.0.1:\(port)")
            try server.start(port, forceIPv4: true)
            dispatchMain()
        } catch let error {
            logger.log(.error, "Encountered error: \(error.localizedDescription), stopping server...")
            server.stop()
        }
    }
    
}
