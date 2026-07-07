//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_doc_scanner/SwiftFlutterDocScannerPlugin.h>)
#import <flutter_doc_scanner/SwiftFlutterDocScannerPlugin.h>
#else
@import flutter_doc_scanner;
#endif

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [SwiftFlutterDocScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"SwiftFlutterDocScannerPlugin"]];
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
}

@end
