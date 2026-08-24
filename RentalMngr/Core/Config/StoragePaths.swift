import Foundation

/// Convención de rutas del bucket de fotos.
///
/// Cada foto se guarda dos veces: el original y una miniatura hermana con el
/// prefijo `thumb_`. Las listas piden la miniatura (~50 KB) y solo la galería a
/// pantalla completa baja el original (~450 KB).
///
/// Las fotos subidas antes de esto NO tienen miniatura: quien lee debe caer al
/// original si la miniatura no existe (lo hace `AsyncImageView`).
enum StoragePaths {
    static let thumbnailPrefix = "thumb_"

    /// `abc/foto.jpg` -> `abc/thumb_foto.jpg`
    static func thumbnail(for path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return thumbnailPrefix + path }
        let folder = path[path.startIndex...slash]
        let file = path[path.index(after: slash)...]
        return "\(folder)\(thumbnailPrefix)\(file)"
    }

    static func isThumbnail(_ path: String) -> Bool {
        (path.split(separator: "/").last ?? "").hasPrefix(thumbnailPrefix)
    }
}
