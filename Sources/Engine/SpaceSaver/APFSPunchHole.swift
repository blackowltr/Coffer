import Foundation
import Darwin

/// macOS APFS Blok Delme (Sparse Hole Punching) ve Senkronizasyon Altyapısı
/// Çıkarılan dosyaların kapladığı disk alanını dosya ofsetlerini ve boyutunu bozmadan anında serbest bırakır.
public enum APFSPunchHole {
    /// sys/fcntl.h: #define F_PUNCHHOLE 99 (Aralıktaki fiziksel blokları deallocate eder)
    public static let F_PUNCHHOLE: Int32 = 99

    /// sys/fcntl.h: #define F_FULLFSYNC 51 (Veriyi sürücünün fiziksel flash belleğine yazar)
    public static let F_FULLFSYNC: Int32 = 51

    /// APFS dosya sistemi tahsis blok boyutu (4096 byte = 4 KB)
    public static let apfsBlockSize: Int64 = 4096

    /// macOS fcntl F_PUNCHHOLE için C uyumlu bellek hizalı struct
    public struct fpunchhole {
        public var fp_flags: UInt32 = 0
        public var reserved: UInt32 = 0
        public var fp_offset: off_t
        public var fp_length: off_t

        public init(fp_flags: UInt32 = 0, reserved: UInt32 = 0, fp_offset: off_t, fp_length: off_t) {
            self.fp_flags = fp_flags
            self.reserved = reserved
            self.fp_offset = fp_offset
            self.fp_length = fp_length
        }
    }

    /// Verilen dosya veya klasörün APFS dosya sisteminde olup olmadığını denetler
    public static func isAPFS(at url: URL) -> Bool {
        var stat = statfs()
        if statfs(url.path, &stat) == 0 {
            let fsName = withUnsafePointer(to: &stat.f_fstypename) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
            }
            return fsName.lowercased() == "apfs"
        }
        return false
    }

    /// Bir dosya tanımlayıcısında (fd) belirtilen ofset ve uzunluktaki blokları delip disk alanını boşaltır
    /// APFS 4KB blok hizalaması gerektirdiği için ofset yukarı, uzunluk ise blok sınırına aşağı yuvarlanır.
    @discardableResult
    public static func punchHole(fileDescriptor fd: Int32, offset: Int64, length: Int64) -> Bool {
        guard length > 0 else { return true }

        // 4 KB blok hizalaması: Veri bütünlüğü için ofseti sonraki 4KB sınırına yuvarla
        let alignedStart = ((offset + apfsBlockSize - 1) / apfsBlockSize) * apfsBlockSize
        let endOffset = offset + length
        let alignedEnd = (endOffset / apfsBlockSize) * apfsBlockSize

        guard alignedEnd > alignedStart else {
            // Aralık 4KB'den küçükse veya tam bir blok kapsayamıyorsa delme atlanır
            return false
        }

        let alignedLength = alignedEnd - alignedStart
        var hole = fpunchhole(
            fp_flags: 0,
            reserved: 0,
            fp_offset: off_t(alignedStart),
            fp_length: off_t(alignedLength)
        )

        let result = fcntl(fd, F_PUNCHHOLE, &hole)
        return result == 0
    }

    /// Verilen URL'deki dosyada belirtilen aralığı açar, deler ve kapatır
    @discardableResult
    public static func punchHole(at url: URL, offset: Int64, length: Int64) -> Bool {
        let fd = open(url.path, O_RDWR)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return punchHole(fileDescriptor: fd, offset: offset, length: length)
    }

    /// Dosyayı ftruncate kullanarak belirtilen uzunluğa güvenle kısaltır
    @discardableResult
    public static func truncate(fileDescriptor fd: Int32, newLength: Int64) -> Bool {
        guard newLength >= 0 else { return false }
        return ftruncate(fd, off_t(newLength)) == 0
    }

    /// Verilen URL'deki dosyayı kısaltır
    @discardableResult
    public static func truncate(at url: URL, newLength: Int64) -> Bool {
        let fd = open(url.path, O_RDWR)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return truncate(fileDescriptor: fd, newLength: newLength)
    }

    /// Çıkarılan dosyanın tüm kirli bloklarını fiziksel sürücüye yazıp commit eder (Crash Safety)
    @discardableResult
    public static func fullSync(fileDescriptor fd: Int32) -> Bool {
        return fcntl(fd, F_FULLFSYNC) == 0
    }

    /// URL üzerindeki dosyanın disk bloklarını flash medyaya tamamen yazar
    @discardableResult
    public static func fullSync(at url: URL) -> Bool {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return fullSync(fileDescriptor: fd)
    }
}
