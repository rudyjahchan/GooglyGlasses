#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface GGViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic) BOOL isFrontFacing;

@end
