//
//  QRSdetector.swift
//  Created by Gilson Frías  on 2019/09/06.
//  Copyright © 2019 Gilson Frías. All rights reserved.
//  Implementation of the QRS detection algorithm proposed by Zong et al [1]. The algorithm is based on the calculation of the curve length transform of the ECG time series and the posterior detection of the QRS onsets by thresholding methods.
//  [1] "A Robust Open-source Algorithm to Detect Onset and Duration of QRS Complexes", W Zong, GB Moody, D Jiang

import Foundation
import simd  //for vector operations (i.e. dot product calculation)

class QRSdetector {
    let fs: Double!     //Sampling frequency
    let gain: Double!   //ADC gain?
    let lfsc: Double!   //length function scale constant
    let N: Int!         //Low-pass filter order
    let a: [Double]!    //filter coefficients
    let a_simd: simd_double8!
    let b: [Double]!    //filter coefficients
    let b_simd: simd_double8!
    let w: Int!         //length transform window size defined over 130 msec. of ECG data
    //var TmDEF: Int!   //Default threshold value
    var Th: Double!     //Threshold value variable
    var isTraining: Bool!
    var cnt: Int!
    let _10s: Int!      //The amount of samples equivalent to 10 sec. of ECG recording
    //let _15s: Int!
    var t0: Int!        //Location of previous inflection point located on Lenght Transform signal
    var t1: Int!        //Location of next inflection point on Lenght Transform signal
    var RR_pointer: Int!//
    var avgRRval: Double!
    var avgHRval: Int!
    var closedEye: Bool!//flag variable used to mark the closed eye period in the thresholding process
    let closedEyePeriod: Int! //150 msec.
    var closedEyeIndex: Int! //marks the beginning of the closed eye period
    var input: [Double]!
    var filtered: [Double]!     //low-pass filtered array
    var differential: [Double]! //contains differentiated ECG samples
    var output: [Double]!       //Lenght Transform data output
    var x_buffer: [Double]!     //keeps history of last N input samples
    var y_buffer: [Double]!     //keeps history of last N filtered samples
    var last: Double!           //Last sample processed by the lenghtTrans function
    var RR_array: [Double]!     //keeps the history of R-R intervals registerd over 5 sec. period
    var HR_array: [Double]!
    var maxHR: Int!           //The maximum Heart Rate registered
    var minHR: Int!           //The minimum Heart Rate registered
    var numHB: Int!           //Number of Heart beats detected
    var HRcnt: Int!           //Keeps the total amount of Heart Rate computations
    
    //Initilize class
    init(){
        self.fs = cfs 
        self.gain = 1.0
        self.lfsc = 1.25*(gain*gain)/Double(fs)
        self.N = 4
        self.cnt = 0
        self._10s = Int(self.fs*10+1)
        self.t0 = 0
        self.t1 = 0
        self.RR_pointer = 0
        self.avgRRval = 0
        self.avgHRval = 0
        self.closedEye = false
        self.closedEyePeriod = Int(self.fs*0.15+1)
        //Recalculated filter coefficients for 360 Hz fs
        self.a = a360
        self.b = b360
        self.a_simd = simd_double8(Array(a[1...N])+Array(repeating:0.0, count: 8-Array(a[1...N]).count))
        self.b_simd = simd_double8(b+Array(repeating:0.0, count: 8-b.count))
        self.w = Int(self.fs*0.130+1)
        self.Th = 0
        self.isTraining = true
        self.input = Array(repeating: 0.0, count: self.w)
        self.filtered = Array(repeating: 0.0, count: self.w)
        self.differential = [0.0]
        self.x_buffer = Array(repeating: 0.0, count: self.N)
        self.y_buffer = Array(repeating: 0.0, count: self.N)
        self.output = [0.0]
        self.last = 0.0
        self.RR_array = Array(repeating: 0.0, count: Int(self._10s/2))
        self.HR_array = Array(repeating: 0, count: 12)
        self.maxHR = -1
        self.minHR = -1
        self.numHB = 0
        self.HRcnt = 0
    }
    
    /*
    Perform low pass filtering on the samples contained in 'inarray'. Also, update
    'differential' array with newly computed differential samples.
    */
    func lowPass(inarray:[Double]) -> [Double] {
        //Retrieve last N processed samples
        x_buffer = Array(input[0...N])
        y_buffer = Array(filtered[0...N])

        for x_n in inarray{
            input.removeLast()
            input.insert(x_n, at: 0)
            x_buffer.removeLast()
            y_buffer.removeLast()
            x_buffer.insert(x_n, at: 0)
            //Construct simd vectors with the x, y, b and a arrays to perform convolution. Pad vectors with tailing zeroes.
            let x_padded = x_buffer+Array(repeating:0.0, count: 8-x_buffer.count)
            let x_simd = simd_double8(x_padded)
            let y_padded = y_buffer+Array(repeating:0.0, count: 8-y_buffer.count)
            let y_simd = simd_double8(y_padded)
            //Perform filtering
            let y_n = simd_dot(x_simd, b_simd) - simd_dot(y_simd, a_simd)
            //Update arrays
            filtered.removeLast()
            filtered.insert(y_n, at: 0)
            y_buffer.insert(y_n, at: 0)
            let dy_n = y_n - last  //Differential sample
            if(differential.count>=2*w){
                differential.removeLast()
            }
            differential.insert(dy_n, at:0)
            last = y_n
        }
        lenghtTrans(sampleCount: inarray.count)
        return Array(filtered[0...inarray.count])
    }
    
