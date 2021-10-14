// Copyright (c) 2020 Facebook, Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
#import "InferenceModule.h"
#import <Libtorch-Lite/Libtorch-Lite.h>

// 640x640 is the default image size used in the export.py in the yolov5 repo to export the TorchScript model, 25200*85 is the model output size
const int input_width = 640;
const int input_height = 640;
//const int output_size = 25200*85;
const int output_size = 25200*9; // BCJ - determined by inspecting the shape of the prediction from detect.py for df2.pt

@implementation InferenceModule {
    @protected torch::jit::mobile::Module _impl;
}

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath {
    self = [super init];
    if (self) {
        try {
            _impl = torch::jit::_load_for_mobile(filePath.UTF8String);
        } catch (const std::exception& exception) {
            NSLog(@"%s", exception.what());
            return nil;
        }
    }
    return self;
}

- (NSArray<NSNumber*>*)detectImage:(void*)imageBuffer {
    try {
        at::Tensor tensor = torch::from_blob(imageBuffer, { 1, 3, input_width, input_height }, at::kFloat);

        c10::InferenceMode guard;
        CFTimeInterval startTime = CACurrentMediaTime();
        auto outputTuple = _impl.forward({ tensor }).toTuple();
        CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
        NSLog(@"inf time:%.2f", elapsedTime);

        auto outputTensor = outputTuple->elements()[0].toTensor();

        float* floatBuffer = outputTensor.data_ptr<float>();
        if (!floatBuffer) {
            return nil;
        }
        
        NSMutableArray* results = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < output_size; i++) {
          //NSLog(@"%i", i);
          [results addObject:@(floatBuffer[i])];
        }

        return [results copy];
        
    } catch (const std::exception& exception) {
        NSLog(@"%s", exception.what());
    }
    return nil;
}

@end
