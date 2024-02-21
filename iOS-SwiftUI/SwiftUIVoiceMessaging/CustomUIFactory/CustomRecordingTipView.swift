//
//  CustomRecordingTipView.swift
//  VoiceChat

import SwiftUI
import TipKit

struct CustomRecordingTipView: View {
    @State private var favoriteTip = FavoriteTip()
    
    var body: some View {
        NavigationStack {
            List {
                
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        //print(favoriteTip.status, FavoriteTip.showTip)
                        FavoriteTip.showTip = true
                    } label: {
                        Image(systemName: "star")
                    }
                    .popoverTip(favoriteTip, arrowEdge: .top)
                }
            }
        }
    }
}

struct FavoriteTip: Tip {
    @Parameter
    static var showTip: Bool = false
    static var numberOfTimesVisited: Event = Event(id: "")
    
    var title: Text {
        Text("Record Your Voice or an Audio")
    }
    
    var message: Text? {
        Text("Hold to record an audio, release the finger to send it")
    }
    
    var asset: any View {
        //Image(systemName: "star")
        Label("Show recording steps", systemImage: "recordingtape.circle.fill")
    }
    
    var options: [TipOption] {
        return [
            Tips.MaxDisplayCount(3)
        ]
    }
    
    var rules: [Rule] {
        return [
            #Rule(FavoriteTip.$showTip) {$0 == true}
        ]
    }
    
    
}
