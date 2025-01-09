//
//  SwiftFD_SET.swift
//

#if os(Linux)
    import Glibc

    @inline(__always)
    func SwiftFD_SET(_ fd: Int32, _ set: inout fd_set)
    {
        let index = Int(fd >> 6) // fd / 64
        let mask: __fd_mask = 1 << (fd & 63)
        withUnsafeMutablePointer(to: &set.__fds_bits)
        { ptr in
            ptr.withMemoryRebound(to: __fd_mask.self, capacity: 16)
            { arrPtr in
                arrPtr[index] |= mask
            }
        }
    }

#else
    import Darwin

    @inline(__always)
    func SwiftFD_SET(_ fd: Int32, _ set: inout fd_set)
    {
        __darwin_fd_set(fd, &set)
    }
#endif
