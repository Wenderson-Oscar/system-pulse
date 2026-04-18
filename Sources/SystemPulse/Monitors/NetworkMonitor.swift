import Foundation
import Darwin

struct NetworkSample {
    var downloadMbps: Double
    var uploadMbps: Double
}

final class NetworkMonitor {
    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTimestamp: TimeInterval = 0

    func sample() -> NetworkSample {
        let (totalIn, totalOut) = readInterfaceCounters()
        let now = Date().timeIntervalSince1970

        defer {
            lastIn = totalIn
            lastOut = totalOut
            lastTimestamp = now
        }

        guard lastTimestamp > 0 else {
            return NetworkSample(downloadMbps: 0, uploadMbps: 0)
        }

        let dt = now - lastTimestamp
        guard dt > 0 else {
            return NetworkSample(downloadMbps: 0, uploadMbps: 0)
        }

        let inBytes = totalIn >= lastIn ? Double(totalIn - lastIn) : 0
        let outBytes = totalOut >= lastOut ? Double(totalOut - lastOut) : 0

        // bytes/sec -> bits/sec -> Mbps
        let downloadMbps = (inBytes * 8.0) / (dt * 1_000_000.0)
        let uploadMbps = (outBytes * 8.0) / (dt * 1_000_000.0)

        return NetworkSample(downloadMbps: downloadMbps, uploadMbps: uploadMbps)
    }

    /// Sums byte counters across non-loopback interfaces.
    private func readInterfaceCounters() -> (UInt64, UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = current {
            defer { current = ptr.pointee.ifa_next }

            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: ifa.ifa_name)
            // Skip loopback and pseudo interfaces
            if name.hasPrefix("lo") || name.hasPrefix("utun") || name.hasPrefix("awdl") || name.hasPrefix("llw") {
                continue
            }

            guard let dataPtr = ifa.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            let data = dataPtr.pointee
            totalIn &+= UInt64(data.ifi_ibytes)
            totalOut &+= UInt64(data.ifi_obytes)
        }

        return (totalIn, totalOut)
    }
}
