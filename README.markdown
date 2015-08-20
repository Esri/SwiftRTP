# SwiftRTP

Swift 1.2 implementation of RTP and the H264 RTP Profile.

## What Works

* Run the sample OS X application. It should be able to connect to a 3DR Solo and
display a video stream (along with statistics about failed packets etc).

* Run a "test card" video stream using ffmpeg, the sample app will connect to it
and display the card - (maybe with some corruption due to buggy `STAP-A`)

```sh
ffmpeg -re -f lavfi -i smptebars -vcodec libx264 -tune zerolatency -vf scale=1920:1080 -b 900k -sdp_file stream.sdp -f rtp "rtp://127.0.0.1:5600"
```

## What Does Not Work

* Check the liberal amount of `// TODO`s in the code.
* This code leaks like a sieve. Do not use in production!!! Lots of leaks of
DispatchData objects (because they're retained by CMDataBuffers but not cleaned
up). Use of `Unmanaged <>` needs to be validated.
* Embeds (private) subsets of SwiftIO and SwiftUtilities. These frameworks
should be made internal. However some of SwiftUtilities is exposed (e.g.
DispatchData)
* RTP padding, extensions and csrcs are not supported yet. If a RTP packet
contains any of these elements it will be dropped.
* The `STAP-A` RTP H264 packet type is not tested well and doesn't seem to be
reliable. Further work is needed.
* The following RTP H264 packet types are not yet supported:
  - `FU-B`
  - `STAP-B`
  - `MTAP-A`
  - `MTAP-B`
* `CMSampleBuffers` are created with a bad timestamp. It is currently ignoring the
timestamp from the RTP packet. This means you cannot write these sample buffers
to file.

## Notes

This was originally written in Swift 2.0 using SwiftIO and SwiftUtilities but we
needed to back port this to Swift 1.2. 2.0 is _much_ better with the CoreMedia
and CoreVideo APIs - being able to provide callbacks in Swift instead of dropping
down to C and avoiding `Unmanaged` make 2.0 far superior. In addition Swift 2.0's
error handling really made this a very robust API (for very little work). I've
tried to emulate Swift 2.0's error handling in 1.2 to some extent but it
definitely is not as pretty.
