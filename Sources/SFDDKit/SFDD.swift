/// A SFDD Node.
///
/// Yet another Decision Diagrams (SFDDs) are structures capable of representing large families of
/// sets, and performing various operations on them quite efficiently. They take advantage of the
/// similarities between the members of a family to compact their representation in a graph-like
/// structure that can be manipulated with homomorphisms.
///
/// Formal Definition
/// =================
///
/// Let T be a set of terms. The set of SFDDs Y is inductively defined by:
///
/// * ⊥ ∈ Y is the rejecting terminal
/// * ⊤ ∈ Y is the accepting terminal
/// ⟨t, τ, σ⟩ ∈ Y if and only if t ∈ T ∧ τ,σ ∈ Y
///
/// A SFDD is canonical if for all the nodes of the form y = ⟨t, τ, σ⟩ it contains, τ and σ
/// represent greater terms, are are terminal nodes. More formally, let < ∈ T × T be a total
/// ordering on T, a SFDD y ∈ Y is canonical if and only if:
///
/// * y ∈ {⊥, ⊤}
/// * y = ⟨t, τ, σ⟩ and:
///   + τ = ⟨t', τ', σ'⟩ -> t < t'
///   + σ = ⟨t", τ", σ"⟩ -> t < t"
///   + τ and σ are canonical
///
/// Usage
/// =====
///
/// SFDDs should not be created directly. Instead, use `Factory.make` or `Factory.makeNode`.
/// The reason is that SFDD factories maintain a unique table of all nodes they created, so as to
/// enable memoization on SFDD operations (e.g. union).
///
///     let factory = Factory<Int>()
///     let family = factory.make([1, 2], [1])
///     print(family)
///     // Prints "{{1, 2}, {1}}"
///
/// Adding and Removing Elements
/// ----------------------------
///
/// SFDDs are immutable, so you cannot add or remove elements from them. Instead, you should create
/// new ones as the result of some set operation or homomorphism. Suppose you need to store the
/// set {1, 3} in the existing family {{1, 2}, {1}}.
///
///     let factory = Factory<Int>()
///     var family = factory.make([1, 2], [1])
///     family = family.union([[1, 3]])
///
/// SFDDs support all basic set operations, i.e. union, intersection, symmetric difference and
/// subtraction.
///
/// - Note: SFDDs have to remain immutable, so that they can be stored them in a unique table. As a
///   result, they can't conform to Swift's `SetAlgebra` protocol.
///
/// Querying the Elements
/// ---------------------
///
/// SFDDs implement a `contains` method, as well as a `count` and `isEmpty` property, in the usual
/// fashion of Swift's collections.
///
///     let factory = Factory<Int>()
///     let family = factory.make([1, 2], [1])
///     print(family.count)
///     // Prints "2"
public final class SFDD<Key>: Hashable where Key: Comparable & Hashable {

    public let key : Key!
    public let take: SFDD!
    public let skip: SFDD!

    public unowned let factory: Factory<Key>

    public let count: Int

