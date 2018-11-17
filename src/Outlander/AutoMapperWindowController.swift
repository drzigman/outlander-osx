//
//  AutoMapperWindowController.swift
//  Outlander
//
//  Created by Joseph McBride on 4/2/15.
//  Copyright (c) 2015 Joe McBride. All rights reserved.
//

import Cocoa

func loadMap <R> (
    backgroundClosure: () -> R,
    mainClosure: (R) -> ())
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
        let res = backgroundClosure()
        dispatch_async(dispatch_get_main_queue(), {
            mainClosure(res)
        })
    }
}

func mainThread(mainClosure: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), {
        mainClosure()
    })
}

class MapsDataSource : NSObject, NSComboBoxDataSource {
    
    private var maps:[MapInfo] = []
    
    func loadMaps(mapsFolder:String, mapLoader:MapLoader, loaded: (()->Void)?) {
        
        { () -> [MapMetaResult] in
            
            return mapLoader.loadFolder(mapsFolder)
            
        } ~> { (results) ->() in
            
            var success:[MapInfo] = []
            
            for res in results {
                switch res {
                    
                case let .Success(mapInfo):
                    success.append(mapInfo)
                    
                case let .Error(error):
                    print("\(error)")
                }
            }
            
            self.maps = success.sort { $0.id.compare($1.id, options: NSStringCompareOptions.NumericSearch, range: $0.id.startIndex..<$0.id.endIndex, locale:nil) == NSComparisonResult.OrderedAscending }
            
            loaded?()
        }
    }
    
    func mapForZoneId(id:String) -> MapInfo? {
        return self.maps.filter { $0.id == id }.first
    }
    
    func mapForFile(file:String) -> MapInfo? {
        return self.maps.filter { $0.file == file }.first
    }
    
    func mapAtIndex(index:Int) -> MapInfo {
        return self.maps[index];
    }
    
    func indexOfMap(id:String) -> Int? {
        
        if let info = mapForZoneId(id) {
            return self.maps.indexOf(info)
        }
        
        return nil
    }

    func initializeMaps(context:GameContext, loader: MapLoader) {
        guard let mapsFolder = context.pathProvider.mapsFolder() else { return }

        let start = NSDate()

        let maps = self.maps.filter { $0.zone == nil }

        context.events.echoText("[Automapper]: loading all maps...", preset: "automapper")

        loadMap({ () -> [MapLoadResult] in
            var results: [MapLoadResult] = []
            maps.forEach { m in
                let result = loader.load(mapsFolder.stringByAppendingPathComponent(m.file))
                switch result {

                case let .Success(zone):
                    zone.file = m.file
                    m.zone = zone

                case let .Error(error):
                    print(error)
                }
                results.append(result)
            }
            return results
            }, mainClosure: { result -> () in
                let diff = NSDate().timeIntervalSinceDate(start)
                self.maps.forEach { map in
                    context.maps[map.id] = map.zone!
                }
                context.events.echoText("[Automapper]: all \(self.maps.count) maps loaded in \(diff.format("0.2")) seconds", preset: "automapper")
                context.resetMap()
        })
    }
    
    // MARK - NSComboBoxDataSource
    
    func numberOfItemsInComboBox(aComboBox: NSComboBox) -> Int {
        return self.maps.count
    }
    
    func comboBox(aComboBox: NSComboBox, objectValueForItemAtIndex index: Int) -> AnyObject? {
        guard index > -1 else { return "" }

        let map = self.maps[index]
        return "\(map.id). \(map.name)"
    }
}

class AutoMapperWindowController: NSWindowController, NSComboBoxDataSource, ISubscriber {
    
    @IBOutlet weak var mapsComboBox: NSComboBox!
    @IBOutlet weak var nodesLabel: NSTextField!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var mapView: MapView!
    @IBOutlet weak var mapLevelLabel: NSTextField!
    @IBOutlet weak var nodeNameLabel: NSTextField!
    
    private var mapsDataSource: MapsDataSource = MapsDataSource()

