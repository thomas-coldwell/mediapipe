#import "FaceDetection.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPTimestampConverter.h"
#include "mediapipe/framework/formats/detection.pb.h"

#import "mediapipe/tasks/ios/vision/core/MPPVisionTaskRunner.h"
#import "mediapipe/tasks/ios/vision/core/MPPImage.h"

static NSString* const kGraphName = @"face_detection_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kOutputDetections = "face_detections";

@interface BoundingBox()
- (instancetype)initWithDetection:(const mediapipe::Detection&)detection;
@end

@implementation BoundingBox {}
-(instancetype)initWithDetection:(const mediapipe::Detection&)detection {
  self = [super init];
  if (self) {
    _x = detection.location_data().relative_bounding_box().xmin();
    _y = detection.location_data().relative_bounding_box().ymin();
    _width = detection.location_data().relative_bounding_box().width();
    _height = detection.location_data().relative_bounding_box().height();
    _score = detection.score()[0];
  }
  return self;
};
@end

@interface FaceDetection() <MPPGraphDelegate> 
@property (nonatomic) MPPTaskRunner* taskRunner;
@property (nonatomic) MPPTimestampConverter* timestampConverter;
@end

@implementation FaceDetection {}

+ (MPPTaskRunner*)loadTaskRunnerFromResource:(NSString*)resource {
  // Load the graph config resource.
  NSError* configLoadError = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  if (!resource || resource.length == 0) {
    return nil;
  }
  NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
  NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
  if (!data) {
    NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
    return nil;
  }

  // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
  mediapipe::CalculatorGraphConfig config;
  config.ParseFromArray(data.bytes, data.length);

  // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
  MPPTaskRunner* newTaskRunner = [[MPPTaskRunner alloc] initWithCalculatorGraphConfig:config];
  return taskRunner;
}

-(instancetype) init {
  self = [super init];
  if (self) {
    self.taskRunner = [[self class] loadTaskRunnerFromResource:kGraphName];
  }
  return self;
}

- (void)dealloc {
  // Ignore errors since we're cleaning up.
  [self.taskRunner closeWithError:nil];
}

- (BoundingBox *)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp:(CMTime)timestamp {
  // Create input packet for image buffer
  MPPImage *mpImage = [[MPPImage alloc] initWithPixelBuffer:imageBuffer];
}

@end
