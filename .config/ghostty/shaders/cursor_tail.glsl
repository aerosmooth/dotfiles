/*
MIT License

Copyright (c) 2026 Sahaj Bhatt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Based on:
https://github.com/sahaj-b/ghostty-cursor-shaders/blob/0a274beac8b93ee6ce6b94402b7313a0417b8e38/cursor_tail.glsl

Adjusted for the previous kitty cursor_trail settings:
- Use the active Box cursor color.
- Start after a two-cell move.
- Use a short, visible 0.18 second decay.
*/

vec3 sRGBToLinear(vec3 color) {
    return mix(
        color / 12.92,
        pow((color + 0.055) / 1.055, vec3(2.4)),
        step(vec3(0.04045), color)
    );
}

vec4 TRAIL_COLOR = vec4(
    sRGBToLinear(iCurrentCursorColor.rgb),
    iCurrentCursorColor.a
);

const float DURATION = 0.18;
const float MAX_TRAIL_LENGTH = 0.2;
const float THRESHOLD_MIN_DISTANCE = 2.0;
const float BLUR = 2.0;

float ease(float value) {
    return sqrt(1.0 - pow(value - 1.0, 2.0));
}

float getSdfRectangle(in vec2 point, in vec2 center, in vec2 bounds) {
    vec2 distance = abs(point - center) - bounds;
    return length(max(distance, 0.0))
        + min(max(distance.x, distance.y), 0.0);
}

float segmentDistance(
    in vec2 point,
    in vec2 start,
    in vec2 end,
    inout float signValue,
    float distanceValue
) {
    vec2 edge = end - start;
    vec2 offset = point - start;
    vec2 projection = start
        + edge * clamp(dot(offset, edge) / dot(edge, edge), 0.0, 1.0);
    float projectedDistance = dot(point - projection, point - projection);
    distanceValue = min(distanceValue, projectedDistance);

    float condition0 = step(0.0, point.y - start.y);
    float condition1 = 1.0 - step(0.0, point.y - end.y);
    float condition2 =
        1.0 - step(0.0, edge.x * offset.y - edge.y * offset.x);
    float allConditions = condition0 * condition1 * condition2;
    float noConditions =
        (1.0 - condition0) * (1.0 - condition1) * (1.0 - condition2);
    float flip = mix(
        1.0,
        -1.0,
        step(0.5, allConditions + noConditions)
    );

    signValue *= flip;
    return distanceValue;
}

float getSdfParallelogram(
    in vec2 point,
    in vec2 vertex0,
    in vec2 vertex1,
    in vec2 vertex2,
    in vec2 vertex3
) {
    float signValue = 1.0;
    float distanceValue = dot(point - vertex0, point - vertex0);

    distanceValue = segmentDistance(
        point, vertex0, vertex3, signValue, distanceValue
    );
    distanceValue = segmentDistance(
        point, vertex1, vertex0, signValue, distanceValue
    );
    distanceValue = segmentDistance(
        point, vertex2, vertex1, signValue, distanceValue
    );
    distanceValue = segmentDistance(
        point, vertex3, vertex2, signValue, distanceValue
    );

    return signValue * sqrt(distanceValue);
}

