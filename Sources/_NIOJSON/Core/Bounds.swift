import Foundation
import _JSONCore

private let lowercasedRadix16table: [UInt8] = [
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66,
]
private let uppercasedRadix16table: [UInt8] = [
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46,
]

extension UInt8 {
  fileprivate func decodeHex() -> UInt8? {
    if let num = lowercasedRadix16table.firstIndex(of: self) {
      return numericCast(num)
    } else if let num = uppercasedRadix16table.firstIndex(of: self) {
      return numericCast(num)
    } else {
      return nil
    }
  }
}

// MARK: - Span-based String Parsing

extension JSONToken.String {
  /// Makes a String from a Span.
  /// Assumes the length is checked against the bounds `self`
  public func makeString(from span: Span<UInt8>, unicode: Bool) -> String? {
    let startOffset = start.byteOffset

    if usesEscaping {
      // Process escaped string
      var buffer = [UInt8]()
      buffer.reserveCapacity(byteLength)

      var readerIndex = 0
      var unicodes = [UInt16]()

      func flushUnicodes() {
        if !unicodes.isEmpty {
          // Convert UTF-16 code units to a String, then append its UTF-8 bytes
          let character = String(decoding: unicodes, as: Unicode.UTF16.self)
          buffer.append(contentsOf: character.utf8)
          unicodes.removeAll(keepingCapacity: true)
        }
      }

      next: while readerIndex < byteLength {
        let byte = span[startOffset + readerIndex]

        if byte != .backslash || readerIndex + 1 >= byteLength {
          flushUnicodes()
          buffer.append(byte)
          readerIndex += 1
          continue next
        }

        readerIndex += 1

        if span[startOffset + readerIndex] == .u {
          readerIndex += 1
          guard readerIndex + 3 < byteLength else {
            return nil
          }
          guard
            let hex0 = span[startOffset + readerIndex].decodeHex(),
            let hex1 = span[startOffset + readerIndex + 1].decodeHex(),
            let hex2 = span[startOffset + readerIndex + 2].decodeHex(),
            let hex3 = span[startOffset + readerIndex + 3].decodeHex()
          else {
            return nil
          }

          var unicodeValue: UInt16 = 0
          unicodeValue &+= UInt16(hex0) &<< 12
          unicodeValue &+= UInt16(hex1) &<< 8
          unicodeValue &+= UInt16(hex2) &<< 4
          unicodeValue &+= UInt16(hex3)

          unicodes.append(unicodeValue)
          readerIndex += 4
          continue next
        }

        flushUnicodes()

        switch span[startOffset + readerIndex] {
        case .backslash, .solidus, .quote:
          buffer.append(span[startOffset + readerIndex])
          readerIndex += 1
        case .t:
          buffer.append(.tab)
          readerIndex += 1
        case .r:
          buffer.append(.carriageReturn)
          readerIndex += 1
        case .n:
          buffer.append(.newLine)
          readerIndex += 1
        case .f:
          buffer.append(.formFeed)
          readerIndex += 1
        case .b:
          buffer.append(.backspace)
          readerIndex += 1
        default:
          return nil
        }
      }

      flushUnicodes()
      return String(decoding: buffer, as: Unicode.UTF8.self)
    } else if #available(macOS 26.0, iOS 26.0, *) {
      // No escaping, use withUnsafeBufferPointer for efficient string creation
        do {
            let subSpan = span.extracting(startOffset ..< startOffset + byteLength)
            let utf8 = try UTF8Span(validating: subSpan)
            return String(copying: utf8)
        } catch {
            return nil
        }
    } else {
        return unsafe span.withUnsafeBytes { buffer in
          let slice = unsafe UnsafeRawBufferPointer(rebasing: buffer[startOffset..<(startOffset + byteLength)])
          return unsafe String(decoding: slice, as: Unicode.UTF8.self)
        }
    }
  }
}

// MARK: - Array-based String Parsing

extension JSONToken.String {
  /// Makes a String from an Array.
  /// Assumes the length is checked against the bounds `self`
  public func makeString(from bytes: [UInt8], unicode: Bool) -> String? {
    let startOffset = start.byteOffset

    if usesEscaping {
      // Process escaped string
      var buffer = [UInt8]()
      buffer.reserveCapacity(byteLength)

      var readerIndex = 0
      var unicodes = [UInt16]()

      func flushUnicodes() {
        if !unicodes.isEmpty {
          // Convert UTF-16 code units to a String, then append its UTF-8 bytes
          let character = String(decoding: unicodes, as: Unicode.UTF16.self)
          buffer.append(contentsOf: character.utf8)
          unicodes.removeAll(keepingCapacity: true)
        }
      }

      next: while readerIndex < byteLength {
        let byte = bytes[startOffset + readerIndex]

        if byte != .backslash || readerIndex + 1 >= byteLength {
          flushUnicodes()
          buffer.append(byte)
          readerIndex += 1
          continue next
        }

        readerIndex += 1

        if bytes[startOffset + readerIndex] == .u {
          readerIndex += 1
          guard readerIndex + 3 < byteLength else {
            return nil
          }
          guard
            let hex0 = bytes[startOffset + readerIndex].decodeHex(),
            let hex1 = bytes[startOffset + readerIndex + 1].decodeHex(),
            let hex2 = bytes[startOffset + readerIndex + 2].decodeHex(),
            let hex3 = bytes[startOffset + readerIndex + 3].decodeHex()
          else {
            return nil
          }

          var unicodeValue: UInt16 = 0
          unicodeValue &+= UInt16(hex0) &<< 12
          unicodeValue &+= UInt16(hex1) &<< 8
          unicodeValue &+= UInt16(hex2) &<< 4
          unicodeValue &+= UInt16(hex3)

          unicodes.append(unicodeValue)
          readerIndex += 4
          continue next
        }

        flushUnicodes()

        switch bytes[startOffset + readerIndex] {
        case .backslash, .solidus, .quote:
          buffer.append(bytes[startOffset + readerIndex])
          readerIndex += 1
        case .t:
          buffer.append(.tab)
          readerIndex += 1
        case .r:
          buffer.append(.carriageReturn)
          readerIndex += 1
        case .n:
          buffer.append(.newLine)
          readerIndex += 1
        case .f:
          buffer.append(.formFeed)
          readerIndex += 1
        case .b:
          buffer.append(.backspace)
          readerIndex += 1
        default:
          return nil
        }
      }

      flushUnicodes()
      return String(decoding: buffer, as: Unicode.UTF8.self)
    } else {
      // No escaping, use slice for efficient string creation
      let slice = bytes[startOffset..<(startOffset + byteLength)]
      return String(decoding: slice, as: Unicode.UTF8.self)
    }
  }
}

