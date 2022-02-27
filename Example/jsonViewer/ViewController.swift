//
//  ViewController.swift
//  jsonViewer
//
//  Created by songxing10000 on 02/22/2022.
//  Copyright (c) 2022 songxing10000. All rights reserved.
//

import Cocoa
import Foundation
import jsonViewer
class ViewController: NSViewController {
    
    @IBOutlet var m_textView: NSTextView!
    @IBAction func clickBtn(_ sender: NSButtonCell) {
        let str = m_textView.string
        if !str.isEmpty {
            presentAsModalWindow(JSONVC.vc(urlStr: str))
        }
    }
}

