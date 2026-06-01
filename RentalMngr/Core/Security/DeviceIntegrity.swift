import Foundation
import MachO

enum DeviceIntegrity {

    struct IntegrityReport: Sendable {
        let threats: [String]
        var isCompromised: Bool { !threats.isEmpty }
    }

    static func check() -> IntegrityReport {
        var threats: [String] = []

        #if !targetEnvironment(simulator)
        if checkJailbreakPaths() { threats.append("jailbreak_paths") }
        if checkSandboxEscape() { threats.append("sandbox_escape") }
        if checkSuspiciousDylibs() { threats.append("suspicious_dylibs") }
        #endif

        if checkDebugger() { threats.append("debugger") }

        return IntegrityReport(threats: threats)
    }

    // MARK: - Jailbreak paths

    private static func checkJailbreakPaths() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/var/jb",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    // MARK: - Sandbox write test

    private static func checkSandboxEscape() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Suspicious dylibs

    private static func checkSuspiciousDylibs() -> Bool {
        let suspicious = ["SubstrateLoader", "substitute", "libhooker", "TweakInject", "frida", "cycript", "SSLKillSwitch"]
        for i in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: name)
            for lib in suspicious {
                if imageName.contains(lib) { return true }
            }
        }
        return false
    }

    // MARK: - Debugger detection

    private static func checkDebugger() -> Bool {
        #if DEBUG
        return false // Don't flag during development
        #else
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return (info.kp_proc.p_flag & P_TRACED) != 0
        #endif
    }
}
