//
//  StormFrontTagStreamer.swift
//  Outlander
//
//  Created by Joseph McBride on 3/21/15.
//  Copyright (c) 2015 Joe McBride. All rights reserved.
//

import Foundation

@objc
public class StormFrontTagStreamer : NSObject {
    
    private var tags:[TextTag]
    private var lastNode:Node?
    
    private var mono = false
    private var bold = false
   
    private var lastStreamId = ""
    private var inStream = false
    
    private let ignoredEot = [
        "app",
        "clearstream",
        "compass",
        "compdef",
        "component",
        "dialogdata",
        "indicator",
        "left",
        "mode",
        "nav",
        "output",
        "popstream",
        "pushstream",
        "right",
        "streamwindow",
        "spell",
        "switchquickbar"
    ]
    
    private let roomTags = [
        "roomdesc",
        "roomobjs",
        "roomplayers",
        "roomexits"
    ]
    
    private let dirMap = [
        "n": "north",
        "s": "south",
        "e": "east",
        "w": "west",
        "ne": "northeast",
        "nw": "northwest",
        "se": "southeast",
        "sw": "southwest",
        "up": "up",
        "down": "down",
        "out": "out"
    ]
    
    public var isSetup = true
    public var emitSetting : ((String,String)->Void)?
    public var emitExp : ((SkillExp)->Void)?
    public var emitRoundtime : ((Roundtime)->Void)?
    public var emitRoom : (()->Void)?
    public var emitProcessNode : ((Node)->Void)?
    public var emitSpell : ((String)->Void)?
    public var emitVitals : ((Vitals)->Void)?
    
    class func newInstance() -> StormFrontTagStreamer {
        return StormFrontTagStreamer()
    }
    
    override init() {
        tags = []
    }
    
    public func stream(nodes:[Node]) -> [TextTag] {
        let tags:[TextTag] = nodes
            .map { (node) -> TextTag? in
                self.processNode(node)
                
                self.emitProcessNode?(node)
                
                return self.tagForNode(node)
            }
            .filter { $0 != nil }
            .map { $0! }
        
        return tags
        
//        var newTags = [TextTag]
//        
//        var tag = TextTag()
//        tag.text = ""
//        
//        for t in tags {
//            tag.text = tag.text + t.text
//            tag.color = t.color ?? tag.color
//            tag.backgroundColor = t.backgroundColor ?? tag.backgroundColor
//            tag.mono = tag.mono || t.mono
//            tag.bold = tag.bold || t.bold
//            tag.targetWindow = t.targetWindow ?? tag.targetWindow
//        }
//        
//        return [tag]
    }
    
    public func streamSingle(node:Node) -> Array<TextTag> {
        return stream([node])
    }
    
