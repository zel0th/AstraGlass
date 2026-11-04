import AppKit
let output = CommandLine.arguments[1]
for (size, suffix) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size)/1024
    let transform = NSAffineTransform(); transform.scale(by:scale); transform.concat()
    let bounds = NSRect(x:40,y:40,width:944,height:944)
    let rounded = NSBezierPath(roundedRect:bounds,xRadius:210,yRadius:210)
    NSGradient(colors:[NSColor(calibratedRed:0.93,green:0.95,blue:1,alpha:1),NSColor(calibratedRed:0.76,green:0.82,blue:0.94,alpha:1)])!.draw(in:rounded,angle:-65)
    NSColor(calibratedRed:0.22,green:0.28,blue:0.56,alpha:0.88).setStroke()
    for radius:CGFloat in [320,265] { let ring=NSBezierPath(ovalIn:NSRect(x:512-radius,y:512-radius,width:radius*2,height:radius*2)); ring.lineWidth=radius==320 ? 15:6; ring.stroke() }
    for index in 0..<12 { let a=CGFloat(index)*CGFloat.pi/6; let path=NSBezierPath(); path.move(to:NSPoint(x:512+280*cos(a),y:512+280*sin(a))); path.line(to:NSPoint(x:512+307*cos(a),y:512+307*sin(a))); path.lineWidth=6; path.stroke() }
    let star=NSBezierPath(); for i in 0..<8 {let a=CGFloat(i)*CGFloat.pi/4; let r:CGFloat=i%2==0 ? 210:67; let p=NSPoint(x:512+r*cos(a),y:512+r*sin(a)); if i==0 {star.move(to:p)} else {star.line(to:p)}}; star.close()
    NSColor(calibratedRed:0.23,green:0.29,blue:0.58,alpha:1).setFill();star.fill()
    NSColor(calibratedRed:1,green:0.69,blue:0.31,alpha:1).setFill(); NSBezierPath(ovalIn:NSRect(x:742,y:677,width:85,height:85)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output).appendingPathComponent("icon_\(suffix).png"))
}
