//
//  File.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import Foundation

struct SetupStateModel {
    var hoopDetected = false
    var playerDetected = false
    
    /// Returns true if all setup steps are completed.
    var isAllDone: Bool {
        hoopDetected && playerDetected
    }
}