vec2 normalizeCoordinate(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialiasTrail(float distanceValue) {
    return 1.0 - smoothstep(
        0.0,
        normalizeCoordinate(vec2(BLUR), 0.0).x,
        distanceValue
    );
}

float isTopRightLeading(vec2 current, vec2 previous) {
    float condition0 =
        step(previous.x, current.x) * step(current.y, previous.y);
    float condition1 =
        step(current.x, previous.x) * step(previous.y, current.y);
    return 1.0 - max(condition0, condition1);
}

void mainImage(out vec4 fragmentColor, in vec2 fragmentCoordinate) {
    fragmentColor = texture(
        iChannel0,
        fragmentCoordinate.xy / iResolution.xy
    );

    vec2 point = normalizeCoordinate(fragmentCoordinate, 1.0);
    vec2 offsetFactor = vec2(-0.5, 0.5);

    vec4 currentCursor = vec4(
        normalizeCoordinate(iCurrentCursor.xy, 1.0),
        normalizeCoordinate(iCurrentCursor.zw, 0.0)
    );
    vec4 previousCursor = vec4(
        normalizeCoordinate(iPreviousCursor.xy, 1.0),
        normalizeCoordinate(iPreviousCursor.zw, 0.0)
    );

    vec2 currentCenter =
        currentCursor.xy - (currentCursor.zw * offsetFactor);
    vec2 previousCenter =
        previousCursor.xy - (previousCursor.zw * offsetFactor);
    float lineLength = length(previousCenter - currentCenter);
    float minimumDistance =
        currentCursor.w * THRESHOLD_MIN_DISTANCE;

    if (lineLength <= minimumDistance) {
        return;
    }

    float progress = clamp(
        (iTime - iTimeCursorChange) / DURATION,
        0.0,
        1.0
    );
    float delay = MAX_TRAIL_LENGTH / lineLength;
    float longMove = step(MAX_TRAIL_LENGTH, lineLength);

    float headForShortMove = ease(progress);
    float tailForShortMove = ease(smoothstep(delay, 1.0, progress));
    float headProgress = mix(1.0, headForShortMove, longMove);
    float tailProgress = mix(ease(progress), tailForShortMove, longMove);

    vec2 absoluteDelta = abs(currentCenter - previousCenter);
    float straightMove = max(
        step(absoluteDelta.y, 0.001),
        step(absoluteDelta.x, 0.001)
    );

    vec2 headTopLeft = mix(
        previousCursor.xy,
        currentCursor.xy,
        headProgress
    );
    vec2 tailTopLeft = mix(
        previousCursor.xy,
        currentCursor.xy,
        tailProgress
    );

    float topRightLeading =
        isTopRightLeading(currentCursor.xy, previousCursor.xy);
    float bottomLeftLeading = 1.0 - topRightLeading;

    vec2 vertex0 = vec2(
        headTopLeft.x + currentCursor.z * topRightLeading,
        headTopLeft.y - currentCursor.w
    );
    vec2 vertex1 = vec2(
        headTopLeft.x + currentCursor.z * bottomLeftLeading,
        headTopLeft.y
    );
    vec2 vertex2 = vec2(
        tailTopLeft.x + currentCursor.z * bottomLeftLeading,
        tailTopLeft.y
    );
    vec2 vertex3 = vec2(
        tailTopLeft.x + currentCursor.z * topRightLeading,
        tailTopLeft.y - previousCursor.w
    );

    float diagonalTrail = getSdfParallelogram(
        point,
        vertex0,
        vertex1,
        vertex2,
        vertex3
    );

    vec2 headCenter = mix(
        previousCenter,
        currentCenter,
        headProgress
    );
    vec2 tailCenter = mix(
        previousCenter,
        currentCenter,
        tailProgress
    );
    vec2 minimumCenter = min(headCenter, tailCenter);
    vec2 maximumCenter = max(headCenter, tailCenter);
    vec2 boxSize =
        (maximumCenter - minimumCenter) + currentCursor.zw;
    vec2 boxCenter = (minimumCenter + maximumCenter) * 0.5;
    float straightTrail = getSdfRectangle(
        point,
        boxCenter,
        boxSize * 0.5
    );

    float trailShape = mix(
        diagonalTrail,
        straightTrail,
        straightMove
    );
    vec4 outputColor = mix(
        fragmentColor,
        TRAIL_COLOR,
        antialiasTrail(trailShape)
    );

    float currentCursorShape = getSdfRectangle(
        point,
        currentCenter,
        currentCursor.zw * 0.5
    );
    fragmentColor = mix(
        outputColor,
        fragmentColor,
        step(currentCursorShape, 0.0)
    );
}
