//
//  CreateCertificate.swift
//  cook
//
//  Created by ned on 05/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

struct CreateCertificate: ExecutableRecipe {

    var csrPath: String
    var pemPath: String
    var p12Path: String
    var p12Password: String
    var usesInputCsr: Bool
    var usesOutputPem: Bool
    var force: Bool
    
    init(csrPath: String, pemPath: String, p12Path: String, p12Pass: String, inputCsr: Bool, usesPem: Bool, force: Bool) {
        self.csrPath = csrPath
        self.pemPath = pemPath
        self.p12Path = p12Path
        self.p12Password = p12Pass
        self.usesInputCsr = inputCsr
        self.usesOutputPem = usesPem
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
                    
                    func fetch() {
                        logger.log(.info, "Fetching certificates...")
                        API.fetchCertificates(team: team, session: session) { result in
                            switch result {
                            case .failure(let error): return _abort(error)
                            case .success(let certs):
                                
                                func revoke(cert: ALTCertificate) {
                                    logger.log(.verbose, "Revoking certificate \(cert)...")
                                    API.revokeCertificate(certificate: cert, team: team, session: session) { result in
                                        switch result {
                                        case .failure(let error): return _abort(error)
                                        case .success(let revoked):
                                            if revoked {
                                                logger.log(.info, "Certificate revoked successfully...")
                                                return fetch()
                                            } else {
                                                logger.log(.verbose, "Certificate could not be revoked...")
                                                return _abort(CertificateError.failedToRevoke)
                                            }
                                        }
                                    }
                                }
                                
                                if let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.machinePrefix) ?? false }) {
                                    if self.force {
                                        logger.log(.info, "Certificate already exists, revoking...")
                                        return revoke(cert: cert)
                                    } else {
                                        logger.log(.error, "Certificate already exists! Aborting... (Use -f to force revoke)")
                                        return _abort(CertificateError.certificateAlreadyExists)
                                    }
                                } else {
                                    logger.log(.info, "Adding certificate...")
                                    
                                    func handle(error: NSError) {
                                        if error.localizedDescription.contains("7460") {
                                            if self.force {
                                                guard let cert = certs.first(where: { $0.name.contains("iPhone Developer") }) else { return _abort(CertificateError.missingCertificate) }
                                                logger.log(.error, "Unable to add certificate, revoking \(cert)...")
                                                return revoke(cert: cert)
                                            } else {
                                                logger.log(.error, "Error: You already have a current iOS Development certificate or a pending certificate request. Use -f to force revoke.")
                                                return _abort(CertificateError.certificateAlreadyExists)
                                            }
                                        } else {
                                            return _abort(error)
                                        }
                                    }
                                    
                                    func save(cert: ALTCertificate) {
                                        if outputAsJSON {
                                            if self.usesOutputPem {
                                                guard let certData = cert.data else { return _abort(CertificateError.missingData) }
                                                return _success(["pem_cert": String(decoding: certData, as: UTF8.self)])
                                            } else {
                                                guard let certP12Data = cert.encryptedP12Data(withPassword: self.p12Password) else { return _abort(CertificateError.missingData) }
                                                return _success(["base64_p12_cert": certP12Data.base64EncodedString(), "p12_password": self.p12Password])
                                            }
                                        }
                                        if self.usesOutputPem {
                                            guard let certData = cert.data else { return _abort(CertificateError.missingData) }
                                            Utils.save(data: certData, to: self.pemPath)
                                            logger.log(.success, "Done! Saved PEM cert to \(self.pemPath)")
                                        } else {
                                            guard let certP12Data = cert.encryptedP12Data(withPassword: self.p12Password) else { return _abort(CertificateError.missingData) }
                                            Utils.save(data: certP12Data, to: self.p12Path)
                                            logger.log(.success, "Done! Saved encrypted P12 cert to \(self.p12Path)")
                                        }
                                        return _success()
                                    }
                                    
                                    func createFromSelfGeneratedCsr() {
                                        logger.log(.info, "Using self generated CSR...")
                                        API.createCertificate(machineName: Utils.machinePrefix, team: team, session: session) { result in
                                            switch result {
                                            case .failure(let error as NSError):
                                                return handle(error: error)
                                            case .success(_):
                                                API.fetchCertificates(team: team, session: session) { result in
                                                    switch result {
                                                    case .failure(let error): return _abort(error)
                                                    case .success(let certs):
                                                        guard let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.machinePrefix) ?? false }) else { return _abort(CertificateError.missingCertificate) }
                                                        return save(cert: cert)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    func createFromEncodedCsr(csr: String) {
                                        logger.log(.info, "Using input CSR...")
                                        API.createCertificate(encodedCSR: csr, prefix: Utils.machinePrefix, team: team, session: session) { result in
                                            switch result {
                                            case .failure(let error as NSError):
                                                return handle(error: error)
                                            case .success(_):
                                                API.fetchCertificates(team: team, session: session) { result in
                                                    switch result {
                                                    case .failure(let error): return _abort(error)
                                                    case .success(let certs):
                                                        guard let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.machinePrefix) ?? false }) else { return _abort(CertificateError.missingCertificate) }
                                                        return save(cert: cert)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    if self.usesInputCsr {
                                        do {
                                            let csr = try String(contentsOfFile: self.csrPath, encoding: .utf8)
                                            return createFromEncodedCsr(csr: csr)
                                        } catch let error {
                                            return _abort(error)
                                        }
                                    } else {
                                        return createFromSelfGeneratedCsr()
                                    }
                                }
                            }
                        }
                    }
                    
                    fetch()
                    
                }
            }
        }
    }
}
