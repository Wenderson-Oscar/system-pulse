import Foundation
import IOKit

/// Minimal SMC reader for fan RPM. Read-only by design:
/// writing fan speeds requires disabling SMC auto-control and can damage hardware.
final class SMCMonitor {
    private var connection: io_connect_t = 0

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        IOServiceOpen(service, mach_task_self_, 0, &connection)
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    struct Fan {
        var index: Int
        var actualRPM: Int
        var targetRPM: Int
        var minRPM: Int
        var maxRPM: Int
    }

    func readFans() -> [Fan] {
        guard connection != 0 else { return [] }
        guard let count = readUInt8(key: "FNum"), count > 0 else { return [] }

        var fans: [Fan] = []
        for i in 0..<Int(count) {
            let actual = readFloat(key: "F\(i)Ac") ?? 0
            let target = readFloat(key: "F\(i)Tg") ?? 0
            let minR = readFloat(key: "F\(i)Mn") ?? 0
            let maxR = readFloat(key: "F\(i)Mx") ?? 0
            fans.append(Fan(index: i,
                            actualRPM: Int(actual),
                            targetRPM: Int(target),
                            minRPM: Int(minR),
                            maxRPM: Int(maxR)))
        }
        return fans
    }

    // MARK: - SMC primitives

    private typealias SMCBytes = (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8)

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCKeyDataVers()
        var pLimitData = SMCKeyDataLimit()
        var keyInfo = SMCKeyDataInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
    private struct SMCKeyDataVers { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct SMCKeyDataLimit { var version: UInt16 = 0; var length: UInt16 = 0; var cpuPLimit: UInt32 = 0; var gpuPLimit: UInt32 = 0; var memPLimit: UInt32 = 0 }
    private struct SMCKeyDataInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0; private var _pad: (UInt8, UInt8, UInt8) = (0, 0, 0) }

    private func fourCharCode(_ s: String) -> UInt32 {
        let bytes = Array(s.utf8)
        guard bytes.count == 4 else { return 0 }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    private func call(_ input: inout SMCKeyData, selector: UInt32) -> (SMCKeyData, Bool) {
        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = inputSize
        let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr in
                IOConnectCallStructMethod(connection, selector,
                                          UnsafeRawPointer(inPtr), inputSize,
                                          UnsafeMutableRawPointer(outPtr), &outputSize)
            }
        }
        return (output, result == kIOReturnSuccess)
    }

    private func readKey(_ key: String) -> (SMCKeyDataInfo, [UInt8])? {
        var input = SMCKeyData()
        input.key = fourCharCode(key)

        // Get key info (selector 9 = kSMCGetKeyInfo)
        input.data8 = 9
        let (infoOut, ok1) = call(&input, selector: 2)
        guard ok1, infoOut.result == 0 else { return nil }
        let info = infoOut.keyInfo

        // Read bytes (selector 5 = kSMCReadKey)
        input.keyInfo.dataSize = info.dataSize
        input.data8 = 5
        let (dataOut, ok2) = call(&input, selector: 2)
        guard ok2, dataOut.result == 0 else { return nil }
        let bytesArray = withUnsafeBytes(of: dataOut.bytes) { Array($0) }
        return (info, bytesArray)
    }

    private func readUInt8(key: String) -> UInt8? {
        guard let (info, bytes) = readKey(key), info.dataSize >= 1 else { return nil }
        return bytes[0]
    }

    /// SMC "flt " (little-endian float) or "fpe2" (big-endian fixed-point 14.2)
    private func readFloat(key: String) -> Float? {
        guard let (info, bytes) = readKey(key) else { return nil }
        let typeStr = fourCharString(info.dataType)
        if typeStr == "flt " {
            var f: Float = 0
            memcpy(&f, bytes, 4)
            return f
        }
        if typeStr == "fpe2" {
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Float(raw) / 4.0
        }
        if typeStr == "ui16" {
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Float(raw)
        }
        return nil
    }

    private func fourCharString(_ v: UInt32) -> String {
        let chars = [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
        return String(bytes: chars, encoding: .ascii) ?? ""
    }
}
