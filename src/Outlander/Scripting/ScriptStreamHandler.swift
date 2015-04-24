//
//  ScriptStreamHandler.swift
//  Outlander
//
//  Created by Joseph McBride on 4/13/15.
//  Copyright (c) 2015 Joe McBride. All rights reserved.
//

import Foundation

@objc
public class ScriptStreamHandler : NodeHandler {
    
    class func newInstance() -> ScriptStreamHandler {
        return ScriptStreamHandler()
    }
    
    public func handle(nodes:[Node], text:String, context:GameContext) {
        var dict:[String:AnyObject] = [:]
        dict["nodes"] = nodes
        dict["text"] = text
        
        NSNotificationCenter
            .defaultCenter()
            .postNotificationName("ol:game-stream", object: nil, userInfo: dict)
    }
}