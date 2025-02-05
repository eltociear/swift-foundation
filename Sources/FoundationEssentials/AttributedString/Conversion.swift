//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


#if FOUNDATION_FRAMEWORK
import Darwin
@_implementationOnly import ReflectionInternal
@_implementationOnly import os
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
#endif

extension String {
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public init(_ characters: Slice<AttributedString.CharacterView>) {
        self.init(characters._characters)
    }

    #if true // FIXME: Make this public.
    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    internal init(_characters: AttributedString.CharacterView) {
        self.init(_characters._characters)
    }
    #else
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    @_alwaysEmitIntoClient
    public init(_ characters: AttributedString.CharacterView) {
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            self.init(_characters: characters)
            return
        }
        // Forward to the slice overload above, which somehow did end up shipping in
        // the original AttributedString release.
        self.init(characters[...])
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal init(_characters: AttributedString.CharacterView) {
        self.init(_characters._characters)
    }
    #endif
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol ObjectiveCConvertibleAttributedStringKey : AttributedStringKey {
    associatedtype ObjectiveCValue : NSObject

    static func objectiveCValue(for value: Value) throws -> ObjectiveCValue
    static func value(for object: ObjectiveCValue) throws -> Value
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension ObjectiveCConvertibleAttributedStringKey where Value : RawRepresentable, Value.RawValue == Int, ObjectiveCValue == NSNumber {
    static func objectiveCValue(for value: Value) throws -> ObjectiveCValue {
        return NSNumber(value: value.rawValue)
    }
    static func value(for object: ObjectiveCValue) throws -> Value {
        if let val = Value(rawValue: object.intValue) {
            return val
        }
        throw CocoaError(.coderInvalidValue)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension ObjectiveCConvertibleAttributedStringKey where Value : RawRepresentable, Value.RawValue == String, ObjectiveCValue == NSString {
    static func objectiveCValue(for value: Value) throws -> ObjectiveCValue {
        return value.rawValue as NSString
    }
    static func value(for object: ObjectiveCValue) throws -> Value {
        if let val = Value(rawValue: object as String) {
            return val
        }
        throw CocoaError(.coderInvalidValue)
    }
}

internal struct _AttributeConversionOptions : OptionSet {
    let rawValue: Int
    
    // If an attribute's value(for: ObjectieCValue) or objectiveCValue(for: Value) function throws, ignore the error and drop the attribute
    static let dropThrowingAttributes = Self(rawValue: 1 << 0)
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension AttributeContainer {
    init(_ dictionary: [NSAttributedString.Key : Any]) {
        var attributeKeyTypes = _loadDefaultAttributes()
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(dictionary, including: AttributeScopes.FoundationAttributes.self, attributeKeyTypes: &attributeKeyTypes, options: .dropThrowingAttributes)
    }
    
    
    init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key : Any], including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(dictionary, including: S.self)
    }
    
    init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key : Any], including scope: S.Type) throws {
        var attributeKeyTypes = [String : any AttributedStringKey.Type]()
        try self.init(dictionary, including: scope, attributeKeyTypes: &attributeKeyTypes)
    }
    
    fileprivate init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key : Any], including scope: S.Type, attributeKeyTypes: inout [String : any AttributedStringKey.Type], options: _AttributeConversionOptions = []) throws {
        storage = .init()
        for (key, value) in dictionary {
            if let type = attributeKeyTypes[key.rawValue] ?? S.attributeKeyType(matching: key.rawValue) {
                attributeKeyTypes[key.rawValue] = type
                func project<K: AttributedStringKey>(_: K.Type) throws {
                    storage[K.self] = try K._convertFromObjectiveCValue(value as AnyObject)
                }
                do {
                    try project(type)
                } catch let conversionError {
                    if !options.contains(.dropThrowingAttributes) {
                        throw conversionError
                    }
                }
            } // else, attribute is not in provided scope, so drop it
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    init(_ container: AttributeContainer) {
        var attributeKeyTypes = _loadDefaultAttributes()
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(container, including: AttributeScopes.FoundationAttributes.self, attributeKeyTypes: &attributeKeyTypes, options: .dropThrowingAttributes)
    }
    
    init<S: AttributeScope>(_ container: AttributeContainer, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(container, including: S.self)
    }
    
    init<S: AttributeScope>(_ container: AttributeContainer, including scope: S.Type) throws {
        var attributeKeyTypes = [String : any AttributedStringKey.Type]()
        try self.init(container, including: scope, attributeKeyTypes: &attributeKeyTypes)
    }
    
    // These includingOnly SPI initializers were provided originally when conversion boxed attributes outside of the given scope as an AnyObject
    // After rdar://80201634, these SPI initializers have the same behavior as the API initializers
    @_spi(AttributedString)
    init<S: AttributeScope>(_ container: AttributeContainer, includingOnly scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(container, including: S.self)
    }
    
    @_spi(AttributedString)
    init<S: AttributeScope>(_ container: AttributeContainer, includingOnly scope: S.Type) throws {
        try self.init(container, including: S.self)
    }
    
    fileprivate init<S: AttributeScope>(_ container: AttributeContainer, including scope: S.Type, attributeKeyTypes: inout [String : any AttributedStringKey.Type], options: _AttributeConversionOptions = []) throws {
        self.init()
        for key in container.storage.keys {
            if let type = attributeKeyTypes[key] ?? S.attributeKeyType(matching: key) {
                attributeKeyTypes[key] = type
                func project<K: AttributedStringKey>(_: K.Type) throws {
                    self[NSAttributedString.Key(rawValue: key)] = try K._convertToObjectiveCValue(container.storage[K.self]!)
                }
                do {
                    try project(type)
                } catch let conversionError {
                    if !options.contains(.dropThrowingAttributes) {
                        throw conversionError
                    }
                }
            }
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension NSAttributedString {
    convenience init(_ attrStr: AttributedString) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(attrStr, scope: AttributeScopes.FoundationAttributes.self, otherAttributeTypes: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }
    
    convenience init<S: AttributeScope>(_ attrStr: AttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(attrStr, scope: S.self)
    }
    
    convenience init<S: AttributeScope>(_ attrStr: AttributedString, including scope: S.Type) throws {
        try self.init(attrStr, scope: scope)
    }
    
    @_spi(AttributedString)
    convenience init<S: AttributeScope>(_ attrStr: AttributedString, includingOnly scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(attrStr, scope: S.self)
    }
    
    @_spi(AttributedString)
    convenience init<S: AttributeScope>(_ attrStr: AttributedString, includingOnly scope: S.Type) throws {
        try self.init(attrStr, scope: scope)
    }
    
    internal convenience init<S: AttributeScope>(
        _ attrStr: AttributedString,
        scope: S.Type,
        otherAttributeTypes: [String : any AttributedStringKey.Type] = [:],
        options: _AttributeConversionOptions = []
    ) throws {
        // FIXME: Consider making an NSString subclass backed by a BigString
        let result = NSMutableAttributedString(string: String(attrStr._guts.string))
        var attributeKeyTypes: [String : any AttributedStringKey.Type] = otherAttributeTypes
        // Iterate through each run of the source
        var nsStartIndex = 0
        var stringStart = attrStr._guts.string.startIndex
        for run in attrStr._guts.runs {
            let stringEnd = attrStr._guts.string.utf8.index(stringStart, offsetBy: run.length)
            let utf16Length = attrStr._guts.string.utf16.distance(from: stringStart, to: stringEnd)
            let range = NSRange(location: nsStartIndex, length: utf16Length)
            let attributes = try Dictionary(AttributeContainer(run.attributes), including: scope, attributeKeyTypes: &attributeKeyTypes, options: options)
            result.setAttributes(attributes, range: range)
            nsStartIndex += utf16Length
            stringStart = stringEnd
        }
        self.init(attributedString: result)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension AttributedString {
    init(_ nsStr: NSAttributedString) {
        // Passing .dropThrowingAttributes causes attributes that throw during conversion to be dropped, so it is safe to do try! here
        try! self.init(nsStr, scope: AttributeScopes.FoundationAttributes.self, otherAttributeTypes: _loadDefaultAttributes(), options: .dropThrowingAttributes)
    }
    
    init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: KeyPath<AttributeScopes, S.Type>) throws {
        try self.init(nsStr, scope: S.self)
    }
    
    init<S: AttributeScope>(_ nsStr: NSAttributedString, including scope: S.Type) throws {
        try self.init(nsStr, scope: S.self)
    }
    
    private init<S: AttributeScope>(_ nsStr: NSAttributedString, scope: S.Type, otherAttributeTypes: [String : any AttributedStringKey.Type] = [:], options: _AttributeConversionOptions = []) throws {
        var string = nsStr.string
        // Eagerly bridge to a native string since AttributedString will do this anyways and this guarantees string's contents are well-formed (no unpaired surrogate characters)
        string.makeContiguousUTF8()
        var runs: [_InternalRun] = []
        var attributeKeyTypes: [String : any AttributedStringKey.Type] = otherAttributeTypes
        var conversionError: Error?
        var endOfLastRange = string.utf16.startIndex
        var hasConstrainedAttributes = false
        // Enumerated ranges are guaranteed to be contiguous and have non-zero length
        nsStr.enumerateAttributes(in: NSMakeRange(0, nsStr.length), options: []) { (nsAttrs, range, stop) in
            let container: AttributeContainer
            do {
                container = try AttributeContainer(nsAttrs, including: scope, attributeKeyTypes: &attributeKeyTypes, options: options)
            } catch {
                conversionError = error
                stop.pointee = true
                return
            }
            
            var startOfCurrentRun = endOfLastRange
            var endOfCurrentRun = string.utf16.index(startOfCurrentRun, offsetBy: range.length)
            endOfLastRange = endOfCurrentRun
            
            // If the run ends in the middle of a surrogate pair, extend it to the full range of the pair
            if UTF16.isLeadSurrogate(string.utf16[string.utf16.index(before: endOfCurrentRun)]) {
                endOfCurrentRun = string.utf16.index(after: endOfCurrentRun)
            }
            
            // If the run begins in the middle of a surrogate pair, compress it forward to exclude the initial low character
            // Note: this can result in a zero-length run which is guarded against below
            if UTF16.isTrailSurrogate(string.utf16[startOfCurrentRun]) {
                startOfCurrentRun = string.utf16.index(after: startOfCurrentRun)
            }
            
            let runLength = string.utf8.distance(from: startOfCurrentRun, to: endOfCurrentRun)
            guard runLength > 0 else { return }
            
            let attrStorage = container.storage
            if let previous = runs.last, previous.attributes == attrStorage {
                runs[runs.endIndex - 1].length += runLength
            } else {
                runs.append(_InternalRun(length: runLength, attributes: attrStorage))
                if !hasConstrainedAttributes {
                    hasConstrainedAttributes = attrStorage.hasConstrainedAttributes
                }
            }
        }
        if let error = conversionError {
            throw error
        }
        self = AttributedString(Guts(string: string, runs: runs))
        if hasConstrainedAttributes {
            self._guts.adjustConstrainedAttributesForUntrustedRuns()
        }
    }
}

internal func _loadDefaultAttributes() -> [String : any AttributedStringKey.Type] {
    #if !targetEnvironment(macCatalyst)
        // AppKit scope on macOS
        let macOSSymbol = ("$s10Foundation15AttributeScopesO6AppKitE0dE10AttributesVN", "/usr/lib/swift/libswiftAppKit.dylib")
    #else
        // UIKit scope on macOS
        let macOSSymbol = ("$s10Foundation15AttributeScopesO5UIKitE0D10AttributesVN", "/System/iOSSupport/System/Library/Frameworks/UIKit.framework/UIKit")
    #endif

    let loadedScopes = [
        macOSSymbol,
        // UIKit scope on non-macOS
        ("$s10Foundation15AttributeScopesO5UIKitE0D10AttributesVN", "/System/Library/Frameworks/UIKit.framework/UIKit"),
        // SwiftUI scope
        ("$s10Foundation15AttributeScopesO7SwiftUIE0D12UIAttributesVN", "/System/Library/Frameworks/SwiftUI.framework/SwiftUI"),
        // Accessibility scope
        ("$s10Foundation15AttributeScopesO13AccessibilityE0D10AttributesVN", "/System/Library/Frameworks/Accessibility.framework/Accessibility")
    ].compactMap {
        _loadScopeAttributes(forSymbol: $0.0, from: $0.1)
    }

    return loadedScopes.reduce([:]) { result, item in
        result.merging(item) { current, new in new }
    }
}

fileprivate struct LoadedScopeCache : Sendable {
    var cache : [String : [String : any AttributedStringKey.Type]]
}
fileprivate let _loadedScopeCacheLock = OSAllocatedUnfairLock(initialState: LoadedScopeCache(cache: .init()))

fileprivate func _loadScopeAttributes(forSymbol symbol: String, from path: String) -> [String : any AttributedStringKey.Type]? {
    return _loadedScopeCacheLock.withLock { cache in
        if let cachedResult = cache.cache[symbol] {
            return cachedResult
        }
        guard let handle = dlopen(path, RTLD_NOLOAD) else {
            return nil
        }
        guard let symbolPointer = dlsym(handle, symbol) else {
            return nil
        }
        guard let scopeType = unsafeBitCast(symbolPointer, to: Any.Type.self) as? any AttributeScope.Type else {
            return nil
        }
        let attributeTypes =  _loadAttributeTypes(from: scopeType)
        cache.cache[symbol] = attributeTypes
        return attributeTypes
    }
}

fileprivate func _loadAttributeTypes<S: AttributeScope>(from scope: S.Type) -> [String : any AttributedStringKey.Type] {
    var result = [String : any AttributedStringKey.Type]()
    for field in Type(scope).fields {
        switch field.type.swiftType {
        case let attribute as any AttributedStringKey.Type:
            result[attribute.name] = attribute
        case let scope as any AttributeScope.Type:
            result.merge(_loadAttributeTypes(from: scope), uniquingKeysWith: { current, new in new })
        default: break
        }
    }
    return result
}

#endif // FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension String.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to e.g. using UTF-8 offsets.
    public init?<S: StringProtocol>(_ sourcePosition: AttributedString.Index, within target: S) {
        let utf8Offset = sourcePosition._value.utf8Offset
        let isTrailingSurrogate = sourcePosition._value._isUTF16TrailingSurrogate
        let i = String.Index(_utf8Offset: utf8Offset, utf16TrailingSurrogate: isTrailingSurrogate)
        self.init(i, within: target)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to e.g. using UTF-8 offsets.
    public init?<S: AttributedStringProtocol>(_ sourcePosition: String.Index, within target: S) {
        guard
            let i = target.__guts.string.index(from: sourcePosition),
            i >= target.startIndex._value,
            i <= target.endIndex._value
        else {
            return nil
        }
        let j = target.__guts.string.index(roundingDown: i)
        guard j == i else { return nil }
        self.init(j)
    }
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension NSRange {
    public init<R: RangeExpression, S: AttributedStringProtocol>(
        _ region: R,
        in target: S
    ) where R.Bound == AttributedString.Index {
        let range = region.relative(to: target.characters)
        precondition(
            range.lowerBound >= target.startIndex && range.upperBound <= target.endIndex,
            "Range out of bounds")
        let str = target.__guts.string
        let utf16Base = str.utf16.distance(from: str.startIndex, to: target.startIndex._value)
        let utf16Start = str.utf16.distance(from: str.startIndex, to: range.lowerBound._value)
        let utf16Length = str.utf16.distance(
            from: range.lowerBound._value,
            to: range.upperBound._value)
        self.init(location: utf16Start - utf16Base, length: utf16Length)
    }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init?<S: StringProtocol>(_ markdownSourcePosition: AttributedString.MarkdownSourcePosition, in target: S) {
        let startOffsets: AttributedString.MarkdownSourcePosition.Offsets
        let endOffsets: AttributedString.MarkdownSourcePosition.Offsets
        if let start = markdownSourcePosition.startOffsets, let end = markdownSourcePosition.endOffsets {
            startOffsets = start
            endOffsets = end
        } else {
            guard let offsets = markdownSourcePosition.calculateOffsets(within: target) else {
                self.init(location: NSNotFound, length: NSNotFound)
                return
            }
            startOffsets = offsets.start
            endOffsets = offsets.end
        }
        
        // Since bounds are inclusive, we need to advance to the next UTF-16 scalar
        // If doing so will leave a hanging high surrogate value (i.e., the UTF-8 offset was within a code point), then don't advance
        var actualEndUTF16 = startOffsets.utf16
        if endOffsets.utf8 + 1 == endOffsets.utf8NextCodePoint {
            actualEndUTF16 += endOffsets.utf16CurrentCodePointLength
        }
        self.init(location: startOffsets.utf16, length: actualEndUTF16 - startOffsets.utf16)
    }
}

#endif // FOUNDATION_FRAMEWORK

extension AttributedString {
    /// A dummy collection type whose only purpose is to facilitate a `RangeExpression.relative(to:)`
    /// call that takes a range expression with string indices but needs to work on an
    /// attributed string.
    internal struct _IndexConverterFromString: Collection {
        typealias Index = String.Index
        typealias Element = Index
        
        let _string: BigString
        let _range: Range<BigString.Index>

        init(_ string: BigString, _ range: Range<BigString.Index>) {
            self._string = string
            self._range = range
        }

        subscript(position: String.Index) -> String.Index { position }

        var startIndex: String.Index { Index(_utf8Offset: _range.lowerBound.utf8Offset) }
        var endIndex: String.Index { Index(_utf8Offset: _range.upperBound.utf8Offset) }
        func index(after i: String.Index) -> Index {
            guard let j = _string.index(from: i) else {
                preconditionFailure("Index out of bounds")
            }
            let k = _string.index(after: j)
            return Index(_utf8Offset: k.utf8Offset)
        }
    }
}

extension BigString {
    func index(from stringIndex: String.Index) -> Index? {
        if stringIndex._canBeUTF8 {
            let utf8Offset = stringIndex._utf8Offset
            // Note: ideally we should also check that the result actually addresses a
            // trailing surrogate, when this flag is true.
            let utf16TrailingSurrogate = stringIndex._isUTF16TrailingSurrogate
            let j = BigString.Index(
                _utf8Offset: utf8Offset, utf16TrailingSurrogate: utf16TrailingSurrogate)
            guard j <= endIndex else { return nil }
            // Note: if utf16Delta > 0, ideally we should also check that the result
            // addresses a trailing surrogate.
            return j
        }
        let utf16Offset = stringIndex._abi_encodedOffset
        let utf8Delta = stringIndex._abi_transcodedOffset
        guard utf16Offset <= self.utf16.count else { return nil }
        let j = self.utf16.index(self.startIndex, offsetBy: utf16Offset)
        guard utf8Delta > 0 else { return j }
        // Note: if utf8Delta > 0, ideally we should also check that the result
        // addresses a scalar that actually does have that many continuation bytes.
        return self.utf8.index(j, offsetBy: utf8Delta)
    }

    func stringIndex(from index: Index) -> String.Index? {
        String.Index(
            _utf8Offset: index.utf8Offset,
            utf16TrailingSurrogate: index._isUTF16TrailingSurrogate)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == AttributedString.Index {
#if FOUNDATION_FRAMEWORK
    public init?<S: AttributedStringProtocol>(_ range: NSRange, in string: S) {
        // FIXME: This can return indices addressing trailing surrogates, which isn't a thing
        // FIXME: AttributedString is normally prepared to handle.
        // FIXME: Consider rounding everything down to the nearest scalar boundary.
        guard range.location != NSNotFound else { return nil }
        guard range.location >= 0, range.length >= 0 else { return nil }
        let endOffset = range.location + range.length
        let bstr = string.__guts.string
        guard endOffset <= bstr.utf16.count else { return nil }

        let start = bstr.utf16.index(bstr.startIndex, offsetBy: range.location)
        let end = bstr.utf16.index(start, offsetBy: range.length)

        guard start >= string.startIndex._value, end <= string.endIndex._value else { return nil }
        self.init(uncheckedBounds: (.init(start), .init(end)))
    }
#endif // FOUNDATION_FRAMEWORK

    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to using UTF-8 offsets.
    public init?<R: RangeExpression, S: AttributedStringProtocol>(
        _ region: R,
        in attributedString: S
    ) where R.Bound == String.Index {
        if let range = region as? Range<String.Index> {
            self.init(_range: range, in: attributedString)
            return
        }
        // This is a frustrating API to implement -- we need to convert String indices to
        // AttributedString indices, but the only way for us to access the actual indices is to
        // go through `RangeExpression.relative(to:)`, which requires a collection value with a
        // matching index type. So we need to construct a dummy collection type for just that.
        let dummy = AttributedString._IndexConverterFromString(
            attributedString.__guts.string,
            attributedString.startIndex._value ..< attributedString.endIndex._value)
        let range = region.relative(to: dummy)
        self.init(_range: range, in: attributedString)
    }

    // The FIXME above also applies to this internal initializer.
    internal init?(
        _range: Range<String.Index>,
        in attributedString: some AttributedStringProtocol
    ) {
        guard let lower = attributedString.__guts.string.index(from: _range.lowerBound),
              let upper = attributedString.__guts.string.index(from: _range.upperBound),
              lower >= attributedString.startIndex._value,
              upper <= attributedString.endIndex._value
        else {
            return nil
        }
        self.init(uncheckedBounds: (.init(lower), .init(upper)))
    }
}

extension AttributedString {
    /// A dummy collection type whose only purpose is to facilitate a `RangeExpression.relative(to:)`
    /// call that takes a range expression with attributed string indices but needs to work on a
    /// regular string.
    internal struct _IndexConverterFromAttributedString: Collection {
        typealias Index = AttributedString.Index
        typealias Element = Index
        
        let string: Substring
        init(_ string: Substring) { self.string = string }
        subscript(position: Index) -> Index { position }
        var startIndex: Index { Index(BigString.Index(_utf8Offset: string.startIndex._utf8Offset)) }
        var endIndex: Index { Index(BigString.Index(_utf8Offset: string.endIndex._utf8Offset)) }
        func index(after i: Index) -> Index {
            let j = String.Index(_utf8Offset: i._value.utf8Offset)
            let k = string.index(after: j)
            return Index(BigString.Index(_utf8Offset: k._utf8Offset))
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == String.Index {
    // FIXME: Converting indices between different collection types does not make sense.
    // FIXME: (Indices are meaningless without the collection value to which they belong,
    // FIXME: and this entry point is not given that.)
    // FIXME: This API ought to be deprecated, with clients migrating to using UTF-8 offsets.
    public init?<R: RangeExpression, S: StringProtocol>(
        _ region: R,
        in string: S
    ) where R.Bound == AttributedString.Index {
        if let range = region as? Range<AttributedString.Index> {
            self.init(_range: range, in: Substring(string))
            return
        }
        let str = Substring(string)
        let dummy = AttributedString._IndexConverterFromAttributedString(str)
        let range = region.relative(to: dummy)
        self.init(_range: range, in: str)
    }

    // The FIXME above also applies to this internal initializer.
    internal init?(
        _range: Range<AttributedString.Index>,
        in string: Substring
    ) {
        // Note: Attributed string indices are usually going to get implicitly round down to
        // (at least) the nearest scalar boundary, but NSRange conversions can still generate
        // indices addressing trailing surrogates, and we want to preserve those here.
        let start = String.Index(
            _utf8Offset: _range.lowerBound._value.utf8Offset,
            utf16TrailingSurrogate: _range.lowerBound._value._isUTF16TrailingSurrogate)
        let end = String.Index(
            _utf8Offset: _range.upperBound._value.utf8Offset,
            utf16TrailingSurrogate: _range.upperBound._value._isUTF16TrailingSurrogate)

        guard string.startIndex <= start, end <= string.endIndex else { return nil }
        self.init(uncheckedBounds: (start, end))
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Support AttributedString markdown in FoundationPreview
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init?<S: StringProtocol>(_ markdownSourcePosition: AttributedString.MarkdownSourcePosition, in target: S) {
        if let start = markdownSourcePosition.startOffsets, let end = markdownSourcePosition.endOffsets {
            self = target.utf8.index(target.startIndex, offsetBy: start.utf8) ..< target.utf8.index(target.startIndex, offsetBy: end.utf8 + 1)
        } else {
            guard let offsets = markdownSourcePosition.calculateOffsets(within: target) else {
                return nil
            }
            self = target.utf8.index(target.startIndex, offsetBy: offsets.start.utf8) ..< target.utf8.index(target.startIndex, offsetBy: offsets.end.utf8 + 1)
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

