//
//  WindowCommandHandler.swift
//  Outlander
//
//  Created by Joseph McBride on 5/19/15.
//  Copyright (c) 2015 Joe McBride. All rights reserved.
//

import Foundation

@objc
class WindowCommandHandler : CommandHandler {
    
    class func newInstance() -> WindowCommandHandler {
        return WindowCommandHandler()
    }
    
    let validCommands = ["add", "show", "hide", "list"]
    
    func canHandle(command: String) -> Bool {
        return command.lowercaseString.hasPrefix("#window")
    }
    
    func handle(command: String, withContext: GameContext) {
        
        let commands = command.substringFromIndex(advance(command.startIndex, 7)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        let groups = commands["(.*) (.*)"].groups()
        
        if groups.count > 2 && contains(validCommands, groups[1]) {
            let action = groups[1].lowercaseString
            let window = groups[2].lowercaseString
            
            withContext.events.publish("OL:window", data: ["action":action, "window":window])
        }
    }
}