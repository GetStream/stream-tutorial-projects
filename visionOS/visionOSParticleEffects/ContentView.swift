//
//  ContentView.swift
//  VisionParticleEffects

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("Hello, Particle Effects!")
                .font(.largeTitle)
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
