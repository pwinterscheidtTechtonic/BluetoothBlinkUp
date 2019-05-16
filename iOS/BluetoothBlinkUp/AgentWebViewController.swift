//
//  AgentWebViewController.swift
//  BluetoothBlinkUp
//
//  Created by Tony Smith on 12/14/17.
//
//  MIT License
//
//  Copyright 2017-19 Electric Imp
//
//  Version 1.1.2
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

class AgentWebViewController: UIViewController, WKNavigationDelegate {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var loadProgress: UIActivityIndicatorView!

    var agentURL: String = ""
    var loadInitialPage: Bool = true


    // MARK: - View Lifecycle Functions

    override func viewDidLoad() {

        super.viewDidLoad()

        // Initialize the UI
        self.webView.navigationDelegate = self
        self.loadProgress.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)

        // Get the 'loading...' page from the app's bundle and load it into the web view
        let page = getPage("back")
        if page.count > 0 {
            self.webView.loadHTMLString(page, baseURL: Bundle.main.bundleURL)
        }
    }

    // MARK: - WKWebView Delegate Functions

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        if self.loadInitialPage {
            // We have just loaded the initial page, so make sure we don't load it again...
            self.loadInitialPage = false

            // ...and load in the agent URL or the default display page
            if self.agentURL.count > 0 {
                // We have a non-zero agent URL string, so pass it to the web view to load
                if let url = URL.init(string: agentURL) {
                    let request: URLRequest = URLRequest.init(url: url)
                    self.loadProgress.startAnimating()
                    self.webView.load(request)
                }
            } else {
                // We've been given no agent URL, so load the default display page instead
                let page = getPage("default")
                if page.count > 0 {
                    self.webView.loadHTMLString(page, baseURL: Bundle.main.bundleURL)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        // Check the server response received by the web view and decide whether to proceed.
        // If the agent is not serving a UI, or there is no agent, we will receive a 404, so
        // we use this to present a boilerplate message page

        // Get the response status code
        let response: HTTPURLResponse = navigationResponse.response as! HTTPURLResponse
        let statusCode = response.statusCode

        // Turn off the progress indicator
        self.loadProgress.stopAnimating()

        // Proceed according to the status code
        if statusCode < 400 {
            // Page is good - allow the transaction to continue
            decisionHandler(WKNavigationResponsePolicy.allow)
        } else {
            // Error - cancel the transaction...
            decisionHandler(WKNavigationResponsePolicy.cancel)

            // ... and present the default page instead
            let page = getPage("default")
            if page.count > 0 {
                self.webView.loadHTMLString(page, baseURL: Bundle.main.bundleURL)
            }
        }
    }


    // MARK: - App Navigation Functions

    @objc func goBack() {

        // Jump back to the previous screen
        self.loadInitialPage = true
        self.navigationController!.popViewController(animated: true)
    }


    // MARK: - Misc Functions

    func getPage(_ name: String) -> String {

        // Load in the named web page as a string from the app bundle and return it
        // If the load fails, just return an empty string (calling functions should check this)
        if let docPath = Bundle.main.path(forResource: name, ofType: "html") {
            if let data = FileManager.default.contents(atPath: docPath) {
                if let dataString = String.init(data: data, encoding: String.Encoding.utf8) {
                    return dataString
                }
            }
        }

        // Couldn't load the page, so return an empty string
        return ""
    }
    
}
