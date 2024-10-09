//
//  TextDiffing.swift
//  DevTool
//
//  Created by masaki on 2024/10/09.
//

import SwiftUI

struct TextDiffingView: View {
    
    @State var a = "aestt"
    @State var b = "tesst"
    
    var body: some View {
        VStack{
            HStack {
                editor($a)
                editor($b)
            }
            HStack {
                diff(from: b, to: a, color: .red)
                diff(from: a, to: b, color: .green)
            }
            Button("Paste XCTest") {
                let pasted = NSPasteboard.general.string(forType: .string) ?? ""
                let parts = pasted.components(separatedBy: "is not equal to")
                if parts.count == 2 {
                    a = parts[0]
                    b = parts[1]
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
        .padding()
    }
    
    func diff(from a: String, to b: String, color: Color) -> some View {
        let diff = b.difference(from: a)
        
        var new = AttributedString(a)
        
        diff.forEach { change in
            switch change {
            case .insert(let offset, let element, _):
                var n = AttributedString(String(element))
                n.foregroundColor = color
                let index = new.index(new.startIndex, offsetByCharacters: offset)
                new.insert(n, at: index)
            case .remove(let offset, _, _):
                let range = new.index(new.startIndex, offsetByCharacters: offset)..<new.index(new.startIndex, offsetByCharacters: offset + 1)
                new.removeSubrange(range)
            }
        }
        
        return ScrollView {
            Text(new)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(.quinary)
    }
    
    func editor(_ text: Binding<String>) -> some View {
        TextEditor(text: text)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scrollContentBackground(.hidden)
            .background(.quinary)
    }
}

struct HighlightButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.95 : 1)
    }
}

extension ButtonStyle where Self == HighlightButtonStyle {
    static var highlight: HighlightButtonStyle {
        HighlightButtonStyle()
    }
}

#Preview {
    TextDiffingView()
        .preferredColorScheme(.dark)
}
