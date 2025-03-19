//
//  Matcher.swift
//
//
//  Created by Christopher DeVito on 2/11/24.
//

typealias MatcherBlock = (String) -> [Match]

public class Match {
    public var i: Int = 0
    public var j: Int = 0
    public var token: String = ""

    public init(i: Int, j: Int, token: String) {
        self.i = i
        self.j = j
        self.token = token
    }

    // Pattern Match
    public var pattern: String = ""
    public var entropy: Float = 0.0
    public var cardinality: Int = 0
    public var guesses: Double? = nil
    public var guessesLog10: Double? = nil

    // Dictionary Match
    public var matchedWord: String? = nil
    public var dictionaryName: String? = nil
    public var rank: Double? = nil
    public var baseEntropy: Float? = nil
    public var upperCaseEntropy: Float? = nil

    // L33t Match
    public var l33t: Bool? = nil
    public var sub: [Character: Character]? = nil
    public var subDisplay: String? = nil
    public var l33tEntropy: Float? = nil

    // Spatial Match
    public var graph: String? = nil
    public var turns: Int? = nil
    public var shiftedCount: Int? = nil

    // Repeat Match
    public var repeatedChar: String? = nil
    public var repeatCount: Double? = nil
    public var baseToken: String? = nil
    public var baseMatches: [Match]? = nil

    // Sequence Match
    public var sequenceName: String? = nil
    public var sequenceSpace: Int? = nil
    public var ascending: Bool? = nil

    // Date Match
    public var year: Int? = nil
    public var month: Int? = nil
    public var day: Int? = nil
    public var separator: String? = nil

    // Dictionary Guesses
    public var baseGuesses: Double? = nil
    public var uppercaseVariations: Double? = nil
    public var l33tVariations: Double? = nil
    public var reversed: Bool? = nil

    // Regex Match
    public var regexName: String? = nil
    public var regexMatch: [String]? = nil

}

extension Match: Equatable {
    public static func == (lhs: Match, rhs: Match) -> Bool {
        return lhs.pattern == rhs.pattern &&
            lhs.i == rhs.i &&
            lhs.j == rhs.j &&
            lhs.token == rhs.token &&
            lhs.entropy == rhs.entropy &&
            lhs.cardinality == rhs.cardinality &&
            lhs.guesses == rhs.guesses &&
            lhs.guessesLog10 == rhs.guessesLog10 &&
            lhs.matchedWord == rhs.matchedWord &&
            lhs.dictionaryName == rhs.dictionaryName &&
            lhs.rank == rhs.rank &&
            lhs.baseEntropy == rhs.baseEntropy &&
            lhs.upperCaseEntropy == rhs.upperCaseEntropy &&
            lhs.l33t == rhs.l33t &&
            lhs.sub == rhs.sub &&
            lhs.subDisplay == rhs.subDisplay &&
            lhs.l33tEntropy == rhs.l33tEntropy &&
            lhs.graph == rhs.graph &&
            lhs.turns == rhs.turns &&
            lhs.shiftedCount == rhs.shiftedCount &&
            lhs.repeatedChar == rhs.repeatedChar &&
            lhs.repeatCount == rhs.repeatCount &&
            lhs.sequenceName == rhs.sequenceName &&
            lhs.sequenceSpace == rhs.sequenceSpace &&
            lhs.ascending == rhs.ascending &&
            lhs.year == rhs.year &&
            lhs.month == rhs.month &&
            lhs.day == rhs.day &&
            lhs.separator == rhs.separator &&
            lhs.baseGuesses == rhs.baseGuesses &&
            lhs.uppercaseVariations == rhs.uppercaseVariations &&
            lhs.l33tVariations == rhs.l33tVariations &&
            lhs.reversed == rhs.reversed &&
            lhs.regexName == rhs.regexName &&
            lhs.regexMatch == rhs.regexMatch
    }
}
