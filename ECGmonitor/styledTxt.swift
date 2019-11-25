//
//  styledTxt.swift
//  ECGmonitor
//
//  Created by Gilson on 2019/11/22.
//  Copyright © 2019 Gilosn Frias . All rights reserved.
//  Custom class to handle styled text views

import Foundation
import UIKit

class styledText {
    let txtView:UITextView
    var items:[String]  //[NSMutableString]
    var styledItems:[String]
    var values:[String]
    var itemsFont = UIFont()//UIFont.italicSystemFont(ofSize: 52)
    var valuesFont = UIFont()//UIFont.systemFont(ofSize: 32)
    var itemsAttributes = [NSAttributedString.Key : Any]()
    var valuesAttributes = [NSAttributedString.Key: Any]()
        
    init() {
        txtView = UITextView()
        items = []
        values = []
        styledItems = [String]()
        txtView.isEditable = false
        txtView.isScrollEnabled = true
    }
    
    func setup(keys:[String], defaultVal:[String]){
        items = keys
        values = defaultVal
        for line in zip(items, values){
            if(line.1 == "--"){
                styledItems += ["•"+line.0+": "]
            }else if(line.1 == " -"){
                styledItems += ["   "+line.0+": "]
            }else{
                styledItems += ["•"+line.0]
            }
        }
        values = values.map{($0==" -") ? "--" : $0}
        itemsFont = UIFont.preferredFont(forTextStyle: .headline)
        valuesFont = UIFont.preferredFont(forTextStyle: .body)
        itemsAttributes = [.font:itemsFont]
        valuesAttributes = [.font:valuesFont]
        updateText(key: " ", value: " ")
    }
    
    //Rewrite the text fields taking into consideration new values for the items
    func updateText(key:String, value:String){
        let str = NSMutableAttributedString()
        let index = (items.firstIndex(of: key) ?? -1)
        if(index>=0 && index<values.count){
            values[index] = value
        }
        for line in zip(self.styledItems, self.values){
            let itemStr = NSMutableAttributedString(string: line.0, attributes: itemsAttributes)
            let valueStr = NSMutableAttributedString(string: line.1+"\n", attributes: valuesAttributes)
            itemStr.append(valueStr)
            str.append(itemStr)
        }
        txtView.textColor = UIColor.black
        txtView.backgroundColor = colors.contentBackground
        txtView.attributedText = str
        txtView.adjustsFontForContentSizeCategory = true
    }
}
