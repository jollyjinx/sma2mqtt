//
//  RandomNumber.swift
//

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

// Generate a random 16-bit number
func generateRandomNumber() -> UInt16
{
    #if os(Linux)
        let randomNumber = UInt16(random() % (Int(UInt16.max) + 1))
    #else
        let randomNumber = UInt16(arc4random_uniform(UInt32(UInt16.max) + 1))
    #endif
    return randomNumber
}
