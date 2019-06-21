![header](./ed-badge.png)

----

# audioLock
A quick attempt to lock an audio player into position using only panning and Bose AR yaw.

## What this currently does
Pair up your Bose Frames, and once the application starts getting sensor data from them, you'll hear crowd noise which should be on your right (full right pan). Pan of value 1. If you don't, hit the callibrate button while looking straight ahead. 

Turn your head to the right and you should hear the audio pan inverse to your head movement - essentially locking the audio in place. The pan adjustment is made every 20ms, based upon the rate set in code for `gameRotation`. I have seen values that are quicker than that, but I have heard that 20ms is a stable number.

When looking to the left, I think we may need to reduce the volume with an algorithm or something to get that effect since you can't pan past full right with a simple panning approach. 

## What this is for
This is mostly a quick proof of concept/playground application just to see how good things might be without using Mach1 encode/decode and it's positioning system.
