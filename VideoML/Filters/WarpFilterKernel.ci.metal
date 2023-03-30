//
//  WarpFilterKernel.metal
//  VideoML
//
//  Created by Aslan Arapbaev on 3/26/23.
//

#include <metal_stdlib>
using namespace metal;

#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        float2 warpFilter(destination dest) {
            float y = dest.coord().y + tan(dest.coord().y / 10) * 2;
            float x = dest.coord().x + tan(dest.coord().x/ 10) * 2;
            return float2(x,y);
        }
    }
}
