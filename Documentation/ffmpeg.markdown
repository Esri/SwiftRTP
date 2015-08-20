# ffmpeg for dummies

## Links:

https://trac.ffmpeg.org/wiki/StreamingGuide

https://ffmpeg.org/ffmpeg-devices.html

http://www.ffmpeg.org/ffmpeg-protocols.html#toc-rtp

## RTP

https://tools.ietf.org/html/rfc3550

[RTP Payload Format for H.264 Video](http://tools.ietf.org/html/rfc3984)

    SliceNonIDR = 1 // P/B-Frame
    SliceIDR = 5 // I-Frame
    SPS = 7 // "Sequence Parameter Set"
    PPS = 8 // "Picture Parameter Set"

    STAP_A = 24
    STAP_B = 25
    MTAP16 = 26
    MTAP24 = 27
    FU_A = 28
    FU_B = 29



## Installing ffmpeg

The `--with-ffplay` is necessary if you want to play streams.

```
brew install ffmpeg --with-ffplay
```

## RTP broadcast on localhost:5600

Note this generates a .sdp file.

```
ffmpeg -re -f lavfi -i smptebars -vcodec libx264 -tune zerolatency -vf scale=1920:1080 -b 900k -sdp_file stream.sdp -f rtp "rtp://127.0.0.1:5600"
```

Mainly sends STAP-A packets.

## Play above rtp stream

```
ffplay stream.sdp
```

## List all AVFoundation devices

```
ffmpeg -f avfoundation -list_devices true -i ""
```

# Record default AVFoundation device to MPEG-1 Video file

```
ffmpeg -f avfoundation -i "default" out.mpg
```

# Stream from Default AVFoundation device

```
ffmpeg -re -f avfoundation -i "default" -vcodec libx264 -sdp_file stream.sdp -f rtp "rtp://127.0.0.1:5600"
```

```
ffmpeg -framerate 30 -f avfoundation -i "default" -vcodec libx264 -tune zerolatency -vf scale=1920:1080 -b 900k -sdp_file stream.sdp -f rtp "rtp://127.0.0.1:5600"
```

`-frametate 30` may or may not be needed.

`-tune zerolatency`
