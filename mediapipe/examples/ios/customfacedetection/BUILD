# Copyright 2019 The MediaPipe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",
)
# load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

licenses(["notice"])

MIN_IOS_VERSION = "14.0"

ios_framework(
    name = "FaceDetection",
    hdrs = [
        "FaceDetection.h"
    ],
    infoplists = ["Info.plist"],
    visibility = ["//visibility:public"],
    bundle_id = "com.thomascoldwell.FaceDetection",
    families = ["iphone", "ipad"],
    minimum_os_version = MIN_IOS_VERSION,
    deps = [
        ":FaceDetectionGpuLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "FaceDetectionGpuLibrary",
    srcs = [
      "FaceDetection.mm"
    ],
    hdrs = [
      "FaceDetection.h"
    ],
    data = [
        "//mediapipe/graphs/face_detection:face_detection_mobile_gpu.binarypb",
        "//mediapipe/modules/face_detection:face_detection_full_range_sparse.tflite",
    ],
    visibility = ["//visibility:public"],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
        "//third_party/apple_frameworks:AVFoundation",
        "//third_party/apple_frameworks:CoreGraphics",
        "//third_party/apple_frameworks:CoreMedia",
        "//third_party/apple_frameworks:UIKit",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/face_detection:mobile_calculators",
            "//mediapipe/modules/face_detection:face_detection_full_range_gpu"
        ],
    }),
)
