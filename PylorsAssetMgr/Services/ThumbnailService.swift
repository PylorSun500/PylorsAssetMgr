import QuickLookThumbnailing
import AppKit

actor ThumbnailService {
    static let shared = ThumbnailService()
    private let generator = QLThumbnailGenerator.shared

    private init() {}

    func generate(for fileURL: URL, size: CGFloat = Constants.thumbSize) async -> URL? {
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            generator.generateBestRepresentation(for: request) { repr, error in
                if let repr = repr {
                    let nsImage = NSImage(cgImage: repr.cgImage,
                                          size: NSSize(width: repr.cgImage.width,
                                                       height: repr.cgImage.height))
                    // 缓存到临时目录
                    let cacheDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("PylorsThumbnails")
                    try? FileManager.default.createDirectory(at: cacheDir,
                                                            withIntermediateDirectories: true)
                    let filename = fileURL.path
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: " ", with: "_") + ".png"
                    let outURL = cacheDir.appendingPathComponent(filename)

                    if let tiff = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: outURL)
                        continuation.resume(returning: outURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
