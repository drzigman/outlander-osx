//
//  AppSettingsLoader.m
//  Outlander
//
//  Created by Joseph McBride on 5/6/14.
//  Copyright (c) 2014 Joe McBride. All rights reserved.
//

#import "AppSettingsLoader.h"
#import "WindowDataService.h"
#import "ProfileLoader.h"
#import "HighlightsLoader.h"
#import "LocalFileSystem.h"
#import "AliasLoader.h"
#import "VariablesLoader.h"
#import "MacrosLoader.h"
#import "Outlander-Swift.h"

@interface AppSettingsLoader () {
    GameContext *_context;
    WindowDataService *_windowDataService;
    ProfileLoader *_profileLoader;
    HighlightsLoader *_highlightsLoader;
    AliasLoader *_aliasLoader;
    VariablesLoader *_variablesLoader;
    MacrosLoader *_macrosLoader;
    TriggersLoader *_triggersLoader;
    SubstituteLoader *_substituteLoader;
    GagsLoader *_gagsLoader;
    PresetLoader *_presetLoader;
    VitalsLoader *_vitalsLoader;
    ClassesLoader *_classesLoader;
    AppConfigLoader *_appConfigLoader;
}
@end

@implementation AppSettingsLoader

- (id)initWithContext:(GameContext *)context {
    self = [super init];
    if(!self) return nil;
    
    _context = context;
    _windowDataService = [[WindowDataService alloc] init];
    _profileLoader = [[ProfileLoader alloc] initWithContext:_context];
    id<FileSystem> fileSystem = [[LocalFileSystem alloc] init];
    _highlightsLoader = [[HighlightsLoader alloc] initWithContext:_context andFileSystem:fileSystem];
    _aliasLoader = [[AliasLoader alloc] initWithContext:_context andFileSystem:fileSystem];
    _variablesLoader = [[VariablesLoader alloc] initWithContext:_context andFileSystem:fileSystem];
    _macrosLoader = [[MacrosLoader alloc] initWithContext:_context andFileSystem:fileSystem];
    _triggersLoader = [TriggersLoader newInstance:_context fileSystem:fileSystem];
    _substituteLoader = [SubstituteLoader newInstance:_context fileSystem:fileSystem];
    _gagsLoader = [GagsLoader newInstance:_context fileSystem:fileSystem];
    _presetLoader = [PresetLoader newInstance:_context fileSystem:fileSystem];
    _vitalsLoader = [VitalsLoader newInstance:_context fileSystem:fileSystem];
    _classesLoader = [ClassesLoader newInstance:_context fileSystem:fileSystem];
    _appConfigLoader = [AppConfigLoader newInstance:_context fileSystem:fileSystem];
    
    return self;
}

- (void)loadProfile:(NSString *)profile {
    
    if ([profile length] > 0 && ![_context.settings.profile isEqualToString:profile]) {
        
        _context.settings.profile = profile;
        [self load];
    }
}

- (void)load {
    
    [self writeConfigFolders:_context.settings.profile];
    [self writeProfileFolders:_context.settings.profile];

    [self loadProfile];
    
    [self loadLayout:_context.settings.layout];
    
    [self loadHighlights];
    [self loadVariables];
    [self loadAliases];
    [self loadMacros];
    [self loadTriggers];
    [self loadSubs];
    [self loadGags];
    [self loadPresets];
    [self loadVitals];
    [self loadClassses];
}

- (void)loadConfig {
    [_appConfigLoader load];
}

- (void)saveConfig {
    [_appConfigLoader save];
}

- (void)loadLayout:(NSString *)file {
    _context.layout = [_windowDataService readFromFile:file withContext:_context];
}

- (void)saveLayout:(NSString *)file {
    [_windowDataService write:_context.layout toFile:file withContext:_context];
}

- (void)loadProfile {
    [_profileLoader load];
}

- (void)saveProfile {
    [_profileLoader save];
}

- (void)loadHighlights {
    [_highlightsLoader load];
}

- (void)saveHighlights {
    [_highlightsLoader save];
}

- (void)loadVariables {
    [_variablesLoader load];
}

- (void)saveVariables {
    [_variablesLoader save];
}

- (void)loadAliases {
    [_aliasLoader load];
}

- (void)saveAliases {
    [_aliasLoader save];
}

- (void)loadMacros {
    [_macrosLoader load];
}

- (void)saveMacros {
    [_macrosLoader save];
}

- (void)loadTriggers {
    [_triggersLoader load];
}

- (void)saveTriggers {
    [_triggersLoader save];
}

- (void)loadSubs {
    [_substituteLoader load];
}

- (void)saveSubs {
    [_substituteLoader save];
}

- (void)loadGags {
    [_gagsLoader load];
}

- (void)saveGags {
    [_gagsLoader save];
}

- (void)loadPresets {
    [_presetLoader load];
}

- (void)savePresets {
    [_presetLoader save];
}

- (void)loadVitals {
    [_vitalsLoader load];
}

- (void)saveVitals {
    [_vitalsLoader save];
}

- (void)loadClassses {
    [_classesLoader load];
}

- (void)saveClasses {
    [_classesLoader save];
}

- (void)writeConfigFolders:(NSString *)profile {
    [self ensurePath:[_context.pathProvider layoutFolder]];
    [self ensurePath:[_context.pathProvider logsFolder]];
    [self ensurePath:[_context.pathProvider scriptsFolder]];
    [self ensurePath:[_context.pathProvider mapsFolder]];
    [self ensurePath:[_context.pathProvider soundsFolder]];
}

- (void)writeProfileFolders:(NSString *)profile {
    [self ensurePath:[_context.pathProvider folderForProfile:profile]];
}

- (void)ensurePath:(NSString *)path {
    NSError *error;
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:path]){
        [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if(error) {
            NSLog(@"%@", error.localizedDescription);
        }
    }
}

@end
