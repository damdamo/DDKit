import Utils

public class Factory<Key> where Key: Comparable & Hashable {

  public init() {
    self.zero = SFDD(factory: self, isOne: false)
    self.uniquenessTable.insert(self.zero)
    self.one = SFDD(factory: self, isOne: true)
    self.uniquenessTable.insert(self.one)
  }

  public func make<S>(_ sequences: S) -> SFDD<Key>
    where S: Sequence, S.Element: Sequence, S.Element.Element == Key
  {
    return sequences.reduce(self.zero) { family, newSequence in
      let set = Set(newSequence)
      guard !set.isEmpty else {
        return family.union(self.one)
      }

      var newMember = self.one!
      for element in set.sorted().reversed() {
        newMember = self.makeNode(key: element, take: newMember, skip: self.zero)
      }
      return family.union(newMember)
    }
  }

  public func make<S>(_ sequences: S...) -> SFDD<Key> where S: Sequence, S.Element == Key {
    return self.make(sequences)
  }

  public func makeNode(key: Key, take: SFDD<Key>, skip: SFDD<Key>) -> SFDD<Key> {
    guard take !== self.zero else {
      return skip
    }

    assert(take.isTerminal || key < take.key, "invalid SFDD ordering")
    assert(skip.isTerminal || key < skip.key, "invalid SFDD ordering")

    let (_, result) = self.uniquenessTable.insert(
      SFDD(key: key, take: take, skip: skip, factory: self),
      withCustomEquality: SFDD<Key>.areEqual)
    return result
  }

  public private(set) var zero: SFDD<Key>! = nil
  public private(set) var one : SFDD<Key>! = nil

  var unionCache              : [[SFDD<Key>]: SFDD<Key>] = [:]
  var intersectionCache       : [[SFDD<Key>]: SFDD<Key>] = [:]
  var symmetricDifferenceCache: [[SFDD<Key>]: SFDD<Key>] = [:]
  var subtractionCache        : [[SFDD<Key>]: SFDD<Key>] = [:]
  private var uniquenessTable : WeakSet<SFDD<Key>> = []

}
