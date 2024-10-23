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
    var name = ""
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
    
    var beforeImageFileName: String {
        if name.isEmpty {
            return "Before.png"
        } else {
            return "\(name)_Before.png"
        }
    }
    
    var afterImageFileName: String {
        if name.isEmpty {
            return "After.png"
        } else {
            return "\(name)_After.png"
        }
    }
    
    var diffHighlightImageFileName: String {
        if name.isEmpty {
            return "highlight.png"
        } else {
            return "\(name)_highlight.png"
        }
    }
    
    var gifFileName: String {
        if name.isEmpty {
            return "diff.gif"
        } else {
            return "\(name)_diff.gif"
        }
    }
}

struct ImageDiffingListView: View {
    
    @State var diffings: [ImageDiffing] = [.init()]
    
    var body: some View {
        ScrollView {
            addButton
            ForEach($diffings) { diffing in
                ImageDiffingView(imageDiffing: diffing) {
                    guard let index = diffings.firstIndex(where: { $0.id == diffing.id }) else {
                        return
                    }
                    diffings.remove(at: index)
                }
            }
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
    
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $imageDiffing.name)
            HStack {
                ImageDiffingSettingView(name: imageDiffing.beforeImageFileName, image: $imageDiffing.before)
                ImageDiffingSettingView(name: imageDiffing.afterImageFileName, image: $imageDiffing.after)
                Color.clear.background(.quinary).overlay {
                    HStack {
                        if let beforeAfter = imageDiffing.beforeAfter {
                            FullSreenView {
                                SlideImageDiffingView(beforeAfter: beforeAfter)
                            }
                            .frame(width: 240)
                        }
                        if let diffImage = imageDiffing.diffImage {
                            FullSreenView {
                                diffImage
                                    .resizable()
                                    .draggable(name: imageDiffing.diffHighlightImageFileName)
                                    .scaledToFit()
                            }
                            .frame(width: 240)
                        }
                        if let gifAnimation = imageDiffing.gifAnimation {
                            FullSreenView {
                                GifImageView(image: gifAnimation.image)
                                    .onDrag(data: gifAnimation.data, name: imageDiffing.gifFileName)
                            } fullScreenContent: {
                                GifImageView(image: gifAnimation.image, fullScreen: true)
                                    .onDrag(data: gifAnimation.data, name: imageDiffing.gifFileName)
                                    .frame(width: 800, height: 800)
                            }
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
                onChangeBeforeAfter(beforeAfter)
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
    
    @MainActor
    func onChangeBeforeAfter(_ beforeAfter: ImageDiffing.ImageBeforeAfter) {
        let image1 = beforeAfter.before.toNSImage()!
        let image2 = beforeAfter.after.toNSImage()!
        let diffImageCreator = DiffImageCreator(image1: image1, image2: image2)
        DispatchQueue(label: "DiffImageCreator").async {
            let diffImage = diffImageCreator.generateHighlightedDifferenceWithOriginal()
            DispatchQueue.main.async {
                imageDiffing.diffImage = diffImage
            }
        }
        let animator = DiffImageBlendAnimator(nsImageA: image1, nsImageB: image2)
        DispatchQueue(label: "DiffImageBlendAnimator").async {
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

struct SlideImageDiffingView: View {
    
    let beforeAfter: ImageDiffing.ImageBeforeAfter
    
    @State var alpha = 0.5
    
    var body: some View {
        VStack {
            ZStack {
                beforeAfter.before
                    .resizable()
                    .scaledToFit()
                beforeAfter.after
                    .resizable()
                    .scaledToFit()
                    .opacity(alpha)
            }
            Slider(value: $alpha)
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
                FullSreenView {
                    image
                        .resizable()
                        .draggable(name: name)
                        .scaledToFit()
                }
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
    
    @MainActor
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

struct FullSreenView<Content: View, FullScreenContent: View>: View {
    
    @State var showsFullScreen = false
    
    @ViewBuilder let content: () -> Content
    @ViewBuilder var fullScreenContent: () -> FullScreenContent
    
    var body: some View {
        content()
            .contextMenu {
                Button("Show Full Screen") {
                    showsFullScreen = true
                }
            }
            .sheet(isPresented: $showsFullScreen) {
                fullScreenContent()
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
            .keyboardShortcut(.cancelAction)
    }
}

extension FullSreenView where Content == FullScreenContent {
    
    init(@ViewBuilder fullScreenContent: @escaping () -> FullScreenContent) {
        self.init(content: fullScreenContent, fullScreenContent: fullScreenContent)
    }
}

struct GifImageView: NSViewRepresentable {
    let image: NSImage
    var fullScreen = false
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = image
        return imageView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        fullScreen ? nsView.intrinsicContentSize : .init(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image != image {
            nsView.image = image
        }
    }
}
