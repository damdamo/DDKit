public struct WeakSet<Element> where Element: Hashable & AnyObject {

  public init(minimumCapacity: Int) {
    self.content = Array(repeating: [], count: minimumCapacity)
  }

  public init() {
    self.init(minimumCapacity: 1024)
  }

  public init<S>(_ sequence: S) where S: Sequence, S.Element == Element {
    self.init()
    for element in sequence {
      self.insert(element)
    }
  }

  fileprivate var content: [[WeakSetElement<Element>]]
  public fileprivate(set) var overestimateCount: Int = 0

  public var isEmpty: Bool {
    return !self.content.contains(
      where: { bucket in bucket.contains(where: { $0.containee != nil }) })
  }

  public var capacity: Int {
    return self.content.count
  }

  @discardableResult
  public mutating func insert(_ newMember: Element)
    -> (inserted: Bool, memberAfterInsert: Element)
  {
    let h = abs(newMember.hashValue % self.capacity)
    let result: (inserted: Bool, memberAfterInsert: Element)

    if let containedIndex = self.content[h].index(where: { $0.containee == newMember }) {
      result = (false, self.content[h][containedIndex].containee!)
    } else {
      overestimateCount += 1
      self.content[h].append(WeakSetElement(containee: newMember))
      result = (true, newMember)
    }

    self.resize()
    return result
  }

  @discardableResult
  public mutating func insert(
    _ newMember: Element, withCustomEquality areEqual: (Element, Element) -> Bool)
    -> (inserted: Bool, memberAfterInsert: Element)
  {
    let h = abs(newMember.hashValue % self.capacity)
    let result: (inserted: Bool, memberAfterInsert: Element)

    if let containedIndex = self.content[h].index(where: {
      return $0.containee != nil
        ? areEqual($0.containee!, newMember)
        : false
    }) {
      result = (false, self.content[h][containedIndex].containee!)
    } else {
      overestimateCount += 1
      self.content[h].append(WeakSetElement(containee: newMember))
      result = (true, newMember)
    }

    self.resize()
    return result
  }

  @discardableResult
  public mutating func update(with newMember: Element) -> Element? {
    let h = abs(newMember.hashValue % self.capacity)
    let result: Element?

    if let containedIndex = self.content[h].index(where: { $0.containee == newMember }) {
      result = self.content[h][containedIndex].containee
      self.content[h][containedIndex] = WeakSetElement(containee: newMember)
    } else {
      overestimateCount += 1
      self.content[h].append(WeakSetElement(containee: newMember))
      result = nil
    }

    self.resize()
    return result
  }

  @discardableResult
  public mutating func remove(_ member: Element) -> Element? {
    let h = abs(member.hashValue % self.capacity)
    if let containedIndex = self.content[h].index(where: { $0.containee == member }) {
      overestimateCount -= 1
      return self.content[h].remove(at: containedIndex).containee
    } else {
      return nil
    }
  }

  public mutating func resize(minimumCapacity: Int? = nil) {
    let newCapacity: Int
    if minimumCapacity != nil {
      newCapacity = Swift.max(minimumCapacity!, capacity)
    } else if overestimateCount > Int(Double(capacity) * 0.8) {
      newCapacity = capacity * 2
    } else {
      return
    }

    var newContent: [[WeakSetElement<Element>]] = Array(repeating: [], count: newCapacity)
    for bucket in self.content {
      for container in bucket {
        if container.containee != nil {
          newContent[abs(container.containee!.hashValue % newCapacity)].append(container)
        }
      }
    }
    self.content = newContent
  }

}

extension WeakSet: Equatable {

  public static func ==(lhs: WeakSet<Element>, rhs: WeakSet<Element>) -> Bool {
    return Set(lhs) == Set(rhs)
  }

}

extension WeakSet: SetAlgebra {


  public func union<S>(_ other: S) -> WeakSet where S: Sequence, S.Element == Element {
    var result = self
    for element in other {
      result.insert(element)
    }
    return result
  }

