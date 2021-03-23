//
//  Errors.swift
//  cook
//
//  Created by ned on 04/12/2019.
//  Copyright © 2019 ned. All rights reserved.
//

enum UsageError: Error {
    case missingAppleId
    case missingPassword
    case missing2FACode
    
    case missingOutput
    
    case missingAppName
    case missingAppBundleId
    
    case missingDeviceName
    case missingDeviceUdid
    
    case missingBundleId
    case missingOutputProfile
    case missingOutputProfiles
    
    case outputMustBeAFolder
    
    case missingIpaPath
    
    case missingSecret
    case malformedCustomAnisetteData
}

enum AuthError: Error {
    case missingUserInfoDictionary
    case missingAnisetteData
    case malformedAnisetteData
    case unableToUnarchive
    case unknownAuthFailure
    case malformed2FACode
}

enum TeamError: Error {
    case missingTeams
    case noFreeTeamsAvailable
}

enum CertificateError: Error {
    case failedToRevoke
    case missingCertificate
    case certificateAlreadyExists
    case missingData
}

enum AppIdError: Error {
    case missingAppId
    case failedToDeleteAppId
}

enum DeviceError: Error {
    case missingDevice
}

enum ProvisioningError: Error {
    case emptyData
    case missingProfile
}

enum ResignError: Error {
    case failedToResign
    case ipaPathNotValid
    case outputIpaPathNotValid
    case certIsNotInP12Format
    case ipaFileNotFound
    case invalidP12
}
