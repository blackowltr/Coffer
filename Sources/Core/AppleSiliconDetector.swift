import Foundation

/// Apple Silicon (M1/M2/M3/M4) Donanım ve Çekirdek Analizcisi
public final class AppleSiliconDetector: Sendable {
    public static let shared = AppleSiliconDetector()

    public let chipName: String
    public let performanceCores: Int
    public let efficiencyCores: Int
    public let totalCores: Int
    public let unifiedMemoryGB: Int
    public let hasHardwareCrypto: Bool // ARMv8 Cryptography (AES/SHA)

    private init() {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var nameChars = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &nameChars, &size, nil, 0)
        let brand = String(cString: nameChars).trimmingCharacters(in: .whitespacesAndNewlines)

        self.chipName = brand.isEmpty ? "Apple Silicon (M-Serisi)" : brand

        var pCores: Int32 = 0
        var eCores: Int32 = 0
        var pSize = MemoryLayout<Int32>.size
        var eSize = MemoryLayout<Int32>.size

        sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &pSize, nil, 0)
        sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &eSize, nil, 0)

        let resolvedP = Int(pCores > 0 ? pCores : 4)
        let resolvedE = Int(eCores > 0 ? eCores : 4)
        self.performanceCores = resolvedP
        self.efficiencyCores = resolvedE
        self.totalCores = resolvedP + resolvedE

        var memSize: UInt64 = 0
        var memLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &memLen, nil, 0)
        self.unifiedMemoryGB = Int(memSize / (1024 * 1024 * 1024))

        // Apple Silicon çiplerinde ARMv8 Crypto Extensions (AES, SHA) donanımsal olarak bulunur
        self.hasHardwareCrypto = true
    }

    /// Sıkıştırma motoru için optimal iş parçacığı (Worker Thread) sayısı
    public var optimalThreadCount: Int {
        // En iyi performans için P-Core'ların tamamı + E-Core'ların yarısı
        return max(2, performanceCores + (efficiencyCores / 2))
    }
}
