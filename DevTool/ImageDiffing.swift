//
//  ImageDiffing.swift
//  DevTool
//
//  Created by masaki on 2024/10/09.
//

import SwiftUI
import PhotosUI

struct ImageDiffing: Identifiable {
    
    struct GIF {
        let data: Data
        let image: NSImage
    }
    
    let id = UUID()
    var before: Image?
    var after: Image?
    var diffImage: Image?
    var gifAnimation: GIF?
    
    struct ImageBeforeAfter: Equatable {
        var before: Image
        var after: Image
    }
    
    var beforeAfter: ImageBeforeAfter? {
        guard let before, let after else {
            return nil
        }
        return ImageBeforeAfter(before: before, after: after)
    }
}

struct ImageDiffingListView: View {
    
    @State var diffings: [ImageDiffing] = [.init()]
    
    var body: some View {
        ScrollView {
            ForEach($diffings) { diffing in
                ImageDiffingView(imageDiffing: diffing)
            }
            addButton
        }
    }
    
    var addButton: some View {
        Button {
            withAnimation {
                diffings.append(.init())
            }
        } label: {
            Text("Add")
                .padding(.horizontal, 64)
                .padding(.vertical, 16)
                .background(.quinary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ImageDiffingView: View {
    
    @Binding var imageDiffing: ImageDiffing
    @State var alpha = 0.5
    
    var body: some View {
        HStack {
            ImageDiffingSettingView(name: "Before", image: $imageDiffing.before)
            ImageDiffingSettingView(name: "After", image: $imageDiffing.after)
            Color.clear.background(.quinary).overlay {
                HStack {
                    if let before = imageDiffing.before, let after = imageDiffing.after {
                        VStack {
                            ZStack {
                                before
                                    .resizable()
                                    .scaledToFit()
                                after
                                    .resizable()
                                    .scaledToFit()
                                    .opacity(alpha)
                            }
                            .frame(width: 240)
                            Slider(value: $alpha)
                        }
                    }
                    if let diffImage = imageDiffing.diffImage {
                        ImagePreview(name: "diff.png", image: diffImage.resizable())
                            .scaledToFit()
                            .frame(width: 240)
                    }
                    if let gifAnimation = imageDiffing.gifAnimation {
                        GifImageView(image: gifAnimation.image)
                            .onDrag(data: gifAnimation.data, name: "diff.gif")
                            .frame(width: 240)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onChange(of: imageDiffing.beforeAfter, initial: true) { oldValue, newValue in
            guard let beforeAfter = newValue else {
                return
            }
            
            imageDiffing.diffImage = DiffImageCreator().createDifferenceImage(from: beforeAfter.before, and: beforeAfter.after)
            let animator = DiffImageBlendAnimator(nsImageA: beforeAfter.before.toNSImage()!, nsImageB: beforeAfter.after.toNSImage()!)
            DispatchQueue.global().async {
                let gifData = animator.createGifAnimation()
                DispatchQueue.main.async {
                    guard let gifData, let image = NSImage(data: gifData) else {
                        return
                    }
                    imageDiffing.gifAnimation = .init(data: gifData, image: image)
                }
            }
        }
    }
}
struct ImageDiffingSettingView: View {
    
    let name: String
    @Binding var image: Image?
    @State var showsFilePanel = false
    
    var body: some View {
        Button {
            showsFilePanel = true
        } label: {
            if let image {
                ImagePreview(name: "\(name).png", image: image.resizable())
                    .scaledToFit()
            } else {
                Image(systemName: "plus")
                    .frame(width: 80, height: 80)
                    .background(.tertiary)
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
        }
        .frame(width: 240, height: 240)
        .buttonStyle(.plain)
        .background(.quinary)
        .overlay(alignment: .top) {
            HStack {
                Text(name)
                    .bold()
                Spacer()
                if image != nil {
                    Button {
                        image = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.black.opacity(0.6))
        }
        .onDrop(of: [.image], delegate: ImageDropDelegate { images in
            guard let selected = images.first else {
                return
            }
            image = selected
        })
        .fileImporter(isPresented: $showsFilePanel, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let selected):
                image = NSImage(contentsOf: selected).map(Image.init)
            case .failure(let failure):
                print(failure)
            }
        }
    }
}


struct ImageDropDelegate: DropDelegate {
    
    let onPerformDrop: ([Image]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        Task {
            let providers = info.itemProviders(for: [.image])
            let images = await withTaskGroup(of: Image?.self) { group in
                providers.forEach { provider in
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            provider.loadObject(ofClass: NSImage.self) { reading, error in
                                let image = reading as? NSImage
                                continuation.resume(returning: image.map { Image(nsImage: $0) })
                            }
                        }
                    }
                }
                
                var result: [Image] = []
                for await image in group {
                    if let image {
                        result.append(image)
                    }
                }
                return result
            }
            onPerformDrop(images)
        }
        return true
    }
}


#Preview {
    ImageDiffingListView(
        diffings: [
            .init(
                before: Image(systemName: "swift"),
                after: Image(systemName: "star")
            )
        ]
    )
}

extension View {
    
    func onDrag(data: Data?, name: String) -> some View {
        func createTemporaryFile(for data: Data) -> URL? {
            // 一時ファイルディレクトリに画像を保存
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(name)
            
            do {
                try? FileManager.default.removeItem(at: fileURL)
                try data.write(to: fileURL)
                return fileURL
            } catch {
                print("Failed to write image to file: \(error)")
                return nil
            }
        }
        return onDrag {
            if let data, let tempFileURL = createTemporaryFile(for: data) {
                return NSItemProvider(contentsOf: tempFileURL) ?? .init()
            } else {
                return .init()
            }
        }
    }
}

extension Image {
    
    func draggable(name: String) -> some View {
        func createTemporaryFile(for image: NSImage?) -> Data? {
            guard let tiffData = image?.tiffRepresentation else { return nil }
            guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else { return nil }
            guard let pngData = bitmapImageRep.representation(using: .png, properties: [:]) else { return nil }
            return pngData
        }
        return onDrag(data: createTemporaryFile(for: toNSImage()), name: name)
    }
}

struct ImagePreview: View {
    
    let name: String
    let image: Image
    
    @State var showsFullScreen = false
    
    var body: some View {
        image
            .draggable(name: name)
            .contextMenu {
                Button {
                    showsFullScreen = true
                } label: {
                    Label("Show Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }
            .sheet(isPresented: $showsFullScreen) {
                image
                    .resizable()
                    .draggable(name: name)
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            showsFullScreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .padding(8)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
            }
    }
}

struct GifImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = image
        return imageView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        .init(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image != image {
            nsView.image = image
        }
    }
}