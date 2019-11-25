//
//  ViewController.swift
//  ECGmonitor
//
//  Created by Gilson Frías  on 2019/08/15.
//  Copyright © 2019 Gilosn Frías . All rights reserved.

//ECGmonitor lets you visualize and analyze streamed ECG data in real time. By pairing with an ECG sensor via the Bluetooth Low Energy (BLE) communication standard, ECG samples can be accessed from the 'ECGQueue' queue-modeled structure.
//The app UI is esentially structured as follows:
//1. A top view 'ecgView' continuously display the real time ECG data
//2. A lower UIScrollView 'featuresView' serves as a container for two child views:
//   2.1. 'sensorView' shows relevant information about the paired wearable sensor
//   2.2. 'statsView' displays statistical info mainly related to Heart Rate variability


import UIKit
import Charts
import CoreBluetooth


class ViewController:UIViewController, UIScrollViewDelegate,  CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //connectButton handles the initiation/termination of BLE communication with sensor
    let connectButton = UIButton()
    
    @objc func wearableConnect(sender: UIButton!){
        if(discovered_peripheral) {
            self.centralManager.connect(self.wearableECGPeripheral)
            connectButton.setTitle("Disconnet", for: UIControl.State.normal)
        }
    }
    
    //UIView setups
    //Launch view
    let launchView: UIView = UIView()
    let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
    let actLabel: UITextView = UITextView()
    
    //Top view
    let ecgView: LineChartView = LineChartView()
    var HRlabel: UILabel = UILabel()
    //Lower view
    let featuresView: UIScrollView = UIScrollView()
    //1
    let sensorView: UIView = UIView()
    let sensorText = styledText()
    //2
    let statsView: UIView = UIView()
    let hrView: LineChartView = LineChartView()
    let statsText = styledText()
    //3
    //let customView: UIView = UIView()
    //let customPlotView: LineChartView = LineChartView()
    //let CVlabel: UILabel = UILabel()
    
    let pageControl: UIPageControl = UIPageControl()
    var pageNumber: Int! = 0
    
    //Main view dimmensions
    var viewWidth: CGFloat = 0.0
    var viewHeight: CGFloat = 0.0
    
    //Instance of the Heart Rate calculation class
    let QRS = QRSdetector()
    
    //BLE variables
    let ECGServiceCBUUID = CBUUID(string: ECGserviceUUID)
    let ECGCharacteristicCBUUID = CBUUID(string: ECGcharacteristicUUID)
    var centralManager: CBCentralManager!
    var wearableECGPeripheral: CBPeripheral!
    var discovered_peripheral = false
    
    //The container of the ECG data. Make sure to retrieve the ECG data from this structure.
    var ECGQueue:[Double] = []
    
    var CViewQueue:[Double] = []
    
    var cnt:Int!               //keeps track of number of notification updates on incomming samples
   
    var BTbuffer:[Double] = [] //Holds samples received on Bluetooth packages
    
    
    /*Print out the current state of the Core Bluetooth device. If device is
     powered on, start scanning for wearable ECG sensors.*/
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state:String
        switch central.state {
        case .unknown:
            print("central.state is UNKNOWN")
            state = "BT state is UNKNOWN"
            actLabel.text = "Unable to initialize Bluetooth communication: "+state
            actInd.stopAnimating()
        //status_queue+=[state]
        case .resetting:
            print("central.state is RESETTING")
            state = "BT state is RESETTING"
            actLabel.text = "Unable to initialize Bluetooth communication: "+state
            actInd.stopAnimating()
        //status_queue+=[state]
        case .unsupported:
            print("central.state is UNSUPPORTED")
            state = "BT state is UNSUPPORTED"
            actLabel.text = "Unable to initialize Bluetooth communication: "+state
            actInd.stopAnimating()
        //status_queue+=[state]
        case .unauthorized:
            print("central.state is UNAUTHORIZED")
            state = "BT state is UNAUTHORIZED"
            actLabel.text = "Unable to initialize Bluetooth communication: "+state
            actInd.stopAnimating()
        //status_queue+=[state]
        case .poweredOff:
            print("central.state is POWEREDOFF")
            state = "BT state is POWEREDOFF"
            actLabel.text = "Bluetooth is disabled, please enable it on settings."
        //status_queue+=[state]
        case .poweredOn:
            print("central.state is POWEREDON")
            print("Scanning for wearable ECG device...")
            actLabel.text = "Scanning for wearable devices..."
            centralManager.scanForPeripherals(withServices: [ECGServiceCBUUID])
        @unknown default:
            fatalError()
        }
    }
    
    //When wearable ECG sensor is discovered, try stablishing a connection
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered Peripheral:")
        print(peripheral)
        actLabel.text = "Discovered Peripheral: "+peripheral.name!+"\n Press 'Connect' to start connection"
        wearableECGPeripheral = peripheral
        wearableECGPeripheral.delegate = self
        centralManager.stopScan()
        self.discovered_peripheral = true
    }
    
    //Instantiate Peripheral service on connection
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connection stablished!")
        //remove launch view
        actInd.stopAnimating()
        view.sendSubviewToBack(launchView)
        wearableECGPeripheral.discoverServices([ECGServiceCBUUID])
        HRlabel.alpha = 0.7
        connectButton.setTitle("Disconnect", for: UIControl.State.normal)
        sensorText.updateText(key: "Status", value: "Connected")
        sensorText.updateText(key: "Sampling rate", value: String(Int(QRS.fs))+" Hz")
        sensorText.updateText(key: "Device name", value: peripheral.name ?? "--")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Connection lost!")
        //self.statusLabel.text = "Connection lost!"
        connectButton.setTitle("Connect", for: UIControl.State.normal)
        sensorText.updateText(key: "Status", value: "Disconnected")
    }
    
    //Register Peripheral service when the ECG service is available
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {return}
        for service in services {
            print("Service discovered:")
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    //Register the ECG characteristic (the structure handling the ECG samples)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {return}
        var properties = [String]()
        for characteristic in characteristics {
            print("Discovered characteristic:")
            print(characteristic)
            if characteristic.uuid == ECGCharacteristicCBUUID {
                if characteristic.properties.contains(.broadcast){
                    properties.append("Broadcast")
                }
                if characteristic.properties.contains(.read){
                    print("\(characteristic.uuid): contains READ property.")
                    peripheral.readValue(for: characteristic)
                    properties.append("Read")
                }
                if characteristic.properties.contains(.notify){
                    print("\(characteristic.uuid): contains NOTIFY property.")
                    peripheral.setNotifyValue(true, for: characteristic)
                    properties.append("Notify")
                }
                if characteristic.properties.contains(.write){
                    properties.append("Write")
                }
                print("--<>--")
                let propTxt = properties.reduce(""){prev, next in "\(prev),\(next)"}.dropFirst()
                print(ECGCharacteristicCBUUID.uuidString)
                sensorText.updateText(key: "UUID", value: ECGCharacteristicCBUUID.uuidString)
                sensorText.updateText(key: "Properties", value: String(propTxt))
            }
        }
    }
    
    //When notification on changes on characteristic are available, read ECG samples and update graphs
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("Updated characteristic value.")  //Debugging
        switch characteristic.uuid {
        case ECGCharacteristicCBUUID:
            _ = getECGsamples(from: characteristic)
            //print(ECG_samples[0])
        //print(ECG_samples[1])
        default:
            print("Unhandled Charasteristic UUID: \(characteristic.uuid)")
        }
    }
    
    //Refresh ECG and HR LineChartViews with provided data
    func updateChart(chart: LineChartView, data: [Double], type: String){
        var dataEntries: [ChartDataEntry] = []
        for (n, x) in data.enumerated(){
            //x label on intervals of 5 seconds for HR chart
            let entry = ChartDataEntry(x: Double(n*5), y: x)
            dataEntries.append(entry)
        }
        let dataSet:LineChartDataSet
        let dataLabel:String
        let color:UIColor
        
        //Style graph according to the type of source data
        switch type {
        case "ECG":
            dataLabel = "ECG Data"
            color = colors.ecgData
            dataSet = LineChartDataSet(entries: dataEntries, label: dataLabel)
            dataSet.drawCirclesEnabled = false
            dataSet.drawCircleHoleEnabled = false
        case "HR":
            dataLabel = "Av. Hearth Rate on 5 sec. intervals"
            color = colors.hrData
            dataSet = LineChartDataSet(entries: dataEntries, label: dataLabel)
            dataSet.drawCirclesEnabled = true
            dataSet.drawCircleHoleEnabled = true
            dataSet.circleRadius = CGFloat(4)
            dataSet.circleHoleRadius = CGFloat(2)
            dataSet.circleColors = [colors.hrCircles]
            dataSet.valueTextColor = colors.hrValues
            dataSet.valueFont = .boldSystemFont(ofSize: 10)
        case "Custom":
            dataLabel = "Custom"
            color = colors.hrData
            dataSet = LineChartDataSet(entries: dataEntries, label: dataLabel)
            dataSet.drawCirclesEnabled = false
            dataSet.drawCircleHoleEnabled = false
        default:
            dataLabel = ""
            color = colors.defaultData
            dataSet = LineChartDataSet(entries: dataEntries, label: dataLabel)
        }

        dataSet.colors = [color]
        dataSet.lineWidth = 2.0
        //Animate chart progression
        chart.data = LineChartData(dataSet: dataSet)
        let duration = Int(data.count*(1/Int(cfs)))
        chart.animate(xAxisDuration: TimeInterval(duration), easingOption: .linear)
    }
    

    //Read 2 new 16 bits ECG samples when ECGCharacteristic updates
    private func getECGsamples(from characteristic: CBCharacteristic) -> [Int] {
        guard let characteristicData = characteristic.value else {return [-1, -1]}
        //ECG data is given as two 16 bits samples packed on a 32 bits signed int
        var byteArray = [UInt8](characteristicData)
        if(byteArray.count==0){
            byteArray = Array(repeating: 0, count: 4)
            return [-1, -1]
        }
        //Unpack samples
        var sample0:Int = 0
        //var sample0:UInt16 = 0
        var sample1:Int = 0
        //var sample1:UInt16 = 0
        let bitMask:UInt8 = 0b11111111
        sample0 = Int(byteArray[3] & bitMask)
        sample0 *= 256 //Shift one byte to the left
        sample0 += Int(byteArray[2])  //Store LS byte
        //Repeat process for second ECG sample
        sample1 = Int(byteArray[1] & bitMask)
        sample1 *= 256 //Shift one byte to the left
        sample1 += Int(byteArray[0])  //Store LS byte
        cnt+=1
        BTbuffer.removeFirst(2)
        BTbuffer.append(Double(sample0))
        BTbuffer.append(Double(sample1))
        //Push samples to QRS detector
        _ = QRS.lowPass(inarray: [Double(sample0), Double(sample1)])
        if(cnt==BTbuffer_capacity){
            //if BTbuffer is full, move content to EcgGraphBuffer
            ECGQueue.removeFirst(BTbuffer_capacity)
            ECGQueue+=BTbuffer
            //Update ECG chart
            updateChart(chart: ecgView, data: ECGQueue, type: "ECG")
            cnt = 0
            //-----<testing>------
            //let customData = ECGViewQueue.map({$0})
            //plot(inArray:ECGViewQueue, label:"Sin(ECG)")
        }
        if(QRS.cnt%150==0 && !QRS.isTraining){
            if(QRS.maxHR != -1){
                HRlabel.text = String(format: "HR: %d BPM", QRS.avgHRval)
                //statsText.updateText(key: "Av. R-R interval", value: String(QRS.avgRRval)+" msec.")
                statsText.updateText(key: "Av. R-R interval", value: String(format:"%.2f sec.", QRS.avgRRval))
                statsText.updateText(key: "Max. Heart Rate", value: String(format:"%d BPM", QRS.maxHR))
                statsText.updateText(key: "Min. Heart Rate", value: String(format:"%d BPM", QRS.minHR))
            }
            statsText.updateText(key: "Total heartbeats detected", value: String(QRS.numHB))
            updateChart(chart: hrView, data: QRS.HR_array, type:"HR")
        }
        return([sample0, sample1])
    }
    
    
   //Set layout for landscape mode. TO DO: fix landscape layout
   /*
   override func viewWillTransition( to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator ) {
      DispatchQueue.main.async() {
        if(UIDevice.current.orientation.isLandscape){
            /*This should be changed to allow scrolling through all subviews in featuresView.
            in the mean time, after a rotation to landscape mode, lock featuesView into customView.*/
            //let x = 2*self.viewWidth
            //let point = CGPoint(x: x, y: 0.0)
            //self.featuresView.setContentOffset(point, animated: true)
            //self.featuresView.isPagingEnabled = false
            //self.featuresView.isScrollEnabled = false
            //self.pageControl.currentPage = 2
            
        }else{
            //print("featuresView contentSize width: \(self.featuresView.contentSize.width)")
            //Re-enable scrolling and paging in portrait mode
            self.featuresView.isPagingEnabled = true
            self.featuresView.isScrollEnabled = true
        }
      }
    }*/
    
    //Allow only scrolling in the x axis. Update 'pageControl' indicator to actual page
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //scrollView.contentOffset.y = 0
        let pageWidth = scrollView.frame.width
        let currentPage = round(scrollView.contentOffset.x/pageWidth)
        switch currentPage {
        case 0:
            pageControl.currentPage = 0
        case 1:
            pageControl.currentPage = 1
        //case 2:
            //pageControl.currentPage = 2
        default:
            pageControl.currentPage = 1
        }
    }
    
    
    func applyConstraints() {
        /*--- Configure ECG chart attributes ---*/
        super.view.addSubview(ecgView)
        //Autolayout
        ecgView.translatesAutoresizingMaskIntoConstraints = false
        ecgView.centerXAnchor.constraint(equalTo: super.view.centerXAnchor).isActive = true
        ecgView.topAnchor.constraint(equalTo: super.view.topAnchor, constant: 50.0).isActive = true
        ecgView.widthAnchor.constraint(equalTo: super.view.widthAnchor, multiplier: 0.95).isActive = true
        ecgView.heightAnchor.constraint(equalTo: super.view.heightAnchor, multiplier: 0.40).isActive = true
        //Chart styling
        ecgView.chartDescription?.text = ""
        ecgView.chartDescription?.textColor = colors.ecgDesc
        ecgView.chartDescription?.font = NSUIFont.preferredFont(forTextStyle: .headline)//NSUIFont.systemFont(ofSize: 16.0)
        ecgView.noDataFont = NSUIFont.preferredFont(forTextStyle: .headline)//NSUIFont.systemFont(ofSize: 16.0)
        ecgView.noDataText = "" //Offline message
        let ecgLegend = ecgView.legend
        ecgLegend.font = NSUIFont.preferredFont(forTextStyle: .footnote)
        ecgView.backgroundColor = colors.chartBackground
        //configure X and Y axes
        let ECGyaxisR = ecgView.getAxis(YAxis.AxisDependency.right)
        let ECGyaxisL = ecgView.getAxis(YAxis.AxisDependency.left)
        ECGyaxisR.axisMinimum = 100  //-150
        ECGyaxisR.drawLabelsEnabled = false
        ECGyaxisR.axisMaximum = 1800   //150
        ECGyaxisL.axisMinimum = 100  //-150
        ECGyaxisL.axisMaximum = 1800   //150
        ecgView.xAxis.drawLabelsEnabled = false
        
        /*--- Configure Heart Rate label ---*/
        ecgView.addSubview(HRlabel)
        HRlabel.translatesAutoresizingMaskIntoConstraints = false
        HRlabel.leftAnchor.constraint(equalTo: ecgView.leftAnchor, constant: 35).isActive = true
        HRlabel.bottomAnchor.constraint(equalTo: ecgView.bottomAnchor, constant: -20).isActive = true
        HRlabel.widthAnchor.constraint(equalTo: ecgView.widthAnchor, multiplier: 0.60).isActive = true
        HRlabel.heightAnchor.constraint(equalTo: ecgView.heightAnchor, multiplier: 0.2).isActive = true
        HRlabel.textColor = colors.hrLabel
        HRlabel.text = "HR: --"
        HRlabel.font = UIFont.boldSystemFont(ofSize: 32)
        
        /*--- Configure scroll view on lower part of canvas---**/
        view.addSubview(featuresView)
        featuresView.translatesAutoresizingMaskIntoConstraints = false
        featuresView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        featuresView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.95).isActive = true
        featuresView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.40).isActive = true
        featuresView.topAnchor.constraint(equalTo: ecgView.bottomAnchor, constant: 0).isActive = true
        featuresView.backgroundColor = colors.featuresBackground
        featuresView.bounces = false
        
        /*-- Configure sensor info view --*/
        featuresView.addSubview(sensorView)
        sensorView.translatesAutoresizingMaskIntoConstraints = false
        sensorView.leftAnchor.constraint(equalTo: featuresView.leftAnchor, constant: 0).isActive = true
        sensorView.topAnchor.constraint(equalTo: featuresView.topAnchor).isActive = true
        sensorView.widthAnchor.constraint(equalTo: featuresView.widthAnchor, multiplier: 1).isActive = true
        sensorView.heightAnchor.constraint(equalTo: featuresView.heightAnchor, multiplier: 1.0).isActive = true
        sensorView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: 0.0).isActive = true
        sensorView.backgroundColor = colors.contentBackground
        //Configure sensor title bar
        let sensorTitleView:UIView = UIView()
        sensorView.addSubview(sensorTitleView)
        sensorTitleView.translatesAutoresizingMaskIntoConstraints = false
        sensorTitleView.topAnchor.constraint(equalTo: sensorView.topAnchor, constant: 0).isActive = true
        sensorTitleView.leftAnchor.constraint(equalTo: sensorView.leftAnchor, constant: 0).isActive = true
        sensorTitleView.rightAnchor.constraint(equalTo: sensorView.rightAnchor, constant: 0).isActive = true
        sensorTitleView.heightAnchor.constraint(equalTo: sensorView.heightAnchor, multiplier: 0.2).isActive = true
        sensorTitleView.backgroundColor = colors.bar
        //Add sensor icon to sensor title bar
        let sensorImage:UIImage = UIImage(named: "sensor")!
        let sensorImageView:UIImageView = UIImageView(image: sensorImage)
        sensorTitleView.addSubview(sensorImageView)
        sensorImageView.translatesAutoresizingMaskIntoConstraints = false
        sensorImageView.leftAnchor.constraint(equalTo: sensorTitleView.leftAnchor, constant: 10).isActive = true
        sensorImageView.centerYAnchor.constraint(equalTo: sensorTitleView.centerYAnchor, constant: 0).isActive = true
        sensorImageView.widthAnchor.constraint(equalTo: sensorTitleView.heightAnchor, multiplier: 0.85).isActive = true
        sensorImageView.heightAnchor.constraint(equalTo: sensorTitleView.heightAnchor, multiplier: 0.85).isActive = true
        //Add sensor title
        let sensorTitle: UILabel = UILabel()
        sensorTitleView.addSubview(sensorTitle)
        sensorTitle.translatesAutoresizingMaskIntoConstraints = false
        sensorTitle.topAnchor.constraint(equalTo: sensorTitleView.topAnchor, constant: 10).isActive = true
        sensorTitle.leftAnchor.constraint(equalTo: sensorImageView.rightAnchor, constant: 10).isActive = true
        sensorTitle.rightAnchor.constraint(equalTo: sensorTitleView.rightAnchor, constant: -10).isActive = true
        sensorTitle.centerYAnchor.constraint(equalTo: sensorTitleView.centerYAnchor, constant: 0).isActive = true
        //Sensor tilte styling
        sensorTitle.text = "Sensor info"
        sensorTitle.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        sensorTitle.adjustsFontForContentSizeCategory = true
        //Configure sensor Text View that displays sensor info
        let skeys = ["Status", "BLE ECG characteristic", "UUID", "Properties", "Device name", "Battery level", "ADC Resolution", "Sampling rate", "Data Format"]
        let svalues = ["--", "  ", " -", " -", "--", "--", "--", "--", "--", "--"]
        sensorText.setup(keys:skeys, defaultVal:svalues)
        let sensorTextView = sensorText.txtView
        sensorView.addSubview(sensorTextView)
        sensorTextView.translatesAutoresizingMaskIntoConstraints = false
        sensorTextView.leftAnchor.constraint(equalTo: sensorView.leftAnchor, constant: 10).isActive = true
        sensorTextView.rightAnchor.constraint(equalTo: sensorView.rightAnchor, constant: -10).isActive = true
        sensorTextView.bottomAnchor.constraint(equalTo: sensorView.bottomAnchor, constant: 0).isActive = true
        sensorTextView.topAnchor.constraint(equalTo: sensorTitleView.bottomAnchor, constant: 0).isActive = true
        
        /*-- Configure statistics view --**/
        featuresView.addSubview(statsView)
        statsView.translatesAutoresizingMaskIntoConstraints = false
        statsView.topAnchor.constraint(equalTo: featuresView.topAnchor, constant: 0).isActive = true
        statsView.leftAnchor.constraint(equalTo: featuresView.leftAnchor, constant: viewWidth).isActive = true
        statsView.widthAnchor.constraint(equalTo: featuresView.widthAnchor, multiplier: 1).isActive = true
        //statsView.heightAnchor.constraint(equalTo: featuresView.heightAnchor, multiplier: 1.0).isActive = true
        statsView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor).isActive = true
        statsView.rightAnchor.constraint(equalTo: featuresView.rightAnchor, constant: 0).isActive = true
        statsView.backgroundColor = colors.contentBackground
        //Configure statistics title bar
        let statsTitleView:UIView = UIView()
        statsView.addSubview(statsTitleView)
        statsTitleView.translatesAutoresizingMaskIntoConstraints = false
        statsTitleView.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 0).isActive = true
        statsTitleView.leftAnchor.constraint(equalTo: statsView.leftAnchor, constant: 0).isActive = true
        statsTitleView.rightAnchor.constraint(equalTo: statsView.rightAnchor, constant: 0).isActive = true
        statsTitleView.heightAnchor.constraint(equalTo: statsView.heightAnchor, multiplier: 0.2).isActive = true
        statsTitleView.backgroundColor = colors.bar
        //Add statistics icon to stats title bar
        let statsImage:UIImage = UIImage(named: "stats")!
        let statsImageView:UIImageView = UIImageView(image: statsImage)
        statsTitleView.addSubview(statsImageView)
        statsImageView.translatesAutoresizingMaskIntoConstraints = false
        statsImageView.leftAnchor.constraint(equalTo: statsTitleView.leftAnchor, constant: 10).isActive = true
        statsImageView.centerYAnchor.constraint(equalTo: statsTitleView.centerYAnchor, constant: 0).isActive = true
        statsImageView.widthAnchor.constraint(equalTo: statsTitleView.heightAnchor, multiplier: 0.85).isActive = true
        statsImageView.heightAnchor.constraint(equalTo: statsTitleView.heightAnchor, multiplier: 0.85).isActive = true
        //Configure statistics view title
        let statsTitle: UILabel = UILabel()
        statsTitleView.addSubview(statsTitle)
        statsTitle.translatesAutoresizingMaskIntoConstraints = false
        statsTitle.topAnchor.constraint(equalTo: statsTitleView.topAnchor, constant: 10).isActive = true
        statsTitle.leftAnchor.constraint(equalTo: statsImageView.rightAnchor, constant: 10).isActive = true
        statsTitle.rightAnchor.constraint(equalTo: statsTitleView.rightAnchor, constant: -10).isActive = true
        statsTitle.centerYAnchor.constraint(equalTo: statsTitleView.centerYAnchor, constant: 0).isActive = true
        statsTitle.text = "ECG statistics"
        statsTitle.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        statsTitle.adjustsFontForContentSizeCategory = true
        /*Configure heart rate plot view*/
        statsView.addSubview(hrView)
        hrView.translatesAutoresizingMaskIntoConstraints = false
        hrView.topAnchor.constraint(equalTo: statsTitleView.bottomAnchor, constant: 10).isActive = true
        hrView.leftAnchor.constraint(equalTo: statsView.leftAnchor, constant: 10).isActive = true
        hrView.rightAnchor.constraint(equalTo: statsView.rightAnchor, constant: -10).isActive = true
        hrView.heightAnchor.constraint(equalTo: statsView.heightAnchor, multiplier: 0.4).isActive = true
        hrView.backgroundColor = colors.chartBackground
        hrView.xAxis.labelPosition = .bottom
        hrView.noDataText = ""
        let hrLegend = hrView.legend
        hrLegend.font = NSUIFont.preferredFont(forTextStyle: .footnote)
        //Setup statistics text field
        let stkeys = ["Av. R-R interval", "Max. Heart Rate", "Min. Heart Rate", "Total heartbeats detected"]
        let stvalues = ["--", "--", "--", "--"]
        statsText.setup(keys: stkeys, defaultVal: stvalues)
        let statsTextView = statsText.txtView
        statsView.addSubview(statsTextView)
        statsTextView.translatesAutoresizingMaskIntoConstraints = false
        statsTextView.leftAnchor.constraint(equalTo: statsView.leftAnchor, constant: 10).isActive = true
        statsTextView.rightAnchor.constraint(equalTo: statsView.rightAnchor, constant: -10).isActive = true
        statsTextView.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 0).isActive = true
        statsTextView.topAnchor.constraint(equalTo: hrView.bottomAnchor, constant: 0).isActive = true
        
        /*-- Configure custom view --*/
        /*
        featuresView.addSubview(customView)
        customView.translatesAutoresizingMaskIntoConstraints = false
        customView.leftAnchor.constraint(equalTo: featuresView.leftAnchor, constant: viewWidth*2).isActive = true
        customView.widthAnchor.constraint(equalTo: featuresView.widthAnchor, multiplier: 1.0).isActive = true
        //customView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        customView.heightAnchor.constraint(equalTo: featuresView.heightAnchor, multiplier: 1.0).isActive = true
        customView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor).isActive = true
        customView.rightAnchor.constraint(equalTo: featuresView.rightAnchor, constant: 0).isActive = true
        customView.backgroundColor = colors.contentBackground
        //Configure title bar
        let cvTitleView:UIView = UIView()
        customView.addSubview(cvTitleView)
        cvTitleView.translatesAutoresizingMaskIntoConstraints = false
        cvTitleView.topAnchor.constraint(equalTo: customView.topAnchor, constant: 0).isActive = true
        cvTitleView.leftAnchor.constraint(equalTo: customView.leftAnchor, constant: 0).isActive = true
        cvTitleView.rightAnchor.constraint(equalTo: customView.rightAnchor, constant: 0).isActive = true
        cvTitleView.heightAnchor.constraint(equalTo: customView.heightAnchor, multiplier: 0.2).isActive = true
        cvTitleView.backgroundColor = colors.bar
        //Custom image
        let cvImage:UIImage = UIImage(named: "vision")!
        let cvImageView:UIImageView = UIImageView(image: cvImage)
        cvTitleView.addSubview(cvImageView)
        cvImageView.translatesAutoresizingMaskIntoConstraints = false
        cvImageView.leftAnchor.constraint(equalTo: cvTitleView.leftAnchor, constant: 10).isActive = true
        cvImageView.centerYAnchor.constraint(equalTo: cvTitleView.centerYAnchor, constant: 0).isActive = true
        cvImageView.widthAnchor.constraint(equalTo: cvTitleView.heightAnchor, multiplier: 0.85).isActive = true
        cvImageView.heightAnchor.constraint(equalTo: cvTitleView.heightAnchor, multiplier: 0.85).isActive = true
        //customView label
        let cvTitle: UILabel = UILabel()
        cvTitleView.addSubview(cvTitle)
        cvTitle.translatesAutoresizingMaskIntoConstraints = false
        //cvTitle.topAnchor.constraint(equalTo: cvTitleView.topAnchor, constant: 10).isActive = true
        cvTitle.leftAnchor.constraint(equalTo: cvImageView.rightAnchor, constant: 10).isActive = true
        cvTitle.rightAnchor.constraint(equalTo: cvTitleView.rightAnchor, constant: -10).isActive = true
        cvTitle.centerYAnchor.constraint(equalTo: cvTitleView.centerYAnchor, constant: 0).isActive = true
        cvTitle.text = "Custom Plot View"
        cvTitle.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        cvTitle.adjustsFontForContentSizeCategory = true
        //customView subtitle label
        customView.addSubview(CVlabel)
        CVlabel.translatesAutoresizingMaskIntoConstraints = false
        CVlabel.topAnchor.constraint(equalTo: cvTitleView.bottomAnchor, constant: 5).isActive = true
        CVlabel.centerXAnchor.constraint(equalTo: customView.centerXAnchor, constant: 0).isActive = true
        CVlabel.heightAnchor.constraint(equalTo: customView.heightAnchor, multiplier: 0.15).isActive = true
        CVlabel.text = ""
        CVlabel.font = UIFont.preferredFont(forTextStyle: .title1)
        CVlabel.adjustsFontForContentSizeCategory = true
        //configure custom plot view
        customView.addSubview(customPlotView)
        customPlotView.translatesAutoresizingMaskIntoConstraints = false
        customPlotView.topAnchor.constraint(equalTo: CVlabel.bottomAnchor, constant: 0).isActive = true
        customPlotView.leftAnchor.constraint(equalTo: customView.leftAnchor, constant: 10).isActive = true
        customPlotView.rightAnchor.constraint(equalTo: customView.rightAnchor, constant: -10).isActive = true
        customPlotView.bottomAnchor.constraint(equalTo: customView.bottomAnchor, constant: -5).isActive = true
        customPlotView.backgroundColor = colors.chartBackground
        */
        
        let featuresView_multiplier = 0.4//1-ecgView_multiplier-0.20
        let effective_height = CGFloat(featuresView_multiplier)*viewHeight
        print("effective height: \(effective_height)")
        featuresView.contentSize = CGSize(width: viewWidth*CGFloat(pageNumber), height: effective_height)
        featuresView.isPagingEnabled = true
        
        
        //October 26, Setup connectButton
        view.addSubview(connectButton)
        connectButton.backgroundColor = .blue
        connectButton.setTitle("Connect", for: UIControl.State.normal)
        connectButton.addTarget(self, action: #selector(wearableConnect(sender:)), for: UIControl.Event.touchUpInside)
        
        //connectButton autolayout
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.leftAnchor.constraint(equalTo: featuresView.leftAnchor, constant: 0.0).isActive = true
        connectButton.topAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: 5.0).isActive = true
        connectButton.widthAnchor.constraint(equalTo: featuresView.widthAnchor, multiplier: 0.30).isActive = true
        connectButton.heightAnchor.constraint(equalTo: featuresView.heightAnchor, multiplier: 0.15).isActive = true
        
        //Page control
        view.addSubview(pageControl)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.centerXAnchor.constraint(equalTo: featuresView.centerXAnchor, constant: 0).isActive = true
        pageControl.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor, constant: 0).isActive = true
        //pageControl.topAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: 5.0).isActive = true
        pageControl.widthAnchor.constraint(equalTo: featuresView.widthAnchor, multiplier: 0.15).isActive = true
        pageControl.heightAnchor.constraint(equalTo: connectButton.heightAnchor, multiplier: 0.5).isActive = true
        pageControl.numberOfPages = pageNumber
        pageControl.backgroundColor = .clear
        pageControl.currentPageIndicatorTintColor = colors.pageIndicatorCheck
        pageControl.pageIndicatorTintColor = colors.pageIndicatorUncheck
        pageControl.isUserInteractionEnabled = false
        
        /*---After setting up all main views, settup and display launch view ---*/
        launchView.frame = view.frame
        launchView.frame = view.frame
        view.addSubview(launchView)
        launchView.translatesAutoresizingMaskIntoConstraints = false
        launchView.topAnchor.constraint(equalTo: ecgView.topAnchor).isActive = true
        launchView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor).isActive = true
        launchView.leftAnchor.constraint(equalTo: ecgView.leftAnchor).isActive = true
        launchView.rightAnchor.constraint(equalTo: ecgView.rightAnchor).isActive = true
        launchView.backgroundColor = colors.launch
        //Activity indicator
        launchView.addSubview(actInd)
        actInd.translatesAutoresizingMaskIntoConstraints = false
        actInd.centerYAnchor.constraint(equalTo: launchView.centerYAnchor, constant: -50).isActive = true
        actInd.centerXAnchor.constraint(equalTo: launchView.centerXAnchor).isActive = true
        actInd.color = .red
        //Activity text
        launchView.addSubview(actLabel)
        actLabel.translatesAutoresizingMaskIntoConstraints = false
        actLabel.centerXAnchor.constraint(equalTo: launchView.centerXAnchor).isActive = true
        actLabel.bottomAnchor.constraint(equalTo: actInd.topAnchor, constant: -5).isActive = true
        actLabel.widthAnchor.constraint(equalTo: launchView.widthAnchor, multiplier: 0.6).isActive = true
        actLabel.heightAnchor.constraint(equalTo: launchView.heightAnchor, multiplier: 0.2).isActive = true
        actLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        actLabel.textColor = .black
        actLabel.text = ""
        actLabel.textAlignment = .center
        actLabel.backgroundColor = .clear
        actInd.startAnimating()
        //view.bringSubviewToFront(launchView)
        
    }
    
    func plot(inArray:[Double], label:String){
        //CVlabel.text = label
        //updateChart(chart: customPlotView, data: inArray, type: "Custom")
    }
    
    //Disable landscape mode
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        //backgroundColor = UIColor(displayP3Red: 162/255, green: 195/255, blue: 195/255, alpha: 1)
        //view.backgroundColor = backgroundColor
        view.setGradientBackground(color0: colors.background0, color1: colors.background1)
        featuresView.delegate = self
        
        BTbuffer = Array(repeating: 0.0, count: BTbuffer_capacity)
        ECGQueue = Array(repeating: 0.0, count: 400)
        
        cnt = 0
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        //let ecgView_multiplier = 0.40
        viewWidth = view.frame.width*0.95
        viewHeight = view.frame.height
        pageNumber = 2
        
        HRlabel = UILabel()
        applyConstraints()
        //
        featuresView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        HRlabel.alpha = 0.0
    }
}

