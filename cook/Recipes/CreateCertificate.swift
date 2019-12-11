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
    var force: Bool
    
    init(csrPath: String, pemPath: String, force: Bool) {
        self.csrPath = csrPath
        self.pemPath = pemPath
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
                                    logger.log(.info, "Adding certificate with given CSR...")
                                    do {
                                        let csr = try String(contentsOfFile: self.csrPath, encoding: .utf8)
                                        API.createCertificate(encodedCSR: csr, prefix: Utils.machinePrefix, team: team, session: session) { result in
                                            switch result {
                                            case .failure(let error as NSError):
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
                                            case .success(_):
                                                API.fetchCertificates(team: team, session: session) { result in
                                                    switch result {
                                                    case .failure(let error): return _abort(error)
                                                    case .success(let certs):
                                                        guard let cert = certs.first(where: { $0.machineName?.hasPrefix(Utils.machinePrefix) ?? false }) else { return _abort(CertificateError.missingCertificate) }
                                                        guard let certData = cert.data else { return _abort(CertificateError.missingData) }
                                                        Utils.save(data: certData, to: self.pemPath)
                                                        logger.log(.success, "Done! Saved PEM cert to \(self.pemPath)")
                                                        exit(EXIT_SUCCESS)
                                                    }
                                                }
                                            }
                                        }
                                    } catch let error {
                                        return _abort(error)
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
