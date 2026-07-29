import Foundation

/// Which kind of collection an event belongs to.
///
/// The vocabulary the per-category collection settings are written in, so it lives beside
/// those settings rather than inside whichever type happens to do the checking.
package enum CollectionCategory {
    case keyboard, mouse, appUsage, clipboard, sleepWake, powerPeripherals
}
