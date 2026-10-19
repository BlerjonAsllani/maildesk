import AppKit

let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(srgbRed: 0.39, green: 0.28, blue: 0.90, alpha: 1),
           ending: NSColor(srgbRed: 0.19, green: 0.13, blue: 0.48, alpha: 1))!.draw(in: tile, angle: -60)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -14)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 205, y: 302, width: 614, height: 420), xRadius: 48, yRadius: 48).fill()
NSGraphicsContext.restoreGraphicsState()
let flap = NSBezierPath()
flap.move(to: NSPoint(x: 232, y: 681))
flap.line(to: NSPoint(x: 512, y: 471))
flap.line(to: NSPoint(x: 792, y: 681))
flap.lineWidth = 31
flap.lineCapStyle = .round
flap.lineJoinStyle = .round
NSColor(srgbRed: 0.45, green: 0.35, blue: 0.82, alpha: 1).setStroke()
flap.stroke()
image.unlockFocus()
let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
try representation.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
