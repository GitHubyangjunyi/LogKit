//
//  LogCategory.swift
//  LogKit
//
//  Created by 杨俊艺 on 2026/11/13.
//

import Foundation

public enum LogCategory: String, Sendable, CaseIterable {
	case network = "NetWork"
    case bluetooth = "Bluetooth"
    case performance = "Performance"
	case pointsOfInterest = "PointsOfInterest"
    case viewControllerLife = "UIViewControllerLife"
}
