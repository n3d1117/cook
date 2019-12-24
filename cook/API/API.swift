//
//  API.swift
//  cook
//
//  Created by ned on 04/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import AltSign

enum API {
    
    /* TEAM */

    static func fetchTeam(account: ALTAccount, session: ALTAppleAPISession, completion: @escaping((Result<ALTTeam, Error>) -> Void)) {
        ALTAppleAPI.shared.fetchTeams(for: account, session: session) { teams, error in
            if let teams = teams, !teams.isEmpty {
                logger.log(.verbose, "Got \(teams.count) teams: \(teams)")
                if let team = teams.first(where: { $0.type == .free }) {
                    completion(.success(team))
                } else {
                    completion(.failure(TeamError.noFreeTeamsAvailable))
                }
            } else {
                completion(.failure(error ?? TeamError.missingTeams))
            }
        }
    }
    
    /* CERTIFICATES */
    
    static func fetchCertificates(team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<[ALTCertificate], Error>) -> Void)) {
        ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { certificates, error in
            if let certificates = certificates {
                logger.log(.verbose, "Got \(certificates.count) certificates: \(certificates)")
                completion(.success(certificates))
            } else {
                completion(.failure(error ?? CertificateError.missingCertificate))
            }
        }
    }
    
    static func revokeCertificate(certificate: ALTCertificate, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<Bool, Error>) -> Void)) {
        ALTAppleAPI.shared.revoke(certificate, for: team, session: session) { (revoked, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(revoked))
            }
        }
    }
    
    static func createCertificate(encodedCSR: String, prefix: String, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTCertificate, Error>) -> Void)) {
        ALTAppleAPI.shared.addCertificate(encodedCSR: encodedCSR, prefix: prefix, to: team, session: session) { (certificate, error) in
            if let certificate = certificate {
                logger.log(.verbose, "Added cert: \(certificate)")
                completion(.success(certificate))
            } else {
                completion(.failure(error ?? CertificateError.missingCertificate))
            }
        }
    }
    
    static func createCertificate(machineName: String, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTCertificate, Error>) -> Void)) {
        ALTAppleAPI.shared.addCertificate(machineName: machineName, to: team, session: session) { (certificate, error) in
            if let certificate = certificate {
                logger.log(.verbose, "Added cert: \(certificate)")
                completion(.success(certificate))
            } else {
                completion(.failure(error ?? CertificateError.missingCertificate))
            }
        }
    }
    
    /* APP IDS */
    
    static func fetchAppIds(team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<[ALTAppID], Error>) -> Void)) {
        ALTAppleAPI.shared.fetchAppIDs(for: team, session: session) { (appIds, error) in
            if let appIds = appIds {
                logger.log(.verbose, "Got \(appIds.count) app ids: \(appIds)")
                completion(.success(appIds))
            } else {
                completion(.failure(error ?? AppIdError.missingAppId))
            }
        }
    }
    
    static func registerAppId(appName: String, bundleIdentifier: String, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTAppID, Error>) -> Void)) {
        ALTAppleAPI.shared.addAppID(withName: appName, bundleIdentifier: bundleIdentifier, team: team, session: session) { (appId, error) in
            if let appId = appId {
                logger.log(.verbose, "Successfully registered app id \(appId)")
                completion(.success(appId))
            } else {
                completion(.failure(error ?? AppIdError.missingAppId))
            }
        }
    }
    
    static func deleteAppId(appId: ALTAppID, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<Bool, Error>) -> Void)) {
        ALTAppleAPI.shared.delete(appId, for: team, session: session) { (deleted, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(deleted))
            }
        }
    }
    
    static func updateAppId(appId: ALTAppID, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTAppID, Error>) -> Void)) {
        ALTAppleAPI.shared.update(appId, team: team, session: session) { (appId, error) in
            if let appId = appId {
                logger.log(.verbose, "Successfully updated app id \(appId)")
                completion(.success(appId))
            } else {
                completion(.failure(error ?? AppIdError.missingAppId))
            }
        }
    }
    
    /* DEVICES */
    
    static func fetchDevices(team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<[ALTDevice], Error>) -> Void)) {
        ALTAppleAPI.shared.fetchDevices(for: team, session: session) { (devices, error) in
            if let devices = devices {
                logger.log(.verbose, "Got \(devices.count) devices: \(devices)")
                completion(.success(devices))
            } else {
                completion(.failure(error ?? DeviceError.missingDevice))
            }
        }
    }
    
    static func registerDevice(name: String, udid: String, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTDevice, Error>) -> Void)) {
        ALTAppleAPI.shared.registerDevice(name: name, identifier: udid, team: team, session: session) { (device, error) in
            if let device = device {
                logger.log(.verbose, "Registered device \(device)")
                completion(.success(device))
            } else {
                completion(.failure(error ?? DeviceError.missingDevice))
            }
        }
    }
    
    /* PROVISIONING PROFILES */
    
    static func fetchProvisioningProfile(for appId: ALTAppID, team: ALTTeam, session: ALTAppleAPISession, completion: @escaping((Result<ALTProvisioningProfile, Error>) -> Void)) {
        ALTAppleAPI.shared.fetchProvisioningProfile(for: appId, team: team, session: session) { (profile, error) in
            if let profile = profile {
                logger.log(.verbose, "Got profile \(profile)")
                completion(.success(profile))
            } else {
                completion(.failure(error ?? ProvisioningError.missingProfile))
            }
        }
    }
    
    /* RESIGN APP */
    
    static func resignApp(app: ALTApplication, team: ALTTeam, certificate: ALTCertificate, profile: ALTProvisioningProfile, completion: @escaping((Result<Bool, Error>) -> Void)) {
        ALTSigner(team: team, certificate: certificate).signApp(at: app.fileURL, provisioningProfiles: [profile]) { (success, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                logger.log(.verbose, "Resign completed with result: \(success)")
                completion(.success(success))
            }
            
        }
    }

}
