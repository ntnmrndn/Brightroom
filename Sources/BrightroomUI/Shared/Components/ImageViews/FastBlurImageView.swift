//
//  FastBlurImageView.swift
//  BrightroomUI
//
//  Created by Antoine Marandon on 11/01/2022.
//  Copyright © 2022 muukii. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders

public final class FastBlurImageView: MTKView, MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  public func draw(in view: MTKView) {
    self.draw(view.frame) // needed ?
  }

  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private lazy var commandQueue: MTLCommandQueue? = {
    return self.device!.makeCommandQueue()
  }()

  private lazy var context: CIContext = {
    return CIContext(mtlDevice: self.device!, options: [.workingColorSpace : NSNull()])
  }()


  private var filter: MPSImageGaussianBlur?
  public var image: CIImage? {
    didSet {
      if let image = image {
        func sigma(_ imageExtent: CGRect) -> Float {
          let v = Float(sqrt(pow(imageExtent.width, 2) + pow(imageExtent.height, 2)))
          return v / 20 // ?
        }
        let max: Float = 160
        let value: Float = 80


        let sigma = sigma(image.extent) * value / max
        self.filter = MPSImageGaussianBlur(device: self.device!, sigma: sigma)//XXX
      } else {
        self.filter = nil
      }
      setNeedsDisplay()
    }
  }


  override public init(
    frame frameRect: CGRect,
    device: MTLDevice?
  ) {
    super.init(
      frame: frameRect,
      device: device ?? MTLCreateSystemDefaultDevice()
    )
    if super.device == nil {
      fatalError("Device doesn't support Metal")
    }
    isOpaque = false
    backgroundColor = .clear
    framebufferOnly = false
    delegate = self
    enableSetNeedsDisplay = true
    autoResizeDrawable = true
    contentMode = .scaleAspectFill
    clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
    clearsContextBeforeDrawing = true
    isPaused = true
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("Not implementend")
  }


  public override func draw(_ rect: CGRect) {
    let date = Date()
    guard let image = image,
          let currentDrawable = currentDrawable,
          let commandBuffer = commandQueue?.makeCommandBuffer()
    else {
      return
    }
    let currentTexture = currentDrawable.texture
    let drawingBounds = CGRect(origin: .zero, size: drawableSize)

    let scaleX = drawableSize.width / image.extent.width
    let scaleY = drawableSize.height / image.extent.height
    let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    print("timeStamp 1: \(date.timeIntervalSinceNow)")
    context.render(scaledImage, to: currentTexture, commandBuffer: commandBuffer, bounds: drawingBounds, colorSpace: colorSpace)

    commandBuffer.present(currentDrawable)

    let filterDate = Date()
    if let filter = filter {
      let inplaceTexture = UnsafeMutablePointer<MTLTexture>.allocate(capacity: 1)
      inplaceTexture.initialize(to: currentTexture)
      filter.encode(commandBuffer: commandBuffer, inPlaceTexture: inplaceTexture, fallbackCopyAllocator: nil)
    }
    commandBuffer.commit()
    let end = date.timeIntervalSinceNow
    let filterEnd = filterDate.timeIntervalSinceNow
    print("Made fast render in \(end)")
    print("Made non buisness render in \(filterEnd)")
  }
}
