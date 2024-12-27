//
//  UIBezierPath+Ext.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 25.12.24.
//

import UIKit

extension UIBezierPath {
    convenience init(cornersOfRect borderRect: CGRect, cornerSize: CGSize, cornerRadius: CGFloat) {
        self.init()
        let cornerSizeH = cornerSize.width
        let cornerSizeV = cornerSize.height
        // top-left
        move(to: CGPoint(x: borderRect.minX, y: borderRect.minY + cornerSizeV + cornerRadius))
        addLine(to: CGPoint(x: borderRect.minX, y: borderRect.minY + cornerRadius))
        addArc(withCenter: CGPoint(x: borderRect.minX + cornerRadius, y: borderRect.minY + cornerRadius),
               radius: cornerRadius,
               startAngle: CGFloat.pi,
               endAngle: -CGFloat.pi / 2,
               clockwise: true)
        addLine(to: CGPoint(x: borderRect.minX + cornerSizeH + cornerRadius, y: borderRect.minY))
        // top-right
        move(to: CGPoint(x: borderRect.maxX - cornerSizeH - cornerRadius, y: borderRect.minY))
        addLine(to: CGPoint(x: borderRect.maxX - cornerRadius, y: borderRect.minY))
        addArc(withCenter: CGPoint(x: borderRect.maxX - cornerRadius, y: borderRect.minY + cornerRadius),
               radius: cornerRadius,
               startAngle: -CGFloat.pi / 2,
               endAngle: 0,
               clockwise: true)
        addLine(to: CGPoint(x: borderRect.maxX, y: borderRect.minY + cornerSizeV + cornerRadius))
        // bottom-right
        move(to: CGPoint(x: borderRect.maxX, y: borderRect.maxY - cornerSizeV - cornerRadius))
        addLine(to: CGPoint(x: borderRect.maxX, y: borderRect.maxY - cornerRadius))
        addArc(withCenter: CGPoint(x: borderRect.maxX - cornerRadius, y: borderRect.maxY - cornerRadius),
               radius: cornerRadius,
               startAngle: 0,
               endAngle: CGFloat.pi / 2,
               clockwise: true)
        addLine(to: CGPoint(x: borderRect.maxX - cornerSizeH - cornerRadius, y: borderRect.maxY))
        // bottom-left
        move(to: CGPoint(x: borderRect.minX + cornerSizeH + cornerRadius, y: borderRect.maxY))
        addLine(to: CGPoint(x: borderRect.minX + cornerRadius, y: borderRect.maxY))
        addArc(withCenter: CGPoint(x: borderRect.minX + cornerRadius,
                                   y: borderRect.maxY - cornerRadius),
               radius: cornerRadius,
               startAngle: CGFloat.pi / 2,
               endAngle: CGFloat.pi,
               clockwise: true)
        addLine(to: CGPoint(x: borderRect.minX, y: borderRect.maxY - cornerSizeV - cornerRadius))
    }
}
