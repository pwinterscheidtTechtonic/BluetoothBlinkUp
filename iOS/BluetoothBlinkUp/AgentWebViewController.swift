//
//  AgentWebViewController.swift
//  BluetoothBlinkUp
//
//  Created by Tony Smith on 12/14/17.
//
//  MIT License
//
//  Copyright 2017-18 Electric Imp
//
//  SPDX-License-Identifier: MIT
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
//  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.



import UIKit
import WebKit

class AgentWebViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    
    var agentURL: String = ""
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        if agentURL.count > 0 {
            if let url = URL.init(string: agentURL) {
                let request: URLRequest = URLRequest.init(url: url)
                webView.load(request)
            }
        } else {
            // We've been given no agent URL, so load up and display
            // a premade HTML-based message
            if let docPath = Bundle.main.path(forResource: "default", ofType: "html") {
                if let data = FileManager.default.contents(atPath: docPath) {
                    if let dataString = String.init(data: data, encoding: String.Encoding.utf8) {
                        webView.loadHTMLString(dataString, baseURL: nil)
                    }
                }
            }
            
            
        }
    }
    
}
