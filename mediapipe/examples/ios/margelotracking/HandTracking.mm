#import "HandTracking.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPTimestampConverter.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kOutputLandmarks = "output_landmarks";
static const char* kNumHandsInputSidePacket = "num_hands";

static const int kNumHands = 2;

@interface Landmark()
- (instancetype)initWithCoordinates:(float)x y:(float)y z:(float)z;
@end

@implementation Landmark {}
- (instancetype)initWithCoordinates:(float)x y:(float)y z:(float)z {
  self = [super init];
  if (self) {
    _x = x;
    _y = y;
    _z = z;
  }
  return self;
};
@end

@interface Hand()
- (instancetype)initWithLandmarkList:(const mediapipe::NormalizedLandmarkList&)landmarkList;
@end

@implementation Hand {}
-(instancetype)initWithLandmarkList:(const mediapipe::NormalizedLandmarkList&)landmarkList {
  self = [super init];
  if (self) {
    auto landmarkCount = landmarkList.landmark_size();
    NSMutableArray<Landmark*> *landmarks = [[NSMutableArray alloc] initWithCapacity: landmarkCount];
    for (int i = 0; i < landmarkCount; i++) {
      mediapipe::NormalizedLandmark l = landmarkList.landmark(i);
      float x = l.x();
      float y = l.y();
      float z = l.z();
      Landmark *landmark = [[Landmark alloc] initWithCoordinates:x y:y z:z];
    }
    _landmarks = landmarks;
  }
  return self;
};
@end

@interface HandTracking() <MPPGraphDelegate>
@property (nonatomic) MPPGraph* mediapipeGraph;
@property (nonatomic) MPPTimestampConverter* timestampConverter;
@end

@implementation HandTracking {}

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
  [newGraph setSidePacket:(mediapipe::MakePacket<int>(kNumHands)) named:kNumHandsInputSidePacket];
  [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
  [newGraph addFrameOutputStream:kOutputLandmarks outputPacketType:MPPPacketTypeRaw];
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
    if (streamName == kOutputLandmarks) {
      if (packet.IsEmpty()) {
        // call delegate with no outputs
        return;
      }
      const auto& handLandmarkLists = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
      NSMutableArray *hands = [NSMutableArray array];
      for (const auto& handLandmarkList : handLandmarkLists) {
        Hand *hand = [[Hand alloc] initWithLandmarkList:handLandmarkList];
        [hands addObject:hand];
      }
      [_delegate didOutputHandTracking:hands];
    }
}

@end