  public mutating func formUnion<S>(_ other: S) where S: Sequence, S.Element == Element {
    for element in other {
      self.insert(element)
    }
  }

  public func intersection<S>(_ other: S) -> WeakSet where S: Sequence, S.Element == Element {
    var result = WeakSet(minimumCapacity: self.capacity)
    for element in other {
      if self.contains(element) {
        result.insert(element)
      }
    }
    return result
  }

  public mutating func formIntersection<S>(_ other: S) where S: Sequence, S.Element == Element {
    let otherElements = Array(other)
    self.subtract(where: { !otherElements.contains($0) })
  }

  public func symmetricDifference<S>(_ other: S) -> WeakSet
    where S: Sequence, S.Element == Element
  {
    let otherSet = WeakSet(other)
    return self.subtracting(otherSet).union(otherSet.subtracting(self))
  }

  public mutating func formSymmetricDifference<S>(_ other: S)
    where S: Sequence, S.Element == Element
  {
    self.content = self.symmetricDifference(other).content
  }

  public func subtracting(_ other: WeakSet) -> WeakSet {
    var result = self
    for element in other {
      result.remove(element)
    }
    return result
  }

  public func subtracting<S>(_ other: S) -> WeakSet where S: Sequence, S.Element == Element {
    var result = self
    for element in other {
      result.remove(element)
    }
    return result
  }

  public func subtracting(where isRemoved: (Element) -> Bool) -> WeakSet {
    var result = self
    result.subtract(where: isRemoved)
    return result
  }

  public mutating func subtract(_ other: WeakSet<Element>) {
    for element in other {
      self.remove(element)
    }
  }

  public mutating func subtract<S>(_ other: S) where S: Sequence, S.Element == Element {
    for element in other {
      self.remove(element)
    }
  }

  @discardableResult
  public mutating func subtract(where isRemoved: (Element) -> Bool) -> [Element] {
    var removed: [Element] = []

    var bucketIndex = 0
    while bucketIndex < self.content.count {
      var elementIndex = 0
      while elementIndex < self.content[bucketIndex].count {
        if let element = self.content[bucketIndex][elementIndex].containee,
          isRemoved(element)
        {
          overestimateCount -= 1
          self.content[bucketIndex].remove(at: elementIndex)
          removed.append(element)
        } else {
          elementIndex += 1
        }
      }
      bucketIndex += 1
    }

    self.resize()
    return removed
  }

}

extension WeakSet: Collection {

  public typealias Index = WeakSetIterator

  public var startIndex: Index {
    return index(after: WeakSetIterator(bucket: 0, entry: -1))
  }

  public var endIndex: Index {
    return WeakSetIterator(bucket: content.count, entry: 0)
  }

  public func index(after i: WeakSetIterator) -> WeakSetIterator {
    var nextIndex = i
    while true {
      nextIndex.entry += 1
      if nextIndex.entry >= content[nextIndex.bucket].count {
        nextIndex.bucket += 1
        nextIndex.entry = 0
      }

      guard nextIndex.bucket < content.count
        else { return endIndex }
      guard nextIndex.entry < content[nextIndex.bucket].count
        else { continue }
      guard content[nextIndex.bucket][nextIndex.entry].containee != nil
        else { continue }

      return nextIndex
    }
  }

  public subscript(i: Index) -> Element {
    return content[i.bucket][i.entry].containee!
  }

}

public struct WeakSetIterator: Comparable {

  fileprivate var bucket: Int
  fileprivate var entry: Int

  public static func < (lhs: WeakSetIterator, rhs: WeakSetIterator) -> Bool {
    return lhs.bucket == rhs.bucket
      ? lhs.entry < rhs.entry
      : lhs.bucket < rhs.entry
  }

}

extension WeakSet: ExpressibleByArrayLiteral {

  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

}

extension WeakSet: CustomStringConvertible {

  public var description: String {
    let contentDescription = self.map({ String(describing: $0) }).joined(separator: ", ")
    return "WeakSet([\(contentDescription)])"
  }

}

fileprivate struct WeakSetElement<Element> where Element: AnyObject {

  weak var containee: Element?

}