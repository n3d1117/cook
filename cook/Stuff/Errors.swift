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
    
    case missingInputCSR
    case missingOutputPEM
    
    case missingAppName
    case missingAppBundleId
    
    case missingDeviceName
    case missingDeviceUdid
    
    case missingBundleId
    case missingOutputProfile
    case missingOutputProfiles
    
    case outputMustBeAFolder
}

enum AuthError: Error {
    case missingUserInfoDictionary
    case missingAnisetteData
    case malformedAnisetteData
    case unableToUnarchive
    case unknownAuthFailure
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
}

enum DeviceError: Error {
    case missingDevice
}

enum ProvisioningError: Error {
    case emptyData
    case missingProfile
}
