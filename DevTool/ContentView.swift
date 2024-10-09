//
//  ContentView.swift
//  Tool
//
//  Created by masaki on 2024/07/22.
//

import SwiftUI

struct ContentView: View {
    
    enum Menu: String, CaseIterable {
        case textDiffing
        case imageDiffing
        
        var title: String {
            switch self {
            case .textDiffing:
                return "Text Diffing"
            case .imageDiffing:
                return "Image Diffing"
            }
        }
    }
    
    @AppStorage("selectedMenu") var selection: Menu = .textDiffing
    
    var body: some View {
        NavigationSplitView {
            List(Menu.allCases, id: \.self, selection: $selection) { menu in
                NavigationLink(menu.title) {
                    switch menu {
                    case .textDiffing:
                        TextDiffingView()
                    case .imageDiffing:
                        ImageDiffingListView()
                    }
                }
            }
        } detail: {
            Text("Detail")
        }
    }
}