    public var isZero    : Bool { return self === self.factory.zero }
    public var isOne     : Bool { return self === self.factory.one }
    public var isTerminal: Bool { return self.isZero || self.isOne }
    public var isEmpty   : Bool { return self.isZero }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(take)
        hasher.combine(skip)
        hasher.combine(count)
    }

    /// Returns `true` if these SFDDs contain the same elements.
    public static func ==(lhs: SFDD, rhs: SFDD) -> Bool {
        return lhs === rhs
    }

    /// Returns `true` if the SFDD contains the given element.
    public func contains(_ element: Set<Key>) -> Bool {
        if element.count == 0 {
            return self.skipMost.isOne
        }

        var node = self
        var keys = element.sorted()

        while !node.isTerminal && !keys.isEmpty {
            let key = keys.first!
            if key > node.key {
                node = node.skip
            } else if key == node.key {
                node = node.take
                keys.removeFirst()
            } else {
                node = node.skip
            }
        }

        return keys.isEmpty && node.skipMost.isOne
    }

    /// Returns the union of this SFDD with another one.
    public func union(_ other: SFDD) -> SFDD {
        if self.isZero || (self === other) {
            return other
        } else if other.isZero {
            return self
        }

        let cacheKey: CacheKey = .set([self, other])
        if let result = self.factory.unionCache[cacheKey] {
            return result
        }
        let result: SFDD

        if self.isOne {
            result = self.factory.makeNode(
                key : other.key,
                take: other.take,
                skip: other.skip.union(self))
        } else if other.isOne {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.union(other))
        } else if other.key > self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.union(other))
        } else if other.key == self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take.union(other.take),
                skip: self.skip.union(other.skip))
        } else if other.key < self.key {
            result = self.factory.makeNode(
                key : other.key,
                take: other.take,
                skip: other.skip.union(self))
        } else {
            fatalError()
        }

        self.factory.unionCache[cacheKey] = result
        return result
    }

    /// Returns the union of this SFDD with multiple other ones.
    public func union<S>(_ others: S) -> SFDD where S: Sequence, S.Element == SFDD {
        var operands = Set(others.filter({ !$0.isZero }))

        if operands.isEmpty {
            return self
        } else if self.isZero {
            return operands.first!.union(operands.dropFirst())
        }

        operands.formUnion([self])
        if operands.count == 1 {
            return operands.first!
        }

        let cacheKey: CacheKey = .set(operands)
        if let result = self.factory.unionCache[cacheKey] {
            return result
        }
        let result: SFDD

        var results = operands.remove(self.factory.one).map({ [$0] }) ?? []
        let groups  = Dictionary(grouping: operands, by: { $0.key })
        for (key, roots) in groups {
            if roots.count <= 1 {
                results.append(roots[0])
            } else {
                let takes = roots.map({ $0.take! })
                let skips = roots.map({ $0.skip! })
                results.append(self.factory.makeNode(
                    key : key!,
                    take: takes.first!.union(takes.dropFirst()),
                    skip: skips.first!.union(skips.dropFirst())))
            }
        }

        let sorted = results.sorted(by: { lhs, rhs in
            lhs.isTerminal || rhs.isTerminal || (lhs.key < rhs.key)
        })
        result = sorted.dropFirst().reduce(sorted[0], { lhs, rhs in
            assert(rhs.isOne || (lhs.key < rhs.key))
            return self.factory.makeNode(
                key : lhs.key,
                take: lhs.take,
                skip: lhs.skip.union(rhs))
        })

        self.factory.unionCache[cacheKey] = result
        return result
    }

    /// Returns the union of this SFDD with another family of sets.
    public func union<S>(_ other: S) -> SFDD
        where S: Sequence, S.Element: Sequence, S.Element.Element == Key
    {
        return self.union(self.factory.make(other))
    }


    /// Returns the intersection of this SFDD with another one.
    public func intersection(_ other: SFDD) -> SFDD {
        if self.isZero || (self === other) {
            return self
        } else if other.isZero {
            return other
        }

        let cacheKey: CacheKey = .set([self, other])
        if let result = self.factory.intersectionCache[cacheKey] {
            return result
        }
        let result: SFDD

        if self.isOne {
            result = other.skipMost
        } else if other.isOne {
            result = self.skipMost
        } else if other.key > self.key {
            result = self.skip.intersection(other)
        } else if other.key == self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take.intersection(other.take),
                skip: self.skip.intersection(other.skip))
        } else if other.key < self.key {
            result = self.intersection(other.skip)
        } else {
            fatalError()
        }

        self.factory.intersectionCache[cacheKey] = result
        return result
    }

    /// Returns the intersection of this SFDD with another family of sets.
    public func intersection<S>(_ other: S) -> SFDD
        where S: Sequence, S.Element: Sequence, S.Element.Element == Key
    {
        return self.intersection(self.factory.make(other))
    }

    /// Returns the symmetric difference between this SFDD and another one.
    public func symmetricDifference(_ other: SFDD) -> SFDD {
        if self.isZero {
            return other
        } else if other.isZero {
            return self
        } else if (self === other) {
            return self.factory.zero
        }

        let cacheKey: CacheKey = .set([self, other])
        if let result = self.factory.symmetricDifferenceCache[cacheKey] {
            return result
        }
        let result: SFDD

        if self.isOne {
            result = self.factory.makeNode(
                key : other.key,
                take: other.take,
                skip: self.symmetricDifference(other.skip))
        } else if other.isOne {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.symmetricDifference(other))
        } else if other.key > self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.symmetricDifference(other))
        } else if other.key == self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take.symmetricDifference(other.take),
                skip: self.skip.symmetricDifference(other.skip))
        } else if other.key < self.key {
            result = self.factory.makeNode(
                key : other.key,
                take: other.take,
                skip: self.symmetricDifference(other.skip))
        } else {
            fatalError()
        }

        self.factory.symmetricDifferenceCache[cacheKey] = result
        return result
    }

    /// Returns the symmetric difference between this SFDD and another family of sets.
    public func symmetricDifference<S>(_ other: S) -> SFDD
        where S: Sequence, S.Element: Sequence, S.Element.Element == Key
    {
        return self.symmetricDifference(self.factory.make(other))
    }

    /// Returns the result of subtracting another SFDD to this one.
    public func subtracting(_ other: SFDD) -> SFDD {
        if self.isZero || other.isZero {
            return self
        } else if (self === other) {
            return self.factory.zero
        }

        let cacheKey: CacheKey = .list([self, other])
        if let result = self.factory.subtractionCache[cacheKey] {
            return result
        }
        let result: SFDD

        if self.isOne {
            result = other.skipMost.isZero
                ? self
                : self.factory.zero
        } else if other.isOne {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.subtracting(other))
        } else if other.key > self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take,
                skip: self.skip.subtracting(other))
        } else if other.key == self.key {
            result = self.factory.makeNode(
                key : self.key,
                take: self.take.subtracting(other.take),
                skip: self.skip.subtracting(other.skip))
        } else if other.key < self.key {
            result = self.subtracting(other.skip)
        } else {
            fatalError()
        }

        self.factory.subtractionCache[cacheKey] = result
        return result
    }

    /// Returns the result of subtracting another family of sets to this SFDD.
    public func subtracting<S>(_ other: S) -> SFDD
        where S: Sequence, S.Element: Sequence, S.Element.Element == Key
    {
        return self.subtracting(self.factory.make(other))
    }

    init(key: Key, take: SFDD, skip: SFDD, factory: Factory<Key>) {
        self.key     = key
        self.take    = take
        self.skip    = skip
        self.factory = factory
        self.count   = self.take.count + self.skip.count
    }

    init(factory: Factory<Key>, count: Int) {
        self.key     = nil
        self.take    = nil
        self.skip   = nil
        self.factory = factory
        self.count   = count
    }

    static func areEqual(_ lhs: SFDD, _ rhs: SFDD) -> Bool {
        return (lhs.key   == rhs.key)
            && (lhs.count == rhs.count)
            && (lhs.take  == rhs.take)
            && (lhs.skip  == rhs.skip)
    }

    private var skipMost: SFDD {
        var result = self
        while !result.isTerminal {
            result = result.skip
        }
        return result
    }

}

