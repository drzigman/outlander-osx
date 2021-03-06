//
//  ClassesLoader.swift
//  Outlander
//
//  Created by Joseph McBride on 3/14/17.
//  Copyright © 2017 Joe McBride. All rights reserved.
//

import Foundation

@objc
class ClassesLoader : NSObject {

    class func newInstance(context:GameContext, fileSystem:FileSystem) -> ClassesLoader {
        return ClassesLoader(context: context, fileSystem: fileSystem)
    }

    var context:GameContext
    var fileSystem:FileSystem

    init(context:GameContext, fileSystem:FileSystem) {
        self.context = context
        self.fileSystem = fileSystem
    }

    func load() {
        let configFile = self.context.pathProvider.profileFolder().stringByAppendingPathComponent("classes.cfg")

        var data:String?

        do {
            data = try self.fileSystem.stringWithContentsOfFile(configFile, encoding: NSUTF8StringEncoding)
        } catch {
            return
        }

        if data == nil {
            return
        }

        self.context.classSettings.clear()

        let pattern = "^#class \\{(.*?)\\} \\{(.*?)\\}$"

        let target = SwiftRegex(target: data!, pattern: pattern, options: [NSRegularExpressionOptions.AnchorsMatchLines, NSRegularExpressionOptions.CaseInsensitive])

        let groups = target.allGroups()

        for group in groups {
            if group.count == 3 {
                let key = group[1]
                let val = group[2].toBool()

                self.context.classSettings.set(key, value: val ?? false)
            }
        }
    }

    func save() {
        let configFile = self.context.pathProvider.profileFolder().stringByAppendingPathComponent("classes.cfg")

        var classes = ""

        for c in self.context.classSettings.all() {
            let val = c.value ? "on" : "off"
            classes += "#class {\(c.key)} {\(val)}"
            classes += "\n"
        }

        self.fileSystem.write(classes, toFile: configFile)
    }
}
