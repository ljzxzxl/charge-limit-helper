import Darwin
import Foundation

public enum UnixSocketError: Error, CustomStringConvertible {
    case pathTooLong(String)
    case socketFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case acceptFailed(errno: Int32)
    case connectFailed(errno: Int32)
    case readFailed(errno: Int32)
    case writeFailed(errno: Int32)
    case invalidUTF8

    public var description: String {
        switch self {
        case .pathTooLong(let path):
            return "Unix socket path is too long: \(path)"
        case .socketFailed(let code):
            return "socket() failed: \(String(cString: strerror(code)))"
        case .bindFailed(let code):
            return "bind() failed: \(String(cString: strerror(code)))"
        case .listenFailed(let code):
            return "listen() failed: \(String(cString: strerror(code)))"
        case .acceptFailed(let code):
            return "accept() failed: \(String(cString: strerror(code)))"
        case .connectFailed(let code):
            return "connect() failed: \(String(cString: strerror(code)))"
        case .readFailed(let code):
            return "read() failed: \(String(cString: strerror(code)))"
        case .writeFailed(let code):
            return "write() failed: \(String(cString: strerror(code)))"
        case .invalidUTF8:
            return "Response was not valid UTF-8"
        }
    }
}

public struct HelperClient {
    public let socketPath: String

    public init(socketPath: String = ChargeLimitPaths.socketPath) {
        self.socketPath = socketPath
    }

    public func send(_ request: HelperRequest) throws -> HelperResponse {
        let fd = try UnixSocket.openClient(path: socketPath)
        defer { close(fd) }

        var payload = try JSONCodec.encoder.encode(request)
        payload.append(0x0a)
        try UnixSocket.writeAll(fd: fd, data: payload)
        shutdown(fd, SHUT_WR)

        let responseData = try UnixSocket.readUntilEOF(fd: fd)
        return try JSONCodec.decoder.decode(HelperResponse.self, from: responseData)
    }

    public func status() throws -> HelperResponse {
        try send(HelperRequest(command: .status))
    }

    public func setBCLM(_ value: UInt8) throws -> HelperResponse {
        try send(HelperRequest(command: .setBCLM, value: value))
    }
}

public enum UnixSocket {
    public static func openServer(path: String, backlog: Int32 = 8) throws -> Int32 {
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw UnixSocketError.socketFailed(errno: errno)
        }

        do {
            var address = try makeAddress(path: path)
            let length = addressLength(path: path)
            let bindResult = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(fd, $0, length)
                }
            }
            guard bindResult == 0 else {
                throw UnixSocketError.bindFailed(errno: errno)
            }

            chmod(path, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP)
            if let admin = getgrnam("admin") {
                chown(path, 0, admin.pointee.gr_gid)
            }

            guard listen(fd, backlog) == 0 else {
                throw UnixSocketError.listenFailed(errno: errno)
            }
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    public static func openClient(path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw UnixSocketError.socketFailed(errno: errno)
        }

        do {
            var address = try makeAddress(path: path)
            let length = addressLength(path: path)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, length)
                }
            }
            guard result == 0 else {
                throw UnixSocketError.connectFailed(errno: errno)
            }
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    public static func acceptClient(serverFD: Int32) throws -> Int32 {
        while true {
            let client = accept(serverFD, nil, nil)
            if client >= 0 {
                return client
            }
            if errno == EINTR {
                continue
            }
            throw UnixSocketError.acceptFailed(errno: errno)
        }
    }

    public static func readLine(fd: Int32, limit: Int = 64 * 1024) throws -> Data {
        var data = Data()
        var byte = UInt8(0)

        while data.count < limit {
            let count = Darwin.read(fd, &byte, 1)
            if count == 1 {
                if byte == 0x0a {
                    break
                }
                data.append(byte)
            } else if count == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw UnixSocketError.readFailed(errno: errno)
            }
        }

        return data
    }

    public static func readUntilEOF(fd: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count == 0 {
                return data
            } else if errno == EINTR {
                continue
            } else {
                throw UnixSocketError.readFailed(errno: errno)
            }
        }
    }

    public static func writeAll(fd: Int32, data: Data) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return
            }

            var offset = 0
            while offset < data.count {
                let pointer = base.advanced(by: offset)
                let written = Darwin.write(fd, pointer, data.count - offset)
                if written > 0 {
                    offset += written
                } else if written < 0 && errno == EINTR {
                    continue
                } else {
                    throw UnixSocketError.writeFailed(errno: errno)
                }
            }
        }
    }

    private static func makeAddress(path: String) throws -> sockaddr_un {
        let maxPathLength = MemoryLayout.size(ofValue: sockaddr_un().sun_path)
        guard path.utf8.count < maxPathLength else {
            throw UnixSocketError.pathTooLong(path)
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            memset(buffer.baseAddress, 0, buffer.count)
            path.withCString { cString in
                buffer.baseAddress?.copyMemory(from: cString, byteCount: strlen(cString))
            }
        }

        return address
    }

    private static func addressLength(path: String) -> socklen_t {
        let offset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 0
        return socklen_t(offset + path.utf8.count + 1)
    }
}
