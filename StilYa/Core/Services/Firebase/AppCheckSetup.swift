//
//  AppCheckSetup.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 26.02.2026.
//  Firebase App Check — App Attest (production) + Debug (simulator)
//

import FirebaseCore
import FirebaseAppCheck

// MARK: - App Check Provider Factory

/// Production (Release): AppAttestProvider (iOS 14+, real device only)
/// DEBUG (Simulator + Physical Device): AppCheckDebugProvider
class StilYaAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        print("[AppCheck] Using DEBUG provider")
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
