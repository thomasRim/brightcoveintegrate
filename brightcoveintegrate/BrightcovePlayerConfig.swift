//
//  BrightcovePlayerConfig.swift
//  Bc_PTV-Sample
//
//  Created by Volodymyr Yevdokymov on 3/20/18.
//  Copyright © 2018 PrometheanTV. All rights reserved.
//

import ObjectMapper

struct BrightcovePlayerConfig: Mappable {
    var policyKey: String = ""
    var imaUseMediaCuePoints: Bool = false
    var imaServerUrl: String?
    
    init?(map: Map) {}
    
    mutating func mapping(map: Map) {
        self.policyKey <- map["video_cloud.policy_key"]
        var plugins = [BrightcovePlugin]()
        plugins <- map["plugins"]
        plugins.forEach { (plugin) in
            if plugin.name == "ima3" {
                self.imaUseMediaCuePoints = ((plugin.options["useMediaCuePoints"] as? Int) ?? 0) == 1
                self.imaServerUrl = plugin.options["serverUrl"] as? String
            }
        }
    }
}

struct BrightcovePlugin: Mappable {
    var name: String = ""
    var options :[String:Any] = [:]
    
    init?(map: Map) {}

    mutating func mapping(map: Map) {
        self.name <- map["name"]
        self.options <- map["options"]
    }
}

