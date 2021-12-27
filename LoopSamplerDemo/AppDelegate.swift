//
//  AppDelegate.swift
//  LoopSamplerDemo
//
//  Created by Joshua Teitelbaum on 12/26/21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func loadSamples() {
        _ = LoopSampler.shared.ignite()
        // Do any additional setup after loading the view.
        if let allUrls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            allUrls.forEach({ url in
                do {
                   print("URL \(url)")
                    _  = LoopSampler.shared.registerSample(sampleURL: url)
                }
            })
        }
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        loadSamples()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

