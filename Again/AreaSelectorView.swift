//
//  AreaSelectorView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 25.01.25.
//

import UIKit

enum AreaSelectorState {
    case none
    case inProgress
    case done
}

class AreaSelectorView: UIView {
    private var cornerPoints: [UIView] = []
    private let selectionLayer = CAShapeLayer()
    private let pointSize: CGFloat = 20
    private let pointColor = UIColor.blue
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAreaSelector()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAreaSelector()
    }
    
    private func setupAreaSelector() {
        selectionLayer.fillColor = UIColor.blue.withAlphaComponent(0.2).cgColor
        selectionLayer.strokeColor = UIColor.blue.cgColor
        selectionLayer.lineWidth = 2
        layer.addSublayer(selectionLayer)
        
        for _ in 0..<4 {
            let pointView = UIView()
            pointView.backgroundColor = pointColor
            pointView.layer.cornerRadius = pointSize / 2
            pointView.isUserInteractionEnabled = true
            addSubview(pointView)
            cornerPoints.append(pointView)
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pointView.addGestureRecognizer(panGesture)
        }
        
        centerInitialArea()
    }
    
    private func centerInitialArea() {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let initialSize: CGFloat = 50
        
        cornerPoints[0].frame = CGRect(x: centerX - initialSize/2, y: centerY - initialSize/2, width: pointSize, height: pointSize)
        cornerPoints[1].frame = CGRect(x: centerX + initialSize/2 - pointSize, y: centerY - initialSize/2, width: pointSize, height: pointSize)
        cornerPoints[2].frame = CGRect(x: centerX + initialSize/2 - pointSize, y: centerY + initialSize/2 - pointSize, width: pointSize, height: pointSize)
        cornerPoints[3].frame = CGRect(x: centerX - initialSize/2, y: centerY + initialSize/2 - pointSize, width: pointSize, height: pointSize)
        
        updateSelectionLayer()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let pointView = gesture.view else { return }
        let translation = gesture.translation(in: self)
        
        pointView.center = CGPoint(
            x: pointView.center.x + translation.x,
            y: pointView.center.y + translation.y
        )
        
        gesture.setTranslation(.zero, in: self)
        constrainPointMovement(movedPoint: pointView)
        updateSelectionLayer()
    }
    
    private func constrainPointMovement(movedPoint: UIView) {
        // Allow full frame coverage
        movedPoint.frame.origin.x = max(0, min(movedPoint.frame.origin.x, bounds.width - pointSize))
        movedPoint.frame.origin.y = max(0, min(movedPoint.frame.origin.y, bounds.height - pointSize))
        
        let points = cornerPoints
        
        // Maintain rectangular constraints
        if movedPoint == points[0] {
            points[1].frame.origin.y = points[0].frame.origin.y
            points[3].frame.origin.x = points[0].frame.origin.x
        } else if movedPoint == points[1] {
            points[0].frame.origin.y = points[1].frame.origin.y
            points[2].frame.origin.x = points[1].frame.origin.x
        } else if movedPoint == points[2] {
            points[3].frame.origin.y = points[2].frame.origin.y
            points[1].frame.origin.x = points[2].frame.origin.x
        } else if movedPoint == points[3] {
            points[0].frame.origin.x = points[3].frame.origin.x
            points[2].frame.origin.y = points[3].frame.origin.y
        }
    }
    
    private func updateSelectionLayer() {
        let path = UIBezierPath()
        path.move(to: cornerPoints[0].center)
        path.addLine(to: cornerPoints[1].center)
        path.addLine(to: cornerPoints[2].center)
        path.addLine(to: cornerPoints[3].center)
        path.close()
        
        selectionLayer.path = path.cgPath
    }
    
    func getSelectedArea() -> CGRect {
        let points = cornerPoints.map { $0.center }
        let minX = points.min(by: { $0.x < $1.x })!.x
        let maxX = points.max(by: { $0.x < $1.x })!.x
        let minY = points.min(by: { $0.y < $1.y })!.y
        let maxY = points.max(by: { $0.y < $1.y })!.y
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
