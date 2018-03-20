//
//  BrightcovePlayerConfig.swift
//  Bc_PTV-Sample
//
//  Created by Volodymyr Yevdokymov on 3/20/18.
//  Copyright © 2018 PrometheanTV. All rights reserved.
//

import ObjectMapper

class BrightcovePlayerConfig:NSObject, Mappable {
    var policyKey: String = ""
    var imaUseMediaCuePoints: Bool = false
    var imaServerUrl: String?
    
    required init?(map: Map) {}
    
    func mapping(map: Map) {
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

    class func configForPlayer(fromAccount id:String, named:String) -> BrightcovePlayerConfig? {
        let policyKeyUrl = "https://players.brightcove.net/\(id)/\(named)_default/config.json"
        if let url = URL(string: policyKeyUrl), let data = try? Data(contentsOf: url) {
            if let object = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String : Any] {
                let config = BrightcovePlayerConfig(JSON: object)
                return config
            }
        }
        return nil
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

