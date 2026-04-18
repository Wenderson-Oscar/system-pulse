import Foundation
import AVFoundation
import CoreMediaIO

final class CameraMonitor {

    /// True if any video capture device is currently running (being used by any process).
    func isCameraInUse() -> Bool {
        let devices = cameraDeviceIDs()
        for dev in devices {
            if isDeviceRunningSomewhere(dev) { return true }
        }
        return false
    }

    private func cameraDeviceIDs() -> [CMIOObjectID] {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(sys, &addr, 0, nil, &dataSize) == 0,
              dataSize > 0 else { return [] }
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var ids = [CMIOObjectID](repeating: 0, count: count)
        let status = ids.withUnsafeMutableBufferPointer { buf -> OSStatus in
            CMIOObjectGetPropertyData(sys, &addr, 0, nil, dataSize, &dataUsed, buf.baseAddress!)
        }
        guard status == 0 else { return [] }
        return ids
    }

    private func isDeviceRunningSomewhere(_ dev: CMIOObjectID) -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        var running: UInt32 = 0
        var dataUsed: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = CMIOObjectGetPropertyData(dev, &addr, 0, nil, size, &dataUsed, &running)
        return status == 0 && running != 0
    }
}
