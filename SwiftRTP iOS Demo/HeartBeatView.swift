//
//  HeartBeatView.swift
//  iSolo
//
//  Created by Jonathan Wight on 9/21/15.
//  Copyright © 2015 3d Robotics. All rights reserved.
//

import UIKit

@IBDesignable public class HeartbeatView: UIView {

    var eventsForHash: [Int: String] = [:]
    var maxEvents: Int = 16
    var duration: CFTimeInterval = 5

    public func handleEvent(event: String) {

        let hashFraction = CGFloat(fractionForEvent(event))

        if eventsForHash[hash] == nil {
            eventsForHash[hash] = event
        }

        let radius = CGFloat(5)
        let color = colorForEvent(event)
        let newLayer = CAShapeLayer()
        newLayer.path = CGPathCreateWithEllipseInRect(CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), nil)
        newLayer.fillColor = color.CGColor
        newLayer.strokeColor = nil

        newLayer.position = CGPoint(
            x: hashFraction * bounds.size.width,
            y: bounds.size.height
            )

        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.toValue = CGPathCreateWithEllipseInRect(CGRect(x: 0, y: 0, width: 0, height: 0), nil)

        let positionAnimation = CABasicAnimation(keyPath: "position.y")
        positionAnimation.toValue = 0

        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [ pathAnimation, positionAnimation ]
        groupAnimation.delegate = self
        groupAnimation.duration = duration
        groupAnimation.setValue(newLayer, forKey: "layer")

        newLayer.addAnimation(groupAnimation, forKey: "groupAnimation")
        layer.addSublayer(newLayer)
    }

    public func fractionForEvent(event: String) -> Double {
        let hash = abs(event.hashValue % maxEvents)
        let hashFraction = Double(hash) / Double(maxEvents)
        return hashFraction
    }

    public func colorForEvent(event: String) -> UIColor {
        let hashFraction = CGFloat(fractionForEvent(event))
        let color = UIColor(hue: hashFraction, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        return color
    }

    public override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        guard let layer = anim.valueForKey("layer") as? CALayer else {
            Swift.print("No layer")
            return
        }
        layer.modelLayer().removeFromSuperlayer()
    }
}