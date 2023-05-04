#import "FaceDetection.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPTimestampConverter.h"
#include "mediapipe/framework/formats/detection.pb.h"

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
@property (nonatomic) MPPGraph* mediapipeGraph;
@property (nonatomic) MPPTimestampConverter* timestampConverter;
@end

@implementation FaceDetection {}

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
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
  MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
  // [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
  [newGraph addFrameOutputStream:kOutputDetections outputPacketType:MPPPacketTypeRaw];
  return newGraph;
}

-(instancetype) init {
  self = [super init];
  if (self) {
    self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
    self.mediapipeGraph.delegate = self;
    self.mediapipeGraph.maxFramesInFlight = 2;
    self.timestampConverter = [[MPPTimestampConverter alloc] init];
  }
  return self;
}

- (void)dealloc {
  self.mediapipeGraph.delegate = nil;
  [self.mediapipeGraph cancel];
  // Ignore errors since we're cleaning up.
  [self.mediapipeGraph closeAllInputStreamsWithError:nil];
  [self.mediapipeGraph waitUntilDoneWithError:nil];
}

- (void)startGraph {
  // Start running self.mediapipeGraph.
  NSError* error;
  if (![self.mediapipeGraph startWithError:&error]) {
    NSLog(@"Failed to start graph: %@", error);
  }
  else if (![self.mediapipeGraph waitUntilIdleWithError:&error]) {
    NSLog(@"Failed to complete graph initial run: %@", error);
  }
}

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp:(CMTime)timestamp {
  [self.mediapipeGraph sendPixelBuffer:imageBuffer
                       intoStream:kInputStream
                       packetType:MPPPacketTypePixelBuffer
                       timestamp:[self.timestampConverter timestampForMediaTime:timestamp]];
}

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
    fromStream:(const std::string&)streamName {
    // [_delegate faceDetection:self didOutputPixelBuffer:pixelBuffer];
}

- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    NSLog(@"mediapipeGraph:didOutputPacket:fromStream: %@", @(streamName.c_str()));
    if (streamName == kOutputDetections) {
      if (packet.IsEmpty()) {
        NSLog(@"Empty packet.");
        // call delegate with no outputs
        return;
      }
      const auto& detections = packet.Get<std::vector<::mediapipe::Detection>>();
      NSMutableArray *result = [NSMutableArray array];
      for (const auto& detection : detections) {
        BoundingBox *box = [[BoundingBox alloc] initWithDetection:detection];
        // if (box.score > 0.5) {
          [result addObject:box];
        // }
      }
      [_delegate faceDetection:self didOutputDetections:result];
    }
}

@end
