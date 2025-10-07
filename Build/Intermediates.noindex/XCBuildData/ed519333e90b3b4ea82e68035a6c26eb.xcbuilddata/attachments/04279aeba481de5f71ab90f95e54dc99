#!/bin/sh
set -euo pipefail

APPICON_SET="${SRCROOT}/scoremyday2/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$APPICON_SET"

SWIFT_SCRIPT="${SRCROOT}/Scripts/GenerateIcon.swift"
mkdir -p "${SRCROOT}/Scripts"

# Write Swift script that renders a glassy emoji icon to 1024x1024 PNG (no assets).
cat > "$SWIFT_SCRIPT" <<'SWIFT'
// GenerateIcon.swift
import Foundation
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Background gradient (glassy)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let color1 = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.26, alpha: 1)
let color2 = NSColor(calibratedRed: 0.20, green: 0.34, blue: 0.56, alpha: 1)
let gradient = NSGradient(colors: [color1, color2])!
gradient.draw(in: rect, angle: 90)

// Subtle glass highlight
let highlight = NSBezierPath(ovalIn: NSRect(x: size*0.1, y: size*0.6, width: size*0.9, height: size*0.5))
NSColor.white.withAlphaComponent(0.08).setFill()
highlight.fill()

// Center emoji
let emoji = "u2728u2795u2796"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let fontSize = size * 0.42
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: fontSize),
    .paragraphStyle: paragraph,
    .foregroundColor: NSColor.white
]
let textRect = NSRect(x: 0, y: (size - fontSize)/2 - size*0.08, width: size, height: fontSize*1.2)
(emoji as NSString).draw(in: textRect, withAttributes: attributes)

img.unlockFocus()

// Save 1024 png
let pngPath = FileManager.default.currentDirectoryPath + "/icon-1024.png"
guard let tiff = img.tiffRepresentation,
      let rep  = NSBitmapImageRep(data: tiff),
      let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}
try data.write(to: URL(fileURLWithPath: pngPath))

// Resize helper via sips
func gen(_ size: Int, _ name: String) {
    let out = FileManager.default.currentDirectoryPath + "/\(name).png"
    let task = Process()
    task.launchPath = "/usr/bin/sips"
    task.arguments = ["-z", "\(size)", "\(size)", "icon-1024.png", "--out", out]
    task.launch(); task.waitUntilExit()
}

let sizes: [(Int, String)] = [
    (20,  "Icon-20"),
    (29,  "Icon-29"),
    (40,  "Icon-40"),
    (58,  "Icon-58"),
    (60,  "Icon-60"),
    (76,  "Icon-76"),
    (80,  "Icon-80"),
    (87,  "Icon-87"),
    (120, "Icon-120"),
    (152, "Icon-152"),
    (167, "Icon-167"),
    (180, "Icon-180"),
    (1024,"Icon-1024")
]
for (s,n) in sizes { gen(s,n) }

// Write Contents.json
let json = """
{
  "images": [
    {"size":"20x20","idiom":"iphone","scale":"2x","filename":"Icon-40.png"},
    {"size":"20x20","idiom":"iphone","scale":"3x","filename":"Icon-60.png"},
    {"size":"29x29","idiom":"iphone","scale":"2x","filename":"Icon-58.png"},
    {"size":"29x29","idiom":"iphone","scale":"3x","filename":"Icon-87.png"},
    {"size":"40x40","idiom":"iphone","scale":"2x","filename":"Icon-80.png"},
    {"size":"40x40","idiom":"iphone","scale":"3x","filename":"Icon-120.png"},
    {"size":"60x60","idiom":"iphone","scale":"2x","filename":"Icon-120.png"},
    {"size":"60x60","idiom":"iphone","scale":"3x","filename":"Icon-180.png"},
    {"size":"76x76","idiom":"ipad","scale":"1x","filename":"Icon-76.png"},
    {"size":"76x76","idiom":"ipad","scale":"2x","filename":"Icon-152.png"},
    {"size":"83.5x83.5","idiom":"ipad","scale":"2x","filename":"Icon-167.png"},
    {"size":"1024x1024","idiom":"ios-marketing","scale":"1x","filename":"Icon-1024.png"}
  ],
  "info": {"version":1,"author":"xcode"}
}
"""
try json.write(toFile: "Contents.json", atomically: true, encoding: .utf8)
SWIFT

pushd "$APPICON_SET" >/dev/null
/usr/bin/swift "$SWIFT_SCRIPT"
popd >/dev/null

