//
//  ColorFilterKernel.metal
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

#include <metal_stdlib>
using namespace metal;

#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        float4 colorFilterKernel(sample_t s) {
            float4 swappedColor;
            swappedColor.r = s.g;
            swappedColor.g = s.b;
            swappedColor.b = s.r;
            swappedColor.a = s.a;
            return swappedColor;
        }
        
        float4 colorFilterKernel2(sample_t s) {
            float4 swappedColor;
            swappedColor.r = s.b;
            swappedColor.g = s.r;
            swappedColor.b = s.g;
            swappedColor.a = s.a;
            return swappedColor;
        }
    }
}