    public func processNode(node:Node) {
        if emitSetting == nil {
            return
        }
        
        switch node.name {
            
            
        case _ where node.name == "prompt":
            emitSetting?("prompt", node.value?.replace("&gt;", withString: ">") ?? "")
            emitSetting?("gametime", node.attr("time") ?? "")
            
            let today = NSDate().timeIntervalSince1970
            emitSetting?("gametimeupdate", "\(today)")
            
        case _ where node.name == "roundtime":
            let roundtime = Roundtime()
            roundtime.time = NSDate(timeIntervalSince1970: NSTimeInterval(Int(node.attr("value")!)!))
            emitRoundtime?(roundtime)
            
        case _ where node.name == "component":
            var compId = node.attr("id")?.replace(" ", withString: "_") ?? ""
            
            if !compId.hasPrefix("exp") {
                compId = compId.replace("_", withString: "")
                
                var value = node.value ?? ""
                
                if compId == "roomexits" {
                    if node.children.count > 0 {
                        value = nodeChildValues(node)
                    }
                }
                
                if compId == "roomobjs" {
                    var origValues = value
                    var monsters = ""
                    var monsterCount = 0
                    if node.children.count > 0 {
                        value = nodeChildValues(node)
                        let bolds = nodeChildValuesWithBold(node)
                        origValues = bolds.0
                        monsters = bolds.1
                        monsterCount = bolds.2
                    }
                    
                    emitSetting?("roomobjsorig", origValues)
                    emitSetting?("monsterlist", monsters)
                    emitSetting?("monstercount", "\(monsterCount)")
                }
                
                emitSetting?(compId, value)
                
                if roomTags.contains(compId) {
                    emitRoom?()
                }
                
            } else if !compId.hasPrefix("exp_tdp") {
                var val = ""
                var isNew = false
                var isBrief = false
                
                if(node.children.count > 0
                    && node.children[0].name == "preset"
                    && node.children[0].attr("id") == "whisper") {
                    isNew = true
                }
                
                if node.children.count > 0 && (node.children.count == 2 || node.children[0].children.count > 1) {
                    isBrief = true
                }
               
                if isBrief {
                    
                    if isNew {
                        val = nodeChildValues(node.children[0])
                    } else {
                        val = nodeChildValues(node)
                    }
                    
                    parseExpBrief(compId, data: val, isNew: isNew)
                } else {
                    
                    if isNew {
                        val = node.children[0].value ?? ""
                    } else {
                        val = node.value ?? ""
                    }
                    
                    parseExp(compId, data: val, isNew: isNew)
                }
            }
            
        case _ where node.name == "left" || node.name == "right":
            emitSetting?("\(node.name)hand", node.value ?? "Empty")
            emitSetting?("\(node.name)handnoun", node.attr("noun") ?? "")
            
        case _ where node.name == "spell":
            if let spell = node.value {
                emitSetting?("preparedspell", spell)
                emitSpell?(spell)
            }
            
        case _ where node.name == "indicator":
            let id = node.attr("id")?.substringFromIndex(4).lowercaseString ?? ""
            let visible = node.attr("visible") == "y" ? "1" : "0"
            
            if id.characters.count == 0 {
                return
            }
            
            emitSetting?(id, visible)
            
        case _ where node.name == "compass":
            let dirs = node.children
                .filter { $0.name == "dir" && $0.hasAttr("value") }
            
            var found:[String] = []
            
            for dir in dirs {
                let mapped = self.dirMap[dir.attr("value")!]!
                found.append(mapped)
                emitSetting?(mapped, "1")
            }
            
            let notFound = dirMap.values.filter { !found.contains($0) }
            
            for dir in notFound {
                emitSetting?(dir, "0")
            }
            
        case _ where node.name == "streamwindow":
            let id = node.attr("id")
            var subtitle = node.attr("subtitle")
            if id == "main" && subtitle != nil && subtitle!.characters.count > 3 {
                subtitle = subtitle!.substringFromIndex(subtitle!.startIndex.advancedBy(3))
                if let t = subtitle {
                    emitSetting?("roomtitle", t)
                }
            }
            
        case _ where node.name == "dialogdata" && node.attr("id") == "minivitals":
            let vitals = node.children
                            .filter {$0.name == "progressbar" && $0.hasAttr("id")}
            
            for vital in vitals {
                let name = vital.attr("id")!
                let value = vital.attr("value") ?? "0"
                emitSetting?(name, value)
               
                let send = Vitals(with: name, value: UInt16(Int(value)!))
                emitVitals?(send)
            }
            
        case _ where node.name == "app":
            emitSetting?("charactername", node.attr("char") ?? "")
            emitSetting?("game", node.attr("game") ?? "")
            
        default:
            // do nothing
            return
        }
    }
    
