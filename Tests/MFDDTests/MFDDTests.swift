import XCTest
import Hashing
@testable import MFDD

class MFDDTests: XCTestCase {

    func testCount() {
        let factory = MFDDFactory<String, Int>()

        XCTAssertEqual(0, factory.zero.count)
        XCTAssertEqual(1, factory.one.count)
        XCTAssertEqual(1, factory.make(["a": 1, "b": 2]).count)
        XCTAssertEqual(2, factory.make(["a": 1, "b": 2], ["a": 1, "b": 3]).count)
        XCTAssertEqual(2, factory.make(["a": 1, "b": 2], [:]).count)
    }

    func testEquates() {
        let factory = MFDDFactory<String, Int>()

        XCTAssertEqual(factory.zero                  , factory.zero)
        XCTAssertEqual(factory.one                   , factory.one)
        XCTAssertEqual(factory.make([:])             , factory.one)
        XCTAssertEqual(factory.make(["a": 1, "b": 2]), factory.make(["a": 1, "b": 2]))
    }

    func testContains() {
        let factory = MFDDFactory<String, Int>()
        var family: MFDD<String, Int>

        family = factory.zero
        XCTAssertFalse(family.contains([:]))

        family = factory.one
        XCTAssertTrue (family.contains([:]))
        XCTAssertFalse(family.contains(["a": 1]))

        family = factory.make(["a": 1])
        XCTAssertFalse(family.contains([:]))
        XCTAssertTrue (family.contains(["a": 1]))
        XCTAssertFalse(family.contains(["a": 2]))

        family = factory.make(["a": 1, "b": 2], ["a": 1, "b": 3], ["a": 1, "b": 4])
        XCTAssertTrue (family.contains(["a": 1, "b": 2]))
        XCTAssertTrue (family.contains(["a": 1, "b": 3]))
        XCTAssertTrue (family.contains(["a": 1, "b": 4]))
        XCTAssertFalse(family.contains([:]))
        XCTAssertFalse(family.contains(["a": 1]))
        XCTAssertFalse(family.contains(["a": 1, "b": 5]))
    }

