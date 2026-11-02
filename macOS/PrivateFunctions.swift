import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ process: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("SetFrontProcessWithOptions")
func SetFrontProcessWithOptions(_ process: UnsafePointer<ProcessSerialNumber>, _ options: OptionBits) -> OSStatus
