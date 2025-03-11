//
//  File.swift
//  Splash30
//
//  Created by Alpay Calalli on 10.03.25.
//

import Foundation

extension Collection {
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