// MARK: - Span-based Number Parsing

extension JSONToken.Number {
  /// Parses a `Double` from a Span
  /// Assumes the length is checked against the bounds `self`
  internal func makeDouble(from span: Span<UInt8>) -> Double {
    let start = start.byteOffset
    return parseDouble(length: byteLength) { span[start &+ $0] }
  }

  internal func makeInt(from span: Span<UInt8>) -> Int? {
    var offset = start.byteOffset
    return span.makeInt(offset: &offset, length: Int(byteLength))
  }

  /// Parses a `Double` from an Array
  /// Assumes the length is checked against the bounds `self`
  internal func makeDouble(from bytes: [UInt8]) -> Double {
    let start = start.byteOffset
    return parseDouble(length: byteLength) { bytes[start &+ $0] }
  }

  internal func makeInt(from bytes: [UInt8]) -> Int? {
    var offset = start.byteOffset
    return bytes.makeInt(offset: &offset, length: Int(byteLength))
  }
}

public struct UTF8ParsingError: Error {}

// MARK: - Double Parsing

/// Powers of ten that are exactly representable as a `Double`
private let exactPowersOfTen: [Double] = [
  1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
  1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22,
]

/// Parses the number literal of `length` bytes that `byteAt` gives access to
@inline(__always)
private func parseDouble(length: Int, byteAt: (Int) -> UInt8) -> Double {
  var offset = 0
  var negative = false

  if length > 0, byteAt(0) == .minus || byteAt(0) == .plus {
    negative = byteAt(0) == .minus
    offset = 1
  }

  let digitsStart = offset
  var significand: UInt64 = 0
  var exponent = 0

  // Larger significands may not fit a `Double` exactly, so they don't need to be complete
  let maxSignificand: UInt64 = 1 << 53
  func append(_ digit: UInt8) {
    if significand <= maxSignificand {
      significand = significand &* 10 &+ UInt64(digit &- .zero)
    }
  }

  while offset < length, byteAt(offset).isDigit {
    append(byteAt(offset))
    offset &+= 1
  }

  if offset < length, byteAt(offset) == .fullStop {
    offset &+= 1

    while offset < length, byteAt(offset).isDigit {
      append(byteAt(offset))
      exponent &-= 1
      offset &+= 1
    }
  }

  let digitsEnd = offset

  if offset < length, byteAt(offset) == .e || byteAt(offset) == .E {
    offset &+= 1
    var explicitExponent = 0
    var exponentIsNegative = false

    if offset < length, byteAt(offset) == .minus || byteAt(offset) == .plus {
      exponentIsNegative = byteAt(offset) == .minus
      offset &+= 1
    }

    while offset < length, byteAt(offset).isDigit {
      // Anything this large is infinite or zero, whatever the digits are
      if explicitExponent < 1_000_000_000 {
        explicitExponent = explicitExponent &* 10 &+ Int(byteAt(offset) &- .zero)
      }
      offset &+= 1
    }

    exponent &+= exponentIsNegative ? 0 &- explicitExponent : explicitExponent
  }

  var result: Double
  if significand <= maxSignificand, exponent >= -22, exponent <= 22 {
    // One operation on two exact values is correctly rounded
    result = Double(significand)
    if exponent < 0 {
      result /= exactPowersOfTen[0 &- exponent]
    } else {
      result *= exactPowersOfTen[exponent]
    }
  } else {
    var literal = [UInt8]()
    literal.reserveCapacity(length &+ 12)
    for i in digitsStart..<digitsEnd where byteAt(i) != .fullStop {
      literal.append(byteAt(i))
    }
    literal.append(.e)
    literal.append(contentsOf: String(exponent).utf8)
    result = Double(String(decoding: literal, as: UTF8.self)) ?? 0
  }

  return negative ? -result : result
}

// MARK: - Array-based makeInt

extension Array where Element == UInt8 {
  func makeInt(offset: inout Int, length: Int) -> Int? {
    guard offset < count else { return nil }

    let negative = self[offset] == .minus
    if negative {
      // skip 1 byte for the minus
      offset = offset &+ 1
    }

    let end = Swift.min(offset &+ length, count)
    guard offset < end else { return nil }

    var number: Int = numericCast(self[offset] &- 0x30)
    offset = offset &+ 1

    while offset < end {
      let byte = self[offset]
      if byte < 0x30 || byte > 0x39 {
        return negative ? -number : number
      }

      number = (number &* 10) &+ numericCast(self[offset] &- 0x30)
      offset = offset &+ 1

      if number < 0 {
        return nil
      }
    }

    return negative ? -number : number
  }
}