    func testUnion() {
        let factory = MFDDFactory<String, Int>()

        // Union of two empty families.
        let eue = factory.make([:]).union(factory.make([:]))
        XCTAssertEqual(eue, factory.one)

        // Union of two identical families.
        let family = factory.make(["a": 1, "b": 2, "c": 3])
        XCTAssertEqual(family.union(family), family)

        // Union of different families.
        let families = [
            // Families with overlapping elements.
            (["a": 1, "b": 3, "c": 9], ["a": 1, "b": 3, "c": 8]),
            (["a": 1, "b": 3, "c": 8], ["a": 1, "b": 3, "c": 9]),
            // Families with disjoint elements.
            (["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]),
            (["a": 9, "b": 2, "c": 4], ["a": 1, "b": 3, "c": 9]),
        ]
        for (fa, fb) in families {
            let a   = factory.make(fa)
            let b   = factory.make(fb)
            let aub = a.union(b)
            let bua = b.union(a)

            XCTAssertEqual(Set(aub.map(HD.init)), Set([HD(fa), HD(fb)]))
            XCTAssertEqual(aub, bua)
        }
    }

    func testIntersection() {
        let factory = MFDDFactory<String, Int>()

        // Intersection of two empty families.
        let eue = factory.make([:]).intersection(factory.make([:]))
        XCTAssertEqual(eue, factory.one)

        // Intersection of two identical families.
        let family = factory.make([["a": 1, "b": 3, "c": 8], ["a": 0, "b": 2, "c": 4]])
        XCTAssertEqual(family.intersection(family), family)

        // Intersection of families with overlapping elements.
        let overlappingFamilies = [
            (
                [["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]],
                [["a": 1, "b": 3, "c": 9], ["a": 5, "b": 6, "c": 7]]
            ),
            (
                [["a": 1, "b": 3, "c": 9], ["a": 5, "b": 6, "c": 7]],
                [["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]]
            ),
        ]
        for (fa, fb) in overlappingFamilies {
            let a   = factory.make(fa)
            let b   = factory.make(fb)
            let aib = a.intersection(b)
            let bia = b.intersection(a)

            XCTAssertEqual(Set(aib.map(HD.init)), Set([["a": 1, "b": 3, "c": 9]]))
            XCTAssertEqual(aib, bia)
        }

        // Intersection of families with disjoint elements.
        let disjointFamilies = [
            (
                [["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]],
                [["a": 1, "b": 3, "c": 0], ["a": 5, "b": 6, "c": 7]]
            ),
            (
                [["a": 1, "b": 3, "c": 0], ["a": 5, "b": 6, "c": 7]],
                [["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]]
            ),
        ]
        for (fa, fb) in disjointFamilies {
            let a   = factory.make(fa)
            let b   = factory.make(fb)
            let aib = a.intersection(b)
            let bia = b.intersection(a)

            XCTAssertEqual(aib, factory.zero)
            XCTAssertEqual(aib, bia)
        }
    }

    func testSymmetricDifference() {
        let factory = MFDDFactory<String, Int>()

        // Symmetric difference between two empty families.
        let ese = factory.make([]).symmetricDifference(factory.make([]))
        XCTAssertEqual(ese, factory.zero)

        // Symmetric difference between two identical families.
        let family = factory.make([["a": 1, "b": 3, "c": 8], ["a": 0, "b": 2, "c": 4]])
        XCTAssertEqual(family.symmetricDifference(family), factory.zero)

        // Symmetric difference between families with overlapping elements.
        let overlappingA = factory.make([["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]])
        let overlappingB = factory.make([["a": 1, "b": 3, "c": 9], ["a": 5, "b": 6, "c": 7]])
        let overlappingC = overlappingA.symmetricDifference(overlappingB)
        XCTAssertEqual(
            Set(overlappingC.map(HD.init)),
            Set([["a": 0, "b": 2, "c": 4], ["a": 5, "b": 6, "c": 7]]))

        // Symmetric difference between families with disjoint elements.
        let disjointA = factory.make([["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]])
        let disjointB = factory.make([["a": 1, "b": 3, "c": 0], ["a": 5, "b": 6, "c": 7]])
        let disjointC = disjointA.symmetricDifference(disjointB)
        XCTAssertEqual(
            Set(disjointC.map(HD.init)),
            Set([
                ["a": 1, "b": 3, "c": 9],
                ["a": 0, "b": 2, "c": 4],
                ["a": 1, "b": 3, "c": 0],
                ["a": 5, "b": 6, "c": 7],
            ]))
    }

    func testSubtracting() {
        let factory = MFDDFactory<String, Int>()

        // Subtraction between two empty families.
        let ese = factory.make([:]).subtracting(factory.make([:]))
        XCTAssertEqual(ese, factory.zero)

        // Subtraction between two identical families.
        let family = factory.make([["a": 1, "b": 3, "c": 8], ["a": 0, "b": 2, "c": 4]])
        XCTAssertEqual(family.subtracting(family), factory.zero)

        // Subtraction between families with overlapping elements.
        let overlappingA = factory.make([["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]])
        let overlappingB = factory.make([["a": 1, "b": 3, "c": 9], ["a": 5, "b": 6, "c": 7]])
        let overlappingC = overlappingA.subtracting(overlappingB)
        XCTAssertEqual(Set(overlappingC.map(HD.init)), Set([["a": 0, "b": 2, "c": 4]]))

        // Subtraction between families with disjoint elements.
        let disjointA = factory.make([["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]])
        let disjointB = factory.make([["a": 1, "b": 3, "c": 0], ["a": 5, "b": 6, "c": 7]])
        let disjointC = disjointA.subtracting(disjointB)
        XCTAssertEqual(
            Set(disjointC.map(HD.init)),
            Set([["a": 1, "b": 3, "c": 9], ["a": 0, "b": 2, "c": 4]]))
    }

    func testAsSequence() {
        let factory = MFDDFactory<String, Int>()

        XCTAssertEqual(Set(factory.zero.map(HD.init)), Set([]))
        XCTAssertEqual(Set(factory.one .map(HD.init)), Set([[:]]))

        XCTAssertEqual(
            Set(factory.make(["a": 1]).map(HD.init)),
            Set([["a": 1]]))
        XCTAssertEqual(
            Set(factory.make([:], ["a": 1]).map(HD.init)),
            Set([[:], ["a": 1]]))
        XCTAssertEqual(
            Set(factory.make(["a": 1, "b": 2], ["a": 1, "b": 2, "c": 3]).map(HD.init)),
            Set([["a": 1, "b": 2], ["a": 1, "b": 2, "c": 3]]))
        XCTAssertEqual(
            Set(factory.make(["a": 1, "b": 2], ["a": 1, "b": 3, "c": 3]).map(HD.init)),
            Set([["a": 1, "b": 2], ["a": 1, "b": 3, "c": 3]]))
    }

    static var allTests = [
        ("testCount"              , testCount),
        ("testEquates"            , testEquates),
        ("testContains"           , testContains),
        ("testUnion"              , testUnion),
        ("testIntersection"       , testIntersection),
        ("testSymmetricDifference", testSymmetricDifference),
        ("testSubtracting"        , testSubtracting),
        ("testAsSequence"         , testAsSequence),
    ]

}

/// Wrapper around Swift's native Dictionary that supports hashing.
///
/// This type will be deprecated from Swift when conditional conformances will be implemented
/// (see SE-0143).
struct HD<Key, Value>: Hashable where Key: Hashable, Value: Hashable {

    init(_ content: [Key: Value]) {
        self.content = content
    }

    let content: [Key: Value]

    var hashValue: Int {
        return hash(self.content.map({ [$0.key.hashValue, $0.value.hashValue] }).joined())
    }

    static func ==(lhs: HD, rhs: HD) -> Bool {
        return lhs.content == rhs.content
    }

}

extension HD: CustomStringConvertible {

    var description: String {
        return self.content.description
    }

}

extension HD: ExpressibleByDictionaryLiteral {

    init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }

}