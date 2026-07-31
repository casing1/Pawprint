import Foundation

/// Which kind of collection an event belongs to.
///
/// The vocabulary the per-category collection settings are written in, so it lives beside
/// those settings rather than inside whichever type happens to do the checking.
package enum CollectionCategory {
    case keyboard, mouse, appUsage, clipboard, sleepWake, powerPeripherals
}

/// Which button, or a drag.
///
/// Beside `CollectionCategory` because it is the same kind of thing: vocabulary the recording layer
/// is written in, which the domain needs and the application happened to own.
package enum ClickKind {
    case left, right, double, drag
}
