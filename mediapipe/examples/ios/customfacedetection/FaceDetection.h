#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@class FaceDetection;
@class BoundingBox;

@interface BoundingBox: NSObject
@property (nonatomic) float x;
@property (nonatomic) float y;
@property (nonatomic) float width;
@property (nonatomic) float height;
@property (nonatomic) float score;
@end

@interface FaceDetection: NSObject
-(instancetype) init;
-(NSArray<BoundingBox*>*) processVideoFrame: (CVPixelBufferRef)imageBuffer timestamp:(CMTime)timestamp;
@end