extension SFDD: Sequence {

    public func makeIterator() -> AnyIterator<Set<Key>> {
        // Implementation note: The iteration process sees the DD as a tree, and explores all his
        // nodes with a in-order traversal. During this traversal, we store all the keys of the
        // "take" parents, so that we can produce an item whenever we reach the one terminal.

        var stack        : [SFDD] = []
        var node         : SFDD!  = self
        var partialResult: [Key] = []

        return AnyIterator {
            guard node != nil else { return nil }

            while !node.isZero {
                if node.isOne {
                    let result = Set(partialResult)
                    node = stack.popLast()
                    if node != nil {
                        partialResult = partialResult.filter({ $0 < node.key })
                        node = node.skip
                    }

                    return result
                } else if !node.skip.isZero {
                    stack.append(node)
                }
                partialResult.append(node.key)
                node = node.take
            }

            return nil
        }
    }

}

extension SFDD: CustomStringConvertible {

    public var description: String {
        let contentDescription = self
            .map({ element in
                "{" + element.map({ String(describing: $0) }).joined(separator: ", ") + "}"
            })
            .joined(separator: ", ")
        return "{\(contentDescription)}"
    }

}

extension SFDD: CustomDebugStringConvertible {

    public var debugDescription: String {
        return self.makeDebugDescription(indent: 0).joined(separator: "\n")
    }

    private func makeDebugDescription(indent: Int) -> [String] {
        if self.isZero {
            return ["⊥"]
        } else if self.isOne {
            return ["⊤"]
        }

        let prefix = String(repeating: " ", count: indent)
        var result = ["\(self.key!) -> ("]

        let takeDescription = self.take.makeDebugDescription(indent: indent + 2)
        result += [prefix + "  take: " + takeDescription[0]]
        result += takeDescription.dropFirst()

        let skipDescription = self.skip.makeDebugDescription(indent: indent + 2)
        result += [prefix + "  skip: " + skipDescription[0]]
        result += skipDescription.dropFirst()

        result += [prefix + ")"]
        return result
    }

}