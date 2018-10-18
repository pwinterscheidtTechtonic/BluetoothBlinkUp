
//  AppDelegate.swift
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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: App Properties

    var window: UIWindow?
    var launchedShortcutItem: UIApplicationShortcutItem?


    // MARK: App Lifecycle Functions

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Override point for customization after application launch.
        // Set window's standard control tint colour
        self.window!.tintColor = UIColor.init(red: 0.03, green: 0.66, blue: 0.66, alpha: 1.0)
        let defaults: UserDefaults = UserDefaults.standard
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String, forKey: "com.bps.bleblinkup.app.version")
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String, forKey: "com.bps.bleblinkup.app.build")

        // If a shortcut was launched, display its information and take the appropriate action.
        var shouldPerformAdditionalDelegateHandling = true

        if let shortcut = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {

            self.launchedShortcutItem = shortcut

            // This will block "performActionForShortcutItem:completionHandler" from being called.
            shouldPerformAdditionalDelegateHandling = false
        }

        return shouldPerformAdditionalDelegateHandling
    }

    func applicationWillResignActive(_ application: UIApplication) {

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {

        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {

        // Notify view controllers that the app is bering reactivated
        let nc = NotificationCenter.default
        nc.post(name: NSNotification.Name.init("appwillenterforeground"), object: self, userInfo: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {

        // Check for a previous 3D touch
        guard let shortcut = self.launchedShortcutItem else { return }

        // Handle the saved shortcut...
        _ = handleShortcut(shortcut)

        // ...then clear it
        self.launchedShortcutItem = nil
    }

    func applicationWillTerminate(_ application: UIApplication) {

        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {

        // Called when the user 3D taps the app icon on the home screen while the app is backgrounded
        let handledShortcut = handleShortcut(shortcutItem)
        completionHandler(handledShortcut)
    }


    // MARK: 3D Touch Handler Function

    func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {

        var handled = false

        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        guard let shortCutType = shortcutItem.type as String? else { return false }
        guard let last = shortCutType.components(separatedBy: ".").last else { return false }

        switch last {
            case "startscan":
                // Handle Start Scan Quick Action: send a notification to the main view controller
                handled = true
                NotificationCenter.default.post(name: NSNotification.Name.init("com.bps.bluetoothblinkup.startscan"), object: self)
                break
            case "visitshop":
                // Handle Visit Store Quick Action: send a notification to the requisite view controller
                handled = true
                //NotificationCenter.default.post(name: NSNotification.Name.init("com.bps.bluetoothblinkup.visitshop"), object: self)
                // Open the EI shop in Safari
                let uiapp = UIApplication.shared
                let url: URL = URL.init(string: "https://store.electricimp.com/")!
                uiapp.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                break
            default:
                break
        }

        return handled
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
