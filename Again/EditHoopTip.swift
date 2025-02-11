//
//  File.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 11.02.25.
//

import TipKit

struct EditHoopTip: Tip {
    static let viewAppearCount = Event(id: "viewAppearCount")
    @Parameter static var showTip: Bool = false
    
    var title: Text {
        Text("Wrong Placement?")
    }
    var message: Text? {
        Text("Press and Hold to edit the hoop.")
    }
    
    var image: Image? {
        Image(systemName: "pencil")
    }
    
    var rules: [Rule] {
        #Rule(Self.$showTip) {  show in
            show == true
        }
        
        #Rule(EditHoopTip.viewAppearCount) { appearCount in
            appearCount.donations.count == 1
        }
    }
    
    var options: [TipOption] {
        [
          Tip.IgnoresDisplayFrequency(true)
        ]
      }
}
