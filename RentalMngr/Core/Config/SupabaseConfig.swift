// Configuration loaded from build settings when available,
// with fallback to bundled defaults for development.
import Foundation

enum SupabaseConfig {
    static let url: URL = {
        if let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        {
            return url
        }
        // Fallback for development
        // swiftlint:disable:next force_unwrapping
        return URL(string: "https://mejrsjdrutzvfxtiximo.supabase.co")!
    }()

    static let anonKey: String = {
        if let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
            !key.isEmpty
        {
            return key
        }
        // Fallback for development — move to xcconfig for production
        return
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lanJzamRydXR6dmZ4dGl4aW1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2MTk2MzAsImV4cCI6MjA3ODE5NTYzMH0.s-wdU95MiXwg__M4xNmXEMBXqMPKJ2STDCWPxRqNr1Q"
    }()

    static let storageBucket = "room-photos"
    static let documentsBucket = "documents"
}