    public func tagForNode(node:Node) -> TextTag? {
        var tag:TextTag? = nil
        
        if !isSetup {
            isSetup = node.name == "endsetup"
            return nil
        }
        
        switch node.name {
            
        case _ where node.name == "app":
            isSetup = false
            
        case _ where node.name == "text":
            if inStream && (lastStreamId == "inv" || lastStreamId == "talk" || lastStreamId == "whispers" || lastStreamId == "ooc" || lastStreamId == "percWindow") {
                break
            }
            
            tag = emitTag(node)
            tag?.targetWindow = self.streamIdToWindow(lastStreamId)
            if inStream {
                tag?.text = "\(tag!.text!)\n"
                if lastStreamId == "logons" || lastStreamId == "death" {
                    tag?.text = tag?.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                }
            }
           
            if lastNode?.name == "preset" && tag!.text.characters.count > 0 && tag!.text!.hasPrefix("  You also see") {
                let text = tag!.text!.trimPrefix("  ")
                tag?.text = "\n\(text)"
                tag?.preset = lastNode?.attr("id")
            }
            
            // room name
            if lastNode?.name == "style" && lastNode?.attr("id") == "roomName" {
                tag?.color = "#0000FF"
            }
            
        case _ where node.name == "eot":
            if inStream || lastNode != nil && (ignoredEot.contains(lastNode!.name) || lastNode!.name == "prompt") {
                break
            }
            tag = TextTag()
            tag?.text = "\r\n"
            
        case _ where node.name == "prompt":
            if lastNode != nil && lastNode!.name == "popstream" {
                break
            }
            tag = emitTag(node)
            tag?.text = tag!.text! + "\r\n"
            
        case _ where node.name == "preset":
            if inStream && (lastStreamId == "talk" || lastStreamId == "whispers" || lastStreamId == "ooc") {
                break
            }
            tag = emitTag(node)
            tag?.targetWindow = self.streamIdToWindow(lastStreamId)
            let id = node.attr("id")
            tag?.preset = id
            if id == "speech" || id == "whisper" || id == "thought" {
                tag?.color = "#99FFFF"
            }
            
        case _ where node.name == "pushbold":
            self.bold = true
            
        case _ where node.name == "popbold":
            self.bold = false
            
        case _ where node.name == "pushstream":
            inStream = true
            if let id = node.attr("id") {
                lastStreamId = id
            }
            
        case _ where node.name == "popstream":
            inStream = false
            lastStreamId = ""
            
        case _ where node.name == "output":
            if let style = node.attr("class") {
                if style == "mono" {
                    self.mono = true
                } else {
                    self.mono = false
                }
            }
            
        case _ where node.name == "a":
            tag = emitTag(node)
            tag?.href = node.attr("href")
            
        case _ where node.name == "b":
            // <b>You yell,</b> Hogs!
            if inStream && lastStreamId == "talk" {
                break
            }
            tag = emitTag(node)
            
        case _ where node.name == "d":
            
            if node.children.count > 0 {
                
                if node.children[0].name == "b" {
                    tag = emitTag(node.children[0])
                }
                
            } else {
                tag = emitTag(node)
            }
            
            if let cmd = node.attr("cmd") {
                tag?.command = cmd
            }
            
        case _ where node.name == "dynastream":
            if node.children.count > 0 {
                tag = emitTag(node)
                tag?.text = self.nodeChildValues(node)
            } else {
                tag = emitTag(node)
            }
            
        default:
           tag = nil
        }
       
        self.lastNode = node
        return tag
    }
    
    public func streamIdToWindow(streamId:String) -> String {
        switch(streamId) {
        case _ where streamId == "logons":
            return "arrivals"
        case _ where streamId == "thoughts" || streamId == "chatter":
            return "thoughts"
        case _ where streamId == "death":
            return "deaths"
        case _ where streamId == "whispers":
            return "whispers"
        case _ where streamId == "ooc":
            return "ooc"
        default:
            return streamId.lowercaseString
        }
    }
    
    public func nodeChildValuesRecursive(node:Node) -> String {
        
        var result = ""
       
        for child in node.children {
            if child.name == "text" || child.name == "d" {
                result += child.value ?? ""
            }
            
            result += nodeChildValuesRecursive(child)
        }
        
        return result
    }
    
    public func nodeChildValues(node:Node) -> String {
        
        var result = ""
       
        for child in node.children {
            if child.name == "text" || child.name == "d" {
                result += child.value ?? ""
            }
        }
        
        return result
    }

