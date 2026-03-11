#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// .r contains the info if the cell is sand (1) or not (0)
// .g is used for masking. The mask prevents a piece of sand from falling twice in two consecutive steps.
// This is needed because this block cellular automata works in something akin to "half steps"
layout(rg8, set = 0, binding = 0) restrict uniform image2D terrain;

// Push Constant will be padded to be multiple of 16 bytes
layout(push_constant, std430) uniform Params {
    int offset;
    float time;
    ivec2 mousePos;
} params;

// Hashes from https://github.com/Angelo1211/2020-Weekly-Shader-Challenge/blob/master/hashes.glsl
uint murmurHash13(uvec3 src) {
    const uint M = 0x5bd1e995u;
    uint h = 1190494759u;
    src *= M; src ^= src>>24u; src *= M;
    h *= M; h ^= src.x; h *= M; h ^= src.y; h *= M; h ^= src.z;
    h ^= h>>13u; h *= M; h ^= h>>15u;
    return h;
}
// 1 output, 3 inputs
float hash13(vec3 src) {
    uint h = murmurHash13(floatBitsToUint(src));
    return uintBitsToFloat(h & 0x007fffffu | 0x3f800000u) - 1.0;
}

// Sampling function with boundary handling
ivec2 loadCoordinate(ivec2 id, ivec2 size) {
    if(params.mousePos == id) {
        return ivec2(1,0);
    }
    if(id.y >= size.y) {
        return ivec2(1,0);
    }
    if(id.y < 0 || id.x < 0 || id.x >= size.x) {
        return ivec2(0,0);
    }
    return ivec2(imageLoad(terrain, id).rg);
}

// Writing function with boundary handling
void storeCoordinate(ivec2 id, ivec2 size, ivec2 value) {
    if(any(greaterThanEqual(id, size)) || any(lessThan(id, ivec2(0)))) {
        return;
    }
    imageStore(terrain, id, vec4(value.r, value.g, 0, 0));
}

int transitionCode(int code, float rng) {
    // Low Chance for nothing to change to break up patterns due to algorithm
    if(rng > 0.85) return code;
    switch(code) {
        case 4: 
            return (rng > 0.98 ? 2 : 1);
        case 5: case 6: case 9: case 10: case 12: 
            return 3;
        case 8: 
            return (rng > 0.98 ? 1 : 2);
        case 13: 
            return( rng > 0.98 ? 11 : 7);
        case 14: 
            return( rng > 0.98 ? 7: 11);
        default: return code;
    }
    return code;
}

const ivec2 offsets[4] = {
    {1,1},
    {0,1},
    {1,0},
    {0,0}
};

void main() {
    // Upper left corner of 2x2 block. Can have negative coordinates!
    ivec2 baseID = 2 * ivec2(gl_GlobalInvocationID.xy) - params.offset;
    ivec2 size = imageSize(terrain);
    if(any(greaterThanEqual(baseID, size))) {
        return;
    }

    ivec2 value = ivec2(0);
    for(int i = 0; i < 4; ++i) {
        value += loadCoordinate(baseID + offsets[i], size) << i;
    }

    int newValue = transitionCode(value.r & (15 - value.g), hash13(vec3(baseID, params.time)));
    int origValue = value.r;
    value.r = (origValue & value.g) | newValue;
    value.g = (15 - origValue) & value.r;

    for(int i = 0; i < 4; ++i) {
        ivec2 val = (value & (1 << i)) >> i;
        storeCoordinate(baseID + offsets[i], size, val);
    }
}