    //Function that implements the Lenght Transform algorithm as presented on [1]
    /*However, as of Nov. 22th 2019, Adaptive thresholding has not been implemented yet.
    A fixed threshold value is used to process all heartbeats*/
    func lenghtTrans(sampleCount:Int){
        var lArray: [Double] = []
        if(differential.count<sampleCount+w){
            for i in 1...sampleCount{
                let dif_2 = Array(differential.suffix(from: sampleCount-i)).map{$0 * $0}
                lArray += [sqrSum(inarray: dif_2)]
            }
        }else{
            for i in 1...sampleCount{
                let dif_2 = Array(differential[sampleCount-i...sampleCount+w-i]).map{$0 * $0}
                lArray += [sqrSum(inarray: dif_2)]
            }
        }
        if(lArray.count+output.count>=2*w){
            _ = output.dropLast(lArray.count)
        }
        output.insert(contentsOf: lArray, at: 0)
        cnt+=lArray.count
        if(isTraining){
            Th+=lArray.reduce(0, +)
            //After 10 seconds of ECG recording, compute threshold value 'Th'
            if(cnt>=_10s){
                Th/=Double(_10s)
                Th*=1.5
                isTraining = false
                RR_pointer = cnt
            }
        }else{
            if(!closedEye){
                let th_array = lArray.map{ ($0 >= Th) ? 1 : 0 }
                //Look for first crossing point above 'Th'
                var RR = 0.0
                if let index = th_array.firstIndex(of: 1) {
                    t0 = t1
                    t1 = cnt - lArray.count - index
                    //Obtain R-R interval
                    RR = Double(t1-t0)/fs
                    //print("***RR: \(RR)***")
                    closedEye = true  //Go on closed eye period
                    closedEyeIndex = cnt
                    numHB += 1
                }
                if (RR_pointer<RR_array.count) {  //RR_array.count
                    RR_array[RR_pointer] = RR
                }else {
                    //Calculate average R-R interval over all registered intervals on 'RR_array'
                    _ = avgRR()
                    let fs_Int = Int(fs)
                    let padding = Array(repeating: 0.0, count: fs_Int)
                    //Drop the equivalent of 1 sec. of ECG recording samples from RR_array
                    RR_array.removeFirst(fs_Int)
                    RR_array += padding
                    //Move pointer to the start of padding data (array of zeroes)
                    RR_pointer -= fs_Int
                }
                RR_pointer+=1
            }else if (cnt-closedEyeIndex>=closedEyePeriod) {
                closedEye = false
            }
        }
    }
    
    //Implements the summation of the square root of the differential signal
    func sqrSum(inarray:[Double]) -> Double{
        let sqr = inarray.map{$0 + lfsc}.map{pow($0, 0.5)}
        let sum = sqr.reduce(0, +)
        return sum
    }
    
    //Returns the average R-R interval
    func avgRR() -> Int{
        var effective_RR = Double(RR_array.filter{ $0 > 0 }.count)
        //How many Heartbeats can be counted on a 5 sec. period
        let tmp_avgHR = 12*effective_RR/5.0
        effective_RR = (effective_RR > 0) ? effective_RR : 1.0 //avoid dividing by zero
        let tmp_avgRR = RR_array.reduce(0.0, +)/effective_RR
        HRcnt += 1
        //HRcnt += 1
        //print("lenght: \(HR_array.count)")
        //print("****Av RR:****")
        //print(tmp_avgRR)
        avgRRval = tmp_avgRR
        avgHRval = Int(tmp_avgHR)
        if (HRcnt>=12) {
            _ = HR_array.removeLast()
            HR_array.insert(tmp_avgHR, at: 0)
            if (maxHR == -1 && minHR == -1){
                maxHR = Int(tmp_avgHR)
                minHR = maxHR
            }else {
                maxHR = (Int(tmp_avgHR)>maxHR) ? Int(tmp_avgHR) : maxHR
                minHR = (Int(tmp_avgHR)<minHR) ? Int(tmp_avgHR) : minHR
            }
        }
        return Int(tmp_avgRR)
    }
}
