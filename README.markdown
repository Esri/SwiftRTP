# SwiftRTP

Swift 2 (iOS and Mac OS) implementation of RTP (["RTP: A Transport Protocol
for Real-Time Applications"](https://tools.ietf.org/html/rfc3550)) and the H264
RTP Profile (["RTP Payload Format for H.264 Video"](http://tools.ietf.org/html/rfc3984)).

## What Works

* Hardware acceleration of H264 decoding on (supported) iOS devices. (See the
[WWDC 2014 Session 513: "Direct Access to
Video Encoding and Decoding](https://developer.apple.com/videos/wwdc/2014/#513)).
* Live streaming of RTP H264 video from [3DRobotics Solo](http://3drobotics.com/solo-drone/) drone.
* Partial support of live streaming of ffmpeg rtp streams. Run a "test card"
video stream using ffmpeg, the sample app will connect to it and display the
card - (maybe with some corruption due to buggy `STAP-A` processing). (See
[Documentation/](Documentation/) folder for more info on ffmpeg)

```sh
ffmpeg -re -f lavfi -i smptebars -vcodec libx264 -tune zerolatency -vf scale=1920:1080 -b 900k -sdp_file stream.sdp -f rtp "rtp://127.0.0.1:5600"
```

## What Does Not Work

* Check the liberal amount of `// TODO`s in the code.
* RTP padding, extensions and csrcs are not supported yet. If a RTP packet
contains any of these elements it will be dropped.
* The `STAP-A` RTP H264 packet type is not tested well and doesn't seem to be
reliable. Further work is needed.
* The following RTP H264 packet types are not yet supported:
  - `FU-B`
  - `STAP-B`
  - `MTAP-A`
  - `MTAP-B`

## Future

* Fix items in the "What Does Not Work" section. The extra packet
types are low priority. They're generally not seen coming either from 3DR Solo
or from ffmpeg.
* Better support for handling SPS and PPS packets. It would be nice if the
`DecompressionSession` class could handle changed parameters better.
* Preload SPS and PPS packets for "fast starts".
* Configure the RTP packet type. 96 (the first user-available type) is
hard-coded.
* SDP file reader?
* Hooks for logging (don't log to println)
* For STAP and MTAP packets we _should_ be calling CMSampleBufferCreate once for
all samples in the packet.
