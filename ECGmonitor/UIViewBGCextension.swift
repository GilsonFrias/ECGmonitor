//
//  UIViewBGCextension.swift
//  ECGmonitor
//
//  Created by Gilson on 2019/11/20.
//  Copyright © 2019 Gilosn Frias . All rights reserved.
//  Based on the Youtube video tutorial by Sean Allen: https://www.youtube.com/watch?v=3gUNg3Jhjwo

import Foundation
import UIKit

extension UIView {
    func setGradientBackground(color0:UIColor, color1:UIColor) {
        let gradient = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = [color0.cgColor, color1.cgColor]
        self.layer.insertSublayer(gradient, at: 0)
    }
}
