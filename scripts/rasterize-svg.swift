#!/usr/bin/env swift
// Rasterize an SVG to a square PNG at an exact pixel size.
//
// Usage (run from repo root):
//   swift scripts/rasterize-svg.swift <input.svg> <output.png> <size>
//
// Renders via AppKit's built-in SVG support (`NSImage` + `draw(in:)`), so it
// needs only the Xcode toolchain already required to build the app — no
// Homebrew, librsvg, ImageMagick, or Inkscape. Transparency and anti-aliased
// edges are preserved, and the output is exactly <size>x<size> pixels.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 4, let size = Int(args[3]), size > 0 else {
  FileHandle.standardError.write(
    Data("usage: rasterize-svg.swift <input.svg> <output.png> <size>\n".utf8))
  exit(2)
}
let input = args[1]
let output = args[2]

guard let image = NSImage(contentsOfFile: input) else {
  FileHandle.standardError.write(Data("error: could not load SVG at \(input)\n".utf8))
  exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard
  let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
  FileHandle.standardError.write(Data("error: could not create bitmap context\n".utf8))
  exit(1)
}
context.interpolationQuality = .high

let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphics
image.draw(
  in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
  operation: .sourceOver, fraction: 1.0)
graphics.flushGraphics()

guard let cgImage = context.makeImage() else {
  FileHandle.standardError.write(Data("error: could not render image\n".utf8))
  exit(1)
}

let url = URL(fileURLWithPath: output)
guard
  let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
  FileHandle.standardError.write(Data("error: could not create PNG destination\n".utf8))
  exit(1)
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
  FileHandle.standardError.write(Data("error: could not write PNG to \(output)\n".utf8))
  exit(1)
}
