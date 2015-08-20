//
//  BitRange.swift
//  BinaryTest
//
//  Created by Jonathan Wight on 6/24/15.
//
//  Copyright (c) 2014, Jonathan Wight
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import Foundation

public func bitRange <T: UnsignedIntegerType> (value: T, # start: Int, # length: Int, flipped: Bool = false) -> T {
    assert(sizeof(T) <= sizeof(UIntMax))
    let bitSize = UIntMax(sizeof(T) * 8)
    assert(start + length <= Int(bitSize))
    if flipped {
        let shift = bitSize - UIntMax(start) - UIntMax(length)
        let mask = (1 << UIntMax(length)) - 1
        let intermediate = value.toUIntMax() >> shift & mask
        let result = intermediate
        return T.init(result)
    }
    else {
        let shift = UIntMax(start)
        let mask = (1 << UIntMax(length)) - 1
        let result = value.toUIntMax() >> shift & mask
        return T.init(result)
    }
}

public func bitRange <T: UnsignedIntegerType> (value: T, # range: Range <Int>, flipped: Bool = false) -> T {
    return bitRange(value, start: range.startIndex, length: range.endIndex - range.startIndex, flipped: flipped)
}

// MARK: -

public func bitRange(buffer: UnsafeBufferPointer <Void>, # start: Int, # length: Int) -> UIntMax {
    let pointer = buffer.baseAddress

    // Fast path; we want whole integers and the range is aligned to integer size.
    if length == 64 && start % 64 == 0 {
        return UnsafePointer <UInt64> (pointer)[start / 64]
    }
    else if length == 32 && start % 32 == 0 {
        return UIntMax(UnsafePointer <UInt32> (pointer)[start / 32])
    }
    else if length == 16 && start % 16 == 0 {
        return UIntMax(UnsafePointer <UInt16> (pointer)[start / 16])
    }
    else if length == 8 && start % 8 == 0 {
        return UIntMax(UnsafePointer <UInt8> (pointer)[start / 8])
    }
    else {
        // Slow(er) path. Range is not aligned.
        let pointer = UnsafePointer <UIntMax> (pointer)
        let wordSize = sizeof(UIntMax) * 8

        let end = start + length

        if start / wordSize == (end - 1) / wordSize {
            // Bit range does not cross two words
            let offset = start / wordSize
            let result = bitRange(pointer[offset].bigEndian, start: start % wordSize, length: length, flipped: true)
            return result
        }
        else {
            // Bit range spans two words, get bit ranges for both words and then combine them.
            let offset = start / wordSize
            let offsettedStart = start % wordSize
            let msw = bitRange(pointer[offset].bigEndian, range: offsettedStart ..< wordSize, flipped: true)
            let bits = (end - offset * wordSize) % wordSize
            let lsw = bitRange(pointer[offset + 1].bigEndian, range: 0 ..< bits, flipped: true)
            return msw << UIntMax(bits) | lsw
        }
    }
}

public func bitRange(buffer: UnsafeBufferPointer <Void>, # range: Range <Int>) -> UIntMax {
    return bitRange(buffer, start: range.startIndex, length: range.endIndex - range.startIndex)
}

// MARK: -

public func bitSet <T: UnsignedIntegerType> (value: T, # start: Int, # length: Int, flipped: Bool = false, # newValue: T) -> T {
    assert(start + length <= sizeof(T) * 8)
    let mask: T = onesMask(start: start, length: length, flipped: flipped)
    let shift = UIntMax(flipped == false ? start: (sizeof(T) * 8 - start - length))
    let shiftedNewValue = newValue.toUIntMax() << UIntMax(shift)
    let result = (value.toUIntMax() & ~mask.toUIntMax()) | (shiftedNewValue & mask.toUIntMax())
    return T(result)
}

public func bitSet <T: UnsignedIntegerType> (value: T, # range: Range <Int>, flipped: Bool = false, # newValue: T) -> T {
    return bitSet(value, start: range.startIndex, length: range.endIndex - range.startIndex, flipped: flipped, newValue: newValue)
}

// MARK: -

public func bitSet(buffer: UnsafeMutableBufferPointer <Void>, # start: Int, # length: Int, # newValue: UIntMax) {
    let pointer = buffer.baseAddress

    // Fast path; we want whole integers and the range is aligned to integer size.
    if length == 64 && start % 64 == 0 {
        UnsafeMutablePointer <UInt64> (pointer)[start / 64] = newValue
    }
    else if length == 32 && start % 32 == 0 {
        UnsafeMutablePointer <UInt32> (pointer)[start / 32] = UInt32(newValue)
    }
    else if length == 16 && start % 16 == 0 {
        UnsafeMutablePointer <UInt16> (pointer)[start / 16] = UInt16(newValue)
    }
    else if length == 8 && start % 8 == 0 {
        UnsafeMutablePointer <UInt8> (pointer)[start / 8] = UInt8(newValue)
    }
    else {
        // Slow(er) path. Range is not aligned.
        let pointer = UnsafeMutablePointer <UIntMax> (pointer)
        let wordSize = sizeof(UIntMax) * 8

        let end = start + length

        if start / wordSize == (end - 1) / wordSize {
            // Bit range does not cross two words

            let offset = start / wordSize
            let value = pointer[offset].bigEndian
            let result = UIntMax(bigEndian: bitSet(value, start: start % wordSize, length: length, flipped: true, newValue: newValue))
            pointer[offset] = result
        }
        else {
            // Bit range spans two words, get bit ranges for both words and then combine them.
            unimplementedFailure()
        }
    }
}

public func bitSet(buffer: UnsafeMutableBufferPointer <Void>, range: Range <Int>, newValue: UIntMax) {
    bitSet(buffer, start: range.startIndex, length: range.endIndex - range.startIndex, newValue: newValue)
}

// MARK: -

func onesMask <T: UnsignedIntegerType> (# start: Int, # length: Int, flipped: Bool = false) -> T {
    let size = UIntMax(sizeof(T) * 8)
    let start = UIntMax(start)
    let length = UIntMax(length)
    let shift = flipped == false ? start: (size - start - length)
    let mask = ((1 << length) - 1) << shift
    return T(mask)
}

