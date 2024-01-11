//
//  CallContainerSetup.swift
//  VideoConferencingSwiftUI
//

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct CallContainerSetup: View {
    @ObservedObject var viewModel: CallViewModel
    
    private var client: StreamVideo
    private let apiKey: String = "mmhfdzb5evj2" // The API key can be found in the Credentials section
    private let userId: String = "Biggs_Darklighter" // The User Id can be found in the Credentials section
    private let token: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiQmlnZ3NfRGFya2xpZ2h0ZXIiLCJpc3MiOiJodHRwczovL3Byb250by5nZXRzdHJlYW0uaW8iLCJzdWIiOiJ1c2VyL0JpZ2dzX0RhcmtsaWdodGVyIiwiaWF0IjoxNzA0ODEwMjMwLCJleHAiOjE3MDU0MTUwMzV9.5-9C-PJHu16-kSDz7N1B1_xEcASgf0LD1QSbNQpCpIs" // The Token can be found in the Credentials section
    private let callId: String = "ZAE5CL4nUaPn" // The CallId can be found in the Credentials section
    
    init() {
        let user = User(
            id: userId,
            name: "Amos G", // name and imageURL are used in the UI
            imageURL: .init(string: "https://getstream.io/static/2796a305dd07651fcceb4721a94f4505/a3911/martin-mitrevski.webp")
        )
        
        // Initialize Stream Video client
        self.client = StreamVideo(
            apiKey: apiKey,
            user: user,
            token: .init(stringLiteral: token)
        )
        
        self.viewModel = .init()
    }
    
    var body: some View {
        NavigationView{
            VStack {
                if viewModel.call != nil {
                    //CallContainer(viewFactory: DefaultViewFactory.shared, viewModel: viewModel)
                    CallContainer(viewFactory: CustomViewFactory(), viewModel: viewModel)
                    
                } else {
                    Text("loading...")
                }
            }
            .ignoresSafeArea()
            .onAppear {
                Task {
                    guard viewModel.call == nil else { return }
                    viewModel.joinCall(callType: .default, callId: callId)
                }
            }
        }
        
    }
}



