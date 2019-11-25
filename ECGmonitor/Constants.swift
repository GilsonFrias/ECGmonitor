//
//  Constants.swift
//  ECGmonitor
//
//  Created by Gilson on 2019/11/20.
//  Copyright © 2019 Gilosn Frias . All rights reserved.
//  Constant values file

import Foundation
import UIKit

let ECGserviceUUID = "0000180D-4d5f-11e9-8646-d663bd873d93"
let ECGcharacteristicUUID = "00002A37-4d5f-11e9-8646-d663bd873d93"
let BTbuffer_capacity = 12

let cfs = 360.0

//Low-pass filter coefficients
let a360 = [ 1.0, -3.27139334,  4.06804375, -2.27301796,  0.48069533]
let b360 = [0.00027049, 0.00108194, 0.00162292, 0.00108194, 0.00027049]

//Color palette used in the app
struct colors {
    static let background0 = UIColor(displayP3Red: 0/255, green: 115/255, blue: 230/255, alpha: 1)
    static let background1 = UIColor(displayP3Red: 128/255, green: 191/255, blue: 255/255, alpha: 1)
    static let launch = UIColor(displayP3Red: 179/255, green: 179/255, blue: 204/255, alpha: 0.75)
    static let ecgDesc = UIColor(displayP3Red: 204/255, green: 102/255, blue: 0/255, alpha: 1)
    static let ecgData = UIColor(displayP3Red: 153/255, green: 0/255, blue: 0/255, alpha: 1)
    static let hrData =  UIColor(displayP3Red: 102/255, green: 102/255, blue: 255/255, alpha: 1)
    static let defaultData = UIColor(displayP3Red: 51/255, green: 102/255, blue: 0/255, alpha: 1)
    static let hrCircles = UIColor(displayP3Red: 102/255, green: 102/255, blue: 255/255, alpha: 1)
    static let hrValues = UIColor(displayP3Red: 0/255, green: 0/255, blue: 255/255, alpha: 1)
    //static let chartBackground = UIColor(displayP3Red: 179/255, green: 224/255, blue: 255/255, alpha: 1)
    static let chartBackground = UIColor(displayP3Red: 246/255, green: 246/255, blue: 246/255, alpha: 1)
    static let bar = UIColor(displayP3Red: 255/255, green: 255/255, blue: 153/255, alpha: 1)
    static let bar0 = UIColor(displayP3Red: 255/255, green: 255/255, blue: 153/255, alpha: 1)
    static let bar1 = UIColor(displayP3Red: 194/255, green: 214/255, blue: 214/255, alpha: 1)
    static let hrLabel = UIColor(displayP3Red: 51/255, green: 0/255, blue: 0/255, alpha: 0.5)
    static let featuresBackground = UIColor(displayP3Red: 153/255, green: 153/255, blue: 102/255, alpha: 1)
    static let contentBackground = UIColor(displayP3Red: 162/255, green: 195/255, blue: 195/255, alpha: 1)
    //static let contentBackground = UIColor(displayP3Red: 148/255, green: 184/255, blue: 184/255, alpha: 1)
    static let button = UIColor(displayP3Red: 51/255, green: 0/255, blue: 0/255, alpha: 1)
    static let pageIndicatorCheck = UIColor(displayP3Red: 204/255, green: 204/255, blue: 0/255, alpha: 1)
    static let pageIndicatorUncheck = UIColor(displayP3Red: 230/255, green: 255/255, blue: 255/255, alpha: 1)
}