    public func nodeChildValuesWithBold(node:Node) -> (String, String, Int) {
        
        var result = ""
        var monsters = ""
        var monsterCount = 0
        var lastNode:Node?
       
        for child in node.children {
            if child.name == "text" || child.name == "d" {
                result += child.value ?? ""
            }
            
            if child.name == "pushbold" {
                result += "<pushbold/>"
            }
            
            if child.name == "popbold" {
                monsterCount++
                if monsters.characters.count > 0 {
                    monsters += "|"
                }
                monsters += lastNode?.value ?? ""
                result += "<popbold/>"
            }
            
            lastNode = child
        }
        
        return (result, monsters, monsterCount)
    }
    
    public func parseExpBrief(compId:String, data:String, isNew:Bool) {
        let expName = compId.substringFromIndex(compId.startIndex.advancedBy(4))
        
        if data.characters.count == 0 {
            
            let rate = LearningRate.fromRate(0)
            let skill = SkillExp()
            skill.name = expName
            skill.ranks = NSDecimalNumber(double: 0.0)
            skill.mindState = rate
            skill.isNew = isNew
            
            emitSetting?("\(expName).LearningRate", "\(rate.rateId)")
            emitSetting?("\(expName).LearningRateName", "\(rate.desc)")
            
            emitExp?(skill)
            return
        }
        
        let pattern = ".+:\\s+(\\d+)\\s(\\d+)%\\s+\\[\\s?(\\d+)?.*";
        
        let trimmed = data.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
      
        let ranks = RegexMutable(trimmed)
        ranks[pattern] ~= "$1.$2"
        
        let mindstate = RegexMutable(trimmed)
        mindstate[pattern] ~= "$3"
        
        let mindstateNumber = NSDecimalNumber(string: mindstate as String)
        
        let rate = LearningRate.fromRate(mindstateNumber.unsignedShortValue)
        
        let skill = SkillExp()
        skill.name = expName
        skill.ranks = NSDecimalNumber(string:ranks as String)
        skill.mindState = rate
        skill.isNew = isNew
        
        emitSetting?("\(expName).Ranks", ranks as String)
        emitSetting?("\(expName).LearningRate", "\(rate.rateId)")
        emitSetting?("\(expName).LearningRateName", "\(rate.desc)")
        
        emitExp?(skill)
    }
    
    public func parseExp(compId:String, data:String, isNew:Bool) {
        
        let expName = compId.substringFromIndex(compId.startIndex.advancedBy(4))
        
        if data.characters.count == 0 {
            
            let rate = LearningRate.fromRate(0)
            let skill = SkillExp()
            skill.name = expName
            skill.ranks = NSDecimalNumber(double: 0.0)
            skill.mindState = rate
            skill.isNew = isNew
            
            emitSetting?("\(expName).LearningRate", "\(rate.rateId)")
            emitSetting?("\(expName).LearningRateName", "\(rate.desc)")
            
            emitExp?(skill)
            return
        }
        
        let pattern = ".+:\\s+(\\d+)\\s(\\d+)%\\s(\\w.*)?.*";
        
        let trimmed = data.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
      
        let ranks = RegexMutable(trimmed)
        ranks[pattern] ~= "$1.$2"
        
        let mindstate = RegexMutable(trimmed)
        mindstate[pattern] ~= "$3"
        
        var rate = LearningRate.fromDescription(mindstate as String)
        
        if(rate == nil) {
            rate = LearningRate.fromRate(0)
        }
        
        let skill = SkillExp()
        skill.name = expName
        skill.ranks = NSDecimalNumber(string:ranks as String)
        skill.mindState = rate
        skill.isNew = isNew
        
        emitSetting?("\(expName).Ranks", ranks as String)
        emitSetting?("\(expName).LearningRate", "\(rate.rateId)")
        emitSetting?("\(expName).LearningRateName", "\(rate.desc)")
        
        emitExp?(skill)
    }
    
    func emitTag(node:Node) -> TextTag? {
        let tag:TextTag? = TextTag()
        var text = node.value?.replace("&gt;", withString: ">")
        text = text?.replace("&lt;", withString: "<")
        tag?.text = text
        tag?.bold = self.bold
        tag?.mono = self.mono
        return tag
    }
}