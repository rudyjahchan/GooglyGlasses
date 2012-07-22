#import "GGViewController.h"

@interface GGViewController ()

@property (nonatomic, strong) AVCaptureSession* session;
@property (nonatomic, strong) CIDetector* faceDetector;
@property (nonatomic, strong) CALayer* imageLayer;

- (void) startCamera;
- (void) stopCamera;
- (void) renderEyeOn:(CGContextRef)context at:(CGPoint) point radius:(CGFloat)radius;

@end

@implementation GGViewController

@synthesize session;
@synthesize faceDetector;
@synthesize imageLayer;

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.imageLayer = [CALayer layer];
  imageLayer.frame = self.view.layer.bounds;
  imageLayer.contentsGravity = kCAGravityResizeAspectFill;
  [self.view.layer addSublayer:imageLayer];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
  self.imageLayer = nil;
}

- (void)viewDidAppear:(BOOL)animated {
  [self startCamera];
}

- (void)viewWillAppear:(BOOL)animated {
  [self stopCamera];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)startCamera {
  AVCaptureDevice *device = nil;
  NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (device in devices) {
    if (device.position == AVCaptureDevicePositionFront) {
      break;
    }
  }
  
  self.session = [[AVCaptureSession alloc] init];
  [session beginConfiguration];
  [session setSessionPreset:AVCaptureSessionPresetLow];  
  NSError* error;
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  if (!input) {
    // Handle the error appropriately.
  }
  [session addInput:input];
  AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
  [session addOutput:output];
  
  dispatch_queue_t queue = dispatch_queue_create("googleGoggleCaptureQueue", DISPATCH_QUEUE_SERIAL);
  [output setSampleBufferDelegate:self queue:queue];
  dispatch_release(queue);
  
  AVCaptureConnection* connection = [output connectionWithMediaType:AVMediaTypeVideo];
  [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
  output.videoSettings =
  [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  output.alwaysDiscardsLateVideoFrames = YES;
  [session commitConfiguration];
  [session startRunning];
  
  NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   CIDetectorAccuracyLow, CIDetectorAccuracy, 
                                   nil];
	self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];  
}

- (void)stopCamera {
   [session stopRunning];
  self.session = nil;
  self.faceDetector = nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:imageBuffer];
  CVPixelBufferLockBaseAddress(imageBuffer, 0); 
  void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
  size_t width = CVPixelBufferGetWidth(imageBuffer); 
  size_t height = CVPixelBufferGetHeight(imageBuffer); 
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
  CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, 
                                               bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);  
  CGContextSetRGBFillColor(context, 0, 0, 0, 0);
  CGContextSetRGBStrokeColor(context, 1.0, 0, 0, 1);
  CGContextSetLineWidth(context, 2.0);
  
  NSArray* features = [faceDetector featuresInImage:image options:nil];
  for(CIFaceFeature* faceFeature in features) {
    if(faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition) {      
      CGFloat width = faceFeature.leftEyePosition.x - faceFeature.rightEyePosition.x;
      if (width < 0) {
        width *= -1.0;
      }
      
      CGFloat height = faceFeature.leftEyePosition.y - faceFeature.rightEyePosition.y;
      if (height < 0) {
        height *= -1.0 ;
      }
      
      CGFloat distance = sqrt(pow(width, 2.0) + pow(height, 2.0))/2.0;
      [self renderEyeOn:context at:faceFeature.leftEyePosition radius:distance];
      [self renderEyeOn:context at:faceFeature.rightEyePosition radius:distance];
    }
  }
  CGImageRef quartzImage = CGBitmapContextCreateImage(context); 
  CVPixelBufferUnlockBaseAddress(imageBuffer,0);

  CGContextRelease(context); 
  CGColorSpaceRelease(colorSpace);
  
  id renderedImage = CFBridgingRelease(quartzImage);
  
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    [CATransaction setDisableActions:YES];
    [CATransaction begin];
		imageLayer.contents = renderedImage;
    [CATransaction commit];
	});
}

- (void) renderEyeOn:(CGContextRef)context at:(CGPoint) point radius:(CGFloat)radius{
  CGContextSetRGBFillColor(context, 1, 1, 1, 1);
  CGContextBeginPath(context);
  CGContextMoveToPoint(context, point.x, point.y - radius);
  CGContextAddArcToPoint(context, point.x + radius, point.y - radius, 
                         point.x + radius, point.y, radius);
  CGContextAddArcToPoint(context, point.x + radius, point.y + radius, 
                         point.x, point.y + radius, radius);
  CGContextAddArcToPoint(context, point.x - radius, point.y + radius, 
                         point.x - radius, point.y, radius);
  CGContextAddArcToPoint(context, point.x - radius, point.y - radius, 
                         point.x, point.y - radius, radius);
  CGContextClosePath(context);
  CGContextDrawPath(context, kCGPathFill);
  
  CGFloat pupilRadius = radius / 2.0;
  
  CGContextSetRGBFillColor(context, 0, 0, 0, 1);
  CGContextBeginPath(context);
  CGContextMoveToPoint(context, point.x, point.y - pupilRadius);
  CGContextAddArcToPoint(context, point.x + pupilRadius, point.y - pupilRadius, 
                         point.x + pupilRadius, point.y, pupilRadius);
  CGContextAddArcToPoint(context, point.x + pupilRadius, point.y + pupilRadius, 
                         point.x, point.y + pupilRadius, pupilRadius);
  CGContextAddArcToPoint(context, point.x - pupilRadius, point.y + pupilRadius, 
                         point.x - pupilRadius, point.y, pupilRadius);
  CGContextAddArcToPoint(context, point.x - pupilRadius, point.y - pupilRadius, 
                         point.x, point.y - pupilRadius, pupilRadius);
  CGContextClosePath(context);
  CGContextDrawPath(context, kCGPathFill);
}

@end
