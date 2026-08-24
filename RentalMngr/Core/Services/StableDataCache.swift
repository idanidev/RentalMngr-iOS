import Foundation

/// Caché en memoria para los datos que casi nunca cambian pero se piden todo el rato.
///
/// Hoy se usa para el perfil del arrendador y las variables de contrato: entre
/// las dos se piden desde 13 sitios (cada generación de contrato, cada anuncio,
/// cada vista previa) y su contenido cambia como mucho una vez al mes.
///
/// **Plan de invalidación** — una caché sin esto es un bug con retraso:
/// 1. **Explícita al escribir**: cada `save`/`create`/`update`/`delete` del propio
///    servicio borra su entrada. Es la vía principal y la que garantiza que el
///    usuario nunca ve lo que acaba de cambiar como antiguo.
/// 2. **Por tiempo (TTL 10 min)**: red de seguridad para cambios hechos en OTRO
///    dispositivo o en la webapp, que esta app no puede detectar.
/// 3. **Al cerrar sesión**: `clearAll()` desde AuthService, para no filtrar datos
///    de una cuenta a la siguiente.
actor StableDataCache {
    static let shared = StableDataCache()

    private struct Entry {
        let value: Any
        let storedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval = 600  // 10 minutos

    /// Devuelve el valor cacheado si sigue fresco; si no, ejecuta `load`, lo guarda y lo devuelve.
    func value<T>(for key: String, load: () async throws -> T) async rethrows -> T {
        if let entry = entries[key],
           Date().timeIntervalSince(entry.storedAt) < ttl,
           let typed = entry.value as? T {
            return typed
        }
        let fresh = try await load()
        entries[key] = Entry(value: fresh, storedAt: Date())
        return fresh
    }

    func invalidate(_ key: String) {
        entries[key] = nil
    }

    func clearAll() {
        entries.removeAll()
    }
}

enum StableDataKey {
    static let landlordProfile = "landlordProfile"
    static let contractVariables = "contractVariables"
}
