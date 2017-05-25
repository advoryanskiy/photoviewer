/********* PhotoViewer.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuickLook/QuickLook.h>

@interface PhotoViewer : CDVPlugin <QLPreviewControllerDataSource> {
  // Member variables go here.
}

@property (nonatomic, strong) QLPreviewController *docPreviewController;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSMutableArray *documentURLs;

- (void)show:(CDVInvokedUrlCommand*)command;
@end

@implementation PhotoViewer

- (void)setupDocumentControllerWithURL:(NSURL *)url andTitle:(NSString *)title
{
    if (self.docPreviewController == nil) {
        self.docPreviewController = [[QLPreviewController alloc] init];
        self.docPreviewController.dataSource = self;
        self.docPreviewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Закрыть" style:UIBarButtonItemStylePlain target:self action:@selector(closePreview)];
        
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font =[[UINavigationBar appearance].titleTextAttributes objectForKey:NSFontAttributeName];
        
        self.dockPreviewController.navigationItem.titleView = self.titleLabel;
    }
    
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];
}

- (UIDocumentInteractionController *) setupControllerWithURL: (NSURL*) fileURL
                                               usingDelegate: (id <UIDocumentInteractionControllerDelegate>) interactionDelegate {

    UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL: fileURL];
    interactionController.delegate = interactionDelegate;

    return interactionController;
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:self.viewController.view.frame];
    [activityIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [activityIndicator.layer setBackgroundColor:[[UIColor colorWithWhite:0.0 alpha:0.30] CGColor]];
    CGPoint center = self.viewController.view.center;
    activityIndicator.center = center;
    [self.viewController.view addSubview:activityIndicator];
    
    [activityIndicator startAnimating];
    
    
    CDVPluginResult* pluginResult = nil;
    NSString* url = [command.arguments objectAtIndex:0];
    NSString* title = [command.arguments objectAtIndex:1];

    if (url != nil && [url length] > 0) {
        [self.commandDelegate runInBackground:^{
            self.documentURLs = [NSMutableArray array];

            NSURL *URL = [self localFileURLForImage:url];

            if (URL) {
                [self.documentURLs addObject:URL];
                [self setupDocumentControllerWithURL:URL andTitle:title];
                double delayInSeconds = 0.1;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [activityIndicator stopAnimating];
//                    [self.docInteractionController presentPreviewAnimated:YES];
                    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.docPreviewController];
                    [self.viewController presentViewController:navController animated:YES completion:nil];
                });
            }
        }];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSURL *)localFileURLForImage:(NSString *)image
{
    // save this image to a temp folder
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *filename = [[NSUUID UUID] UUIDString];
    NSURL *fileURL = [NSURL URLWithString:image];
    if ([fileURL isFileReferenceURL]) {
        return fileURL;
    }

    NSData *data = [NSData dataWithContentsOfURL:fileURL];

    if( data ) {
        fileURL = [[tmpDirURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:[self contentTypeForImageData:data]];

        [[NSFileManager defaultManager] createFileAtPath:[fileURL path] contents:data attributes:nil];

        return fileURL;
    } else {
        return nil;
    }
}

- (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];

    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
    }
    return nil;
}

- (void)closePreview {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.documentURLs.length;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [self.documentURLs objectAtIndex:index];
}

@end
