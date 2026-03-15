import Foundation
import IOKit

enum IdleDetector {

    static func secondsSinceLastInput() -> TimeInterval? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = unmanagedDict?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        guard let idleTime = dict["HIDIdleTime"] as? Int64 else { return nil }
        return TimeInterval(idleTime) / 1_000_000_000
    }

    static func isIdle(threshold: TimeInterval = 300) -> Bool {
        guard let idle = secondsSinceLastInput() else { return false }
        return idle > threshold
    }
}