    private var context:GameContext?
    private let mapLoader:MapLoader = MapLoader()
    
    var mapLevel:Int = 0 {
        didSet {
            self.mapView.mapLevel = self.mapLevel
            self.mapLevelLabel.stringValue = "Level: \(self.mapLevel)"
        }
    }
    
    var mapZoom:CGFloat = 1.0 {
        didSet {
            if self.mapZoom == 0 {
                self.mapZoom = 0.5
            }
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        self.nodeNameLabel.stringValue = ""
        
        self.mapsComboBox.dataSource = self.mapsDataSource
        self.mapView.nodeHover = { node in
            if let room = node {
                var notes = ""
                if room.notes != nil {
                    notes = "(\(room.notes!))"
                }
                self.nodeNameLabel.stringValue = "#\(room.id) - \(room.name) \(notes)"
            } else {
                self.nodeNameLabel.stringValue = ""
            }
        }
    }
    
    func setSelectedZone() {
        if let zone = self.context?.mapZone {
            
            if let idx = self.mapsDataSource.indexOfMap(zone.id) {
                
                self.mapsComboBox.selectItemAtIndex(idx)
                
                self.renderMap(zone)
            }
        }

        if let charname = self.context?.globalVars["charactername"], let game = self.context?.globalVars["game"] {
            self.window?.title = "AutoMapper - \(game): \(charname)"
        }
    }

    internal func handle(token:String, data:[String:AnyObject]) {
        guard token == "variable:changed" else { return }
        guard let changed = data as? [String:String] else { return }

        let key = changed.keys.first ?? ""
        if key == "zoneid" {
            if let zoneId = changed["zoneid"], let mapInfo = self.mapsDataSource.mapForZoneId(zoneId) {
                self.setZoneFromMap(mapInfo)
            }
        }

        if key == "roomid" {
            if let id = changed["roomid"], let room = self.context!.mapZone?.roomWithId(id) {

                if room.notes != nil && room.notes!.rangeOfString(".xml") != nil {
                    
                    let groups = room.notes!["(.+\\.xml)"].groups()
                    
                    if groups.count > 1 {
                        let mapfile = groups[1]
                        
                        if let mapInfo = self.mapsDataSource.mapForFile(mapfile) {
                            self.setZoneFromMap(mapInfo)
                        }
                    }
                } else {
                    mainThread {
                        if self.mapView != nil {
                            self.mapView.mapLevel = room.position.z
                            self.mapView.currentRoomId = id
                        }
                    }
                }
            }
        }
    }

    func setContext(context:GameContext) {
        self.context = context
        self.context?.events.subscribe(self, token: "variable:changed")
    }
    
    func setZoneFromMap(mapInfo:MapInfo) {
        if let idx = self.mapsDataSource.indexOfMap(mapInfo.id) {
            
            mainThread {
                
                if self.mapsComboBox != nil && self.mapsComboBox.indexOfSelectedItem != idx {
                    self.mapsComboBox.selectItemAtIndex(idx)
                }
                else {
                    
                    if mapInfo.zone != nil {
                        
                        self.renderMap(mapInfo.zone!)
                        self.context?.mapZone = mapInfo.zone!
                        
                    } else {
                        self.loadMapFromInfo(mapInfo)
                    }
                }
            }
        }
    }
    
    func findCurrentRoom(zone:MapZone) -> MapNode? {
        if let ctx = self.context {

            let roomId = ctx.globalVars["roomid"] ?? ""
            return zone.roomWithId(roomId)
        }

        return nil
    }
    
    func loadMaps() {
        if let mapsFolder = self.context?.pathProvider.mapsFolder() {
            
            if self.nodesLabel != nil {
                self.nodesLabel.stringValue = "Loading Maps ..."
            }
            
            self.mapsDataSource.loadMaps(mapsFolder, mapLoader: self.mapLoader, loaded: { ()->Void in
                if self.nodesLabel != nil {
                    self.nodesLabel.stringValue = ""
                }
                
                if let zoneId = self.context!.globalVars["zoneid"] {
                    
                    if let idx = self.mapsDataSource.indexOfMap(zoneId) {
                        if self.mapsComboBox != nil {
                            self.mapsComboBox.selectItemAtIndex(idx)
                        } else {
                            self.loadMapFromInfo(self.mapsDataSource.mapAtIndex(idx))
                        }
                    }
                }

                self.mapsDataSource.initializeMaps(self.context!, loader: self.mapLoader)
            })
        }
    }

    func renderMap(zone:MapZone) {
        
        if self.mapView == nil {
            return
        }

        let room = self.findCurrentRoom(zone)
        let rect = zone.mapSize(0, padding: 100.0)
        
        self.mapLevel = room?.position.z ?? 0
        
        self.mapView?.setFrameSize(rect.size)
        self.mapView?.currentRoomId = room != nil ? room!.id : ""
        self.mapView?.setZone(zone, rect: rect)
        
        let roomCount = zone.rooms.count
        
        self.nodesLabel.stringValue = "Map \(zone.id). \(zone.name), Rooms: \(roomCount)"
        
        if let rect = self.mapView?.rectForRoom(self.mapView?.currentRoomId) {
            self.scrollView.scrollRectToVisible(rect)
        }
    }
    
    func loadMapFromInfo(info:MapInfo) {

        if let loaded = info.zone {
            self.context?.mapZone = loaded

            info.zone = loaded
            
            if self.mapView != nil {
                
                self.renderMap(loaded)
            }
            return
        }
        
        if let mapsFolder = context?.pathProvider.mapsFolder() {
            
            let file = mapsFolder.stringByAppendingPathComponent(info.file)
           
            if self.nodesLabel != nil {
                self.nodesLabel.stringValue = "Loading ..."
            }

            self.context?.events.echoText("[Automapper]: loading selected map \(info.file)", preset: "automapper")
            
            let start = NSDate()

            loadMap({ () -> MapLoadResult in
                return self.mapLoader.load(file)
            }, mainClosure: { (result) -> () in
                
                let diff = NSDate().timeIntervalSinceDate(start)
                
                switch result {
                    
                case let .Success(zone):

                    self.context?.events.echoText("[Automapper]: \(zone.name) loaded in \(diff.format(".2")) seconds", preset: "automapper")
                    
                    self.context?.mapZone = zone
                    
                    info.zone = zone
                    
                    if self.mapView != nil {
                        
                        self.renderMap(zone)
                    }
                    
                case let .Error(error):
                    self.context?.events.echoText("[Automapper]: map loaded with error in \(diff.format(".2")) seconds", preset: "automapper")
                    self.context?.events.echoText("\(error)")
                    if self.nodesLabel != nil {
                        self.nodesLabel.stringValue = "Error loading map: \(error)"
                    }
                }
            })
        }
    }
    
    @IBAction func mapLevelAction(sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            self.mapLevel += 1
        } else {
            self.mapLevel -= 1
        }
    }
    
    @IBAction func mapZoomAction(sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            self.mapZoom += 0.5
        } else {
            self.mapZoom -= 0.5
        }
        
        let clipView = self.scrollView.contentView
        var clipViewBounds = clipView.bounds
        let clipViewSize = clipView.frame.size
        
        clipViewBounds.size.width = clipViewSize.width / self.mapZoom
        clipViewBounds.size.height = clipViewSize.height / self.mapZoom
        
        clipView.setBoundsSize(clipViewBounds.size)
    }
    
    func comboBoxSelectionDidChange(notification: NSNotification) {
        let idx = self.mapsComboBox.indexOfSelectedItem
        let selectedMap = self.mapsDataSource.mapAtIndex(idx)
        
        if self.context?.mapZone != selectedMap.zone {
            self.loadMapFromInfo(selectedMap)

        } else if selectedMap.zone != nil {
            self.renderMap(selectedMap.zone!)
        }
    }
}
