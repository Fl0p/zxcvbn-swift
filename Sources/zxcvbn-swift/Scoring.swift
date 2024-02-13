//
//  Matcher.swift
//
//
//  Created by Christopher DeVito on 2/11/24.
//

import Foundation

class Scoring {
    // ------------------------------------------------------------------------------
    // search --- most guessable match sequence -------------------------------------
    // ------------------------------------------------------------------------------

    // takes a sequence of overlapping matches, returns the non-overlapping sequence with
    // minimum guesses. the following is a O(l_max * (n + m)) dynamic programming algorithm
    // for a length-n password with m candidate matches. l_max is the maximum optimal
    // sequence length spanning each prefix of the password. In practice it rarely exceeds 5 and the
    // search terminates rapidly.

    // the optimal "minimum guesses" sequence is here defined to be the sequence that
    // minimizes the following function:

    //     g = l! * Product(m.guesses for m in sequence) + D^(l - 1)

    // where l is the length of the sequence.

    // the factorial term is the number of ways to order l patterns.

    // the D^(l-1) term is another length penalty, roughly capturing the idea that an
    // attacker will try lower-length sequences first before trying length-l sequences.

    // for example, consider a sequence that is date-repeat-dictionary.
    // - an attacker would need to try other date-repeat-dictionary combinations,
    //     hence the product term.
    // - an attacker would need to try repeat-date-dictionary, dictionary-repeat-date,
    //     ..., hence the factorial term.
    // - an attacker would also likely try length-1 (dictionary) and length-2 (dictionary-date)
    //     sequences before length-3. assuming at minimum D guesses per pattern type,
    //     D^(l-1) approximates Sum(D^i for i in [1..l-1]

    // ------------------------------------------------------------------------------
    let adjacencyGraphs = Helpers.shared.loadAdjacencyGraphs()
    let BRUTEFORCE_CARDINALITY = 10
    let MIN_GUESSES_BEFORE_GROWING_SEQUENCE = 10000
    let MIN_SUBMATCH_GUESSES_SINGLE_CHAR = 10
    let MIN_SUBMATCH_GUESSES_MULTI_CHAR = 50
    let MIN_YEAR_SPACE = 20
    let REFERENCE_YEAR = Calendar.current.component(.year, from: Date())
    
    /// Implements an n choose k check for the number of ways to choose k elements from a set of n elements
    /// - Parameters:
    ///   - n: the total number of elements
    ///   - k: the number of elements per combination
    /// - Returns: The int representing the number of total combinations
    func nChooseK(_ n: Int, _ k: Int) -> Int {
        var n = n
        if k > n {
            return 0
        }
        if k == 0 {
            return 1
        }
        var r = 1
        for d in 1...k {
            r *= n
            r /= d
            n -= 1
        }
        return r
    }


    /// Warning: This method is not optimized. Only run on small factorials.
    /// - Parameter n: The number to calculate the factorial of.
    /// - Returns: The factorial of the given number. Returns Int.max if the number is greater than 20.

    func factorial(_ n: Int) -> Double {
        if n < 2 {
            return 1
        }
        // if n > 20 {
        //     return Int.max
        // }
        var f = 1.0
        for i in 2...n {
            f *= Double(i)
        }
        return f
    }

    func calcAverageDegree(graph: [String: [String?]]) -> Double {
        var average = 0.0
        for (_, neighbors) in graph {
            average += Double(neighbors.compactMap { $0 }.count)
        }
        average /= Double(graph.count)
        return average
    }

    func mostGuessableMatchSequence(password: String, matches: [Match], excludeAdditive: Bool = false) -> MostGuessableMatchSequenceResult {
        let n = password.count

        var matchesByJ = Array(repeating: [Match](), count: n)
        for match in matches {
            matchesByJ[match.j].append(match)
        }
        for index in matchesByJ.indices {
            matchesByJ[index].sort { $0.i < $1.i }
        }

        var optimal = Optimal(n: n)

        for k in 0..<n {
            for match in matchesByJ[k] {
                if match.i > 0 {
                    for (l, _) in optimal.m[match.i - 1] {
                        update(match: match, l: l + 1, optimal: &optimal, password: password, excludeAdditive: excludeAdditive)
                    }
                } else {
                    update(match: match, l: 1, optimal: &optimal, password: password, excludeAdditive: excludeAdditive)
                }
            }
            bruteforceUpdate(k: k, optimal: &optimal, password: password, excludeAdditive: excludeAdditive)
        }
        let optimalMatchSequence = unwind(n: n, optimal: optimal)
        let optimalL = optimalMatchSequence.count

        var guesses: Double = 1
        if password.count != 0 {
            guesses = optimal.g[n - 1][optimalL]!
        }

        return MostGuessableMatchSequenceResult(password: password, guesses: guesses, guessesLog10: log10(guesses), sequence: optimalMatchSequence) 
    }

    func estimateGuesses(match: Match, password: String) -> Int {
        guard match.guesses == nil else { return match.guesses! }
        var minGuesses = 1
        if match.token.count < password.count {
            minGuesses = match.token.count == 1 ? MIN_SUBMATCH_GUESSES_SINGLE_CHAR : MIN_SUBMATCH_GUESSES_MULTI_CHAR
        }

        let guesses: Int
        switch match.pattern {
        case "bruteforce":
            guesses = bruteforceGuesses(match: match)
        case "dictionary":
            guesses = dictionaryGuesses(match: match)
        case "spatial":
            guesses = spatialGuesses(match: match)
        case "repeat":
            guesses = repeatGuesses(match: match)
        case "sequence":
            guesses = sequenceGuesses(match: match)
        case "regex":
            guesses = regexGuesses(match: match)
        case "date":
            guesses = dateGuesses(match: match)
        default:
            guesses = 1
        }

        match.guesses = max(guesses, minGuesses)
        match.guessesLog10 = log10(Double(match.guesses!))
        return match.guesses!
    }

    func bruteforceGuesses(match: Match) -> Int {
        var guesses = Double(pow(Double(BRUTEFORCE_CARDINALITY), Double(match.token.count)))
        if guesses == Double.infinity {
            guesses = Double.greatestFiniteMagnitude
        }
        let minGuesses = match.token.count == 1 ? MIN_SUBMATCH_GUESSES_SINGLE_CHAR + 1 : MIN_SUBMATCH_GUESSES_MULTI_CHAR + 1
        return max(Int(guesses), minGuesses)    
    }

    func repeatGuesses(match: Match) -> Int {
        guard let baseGuesses = match.baseGuesses, let repeatCount = match.repeatCount else { return 1 }
        return baseGuesses * repeatCount
    }

    func sequenceGuesses(match: Match) -> Int {
        let firstChar = match.token.first!
        var baseGuesses: Int
        if ["a", "A", "z", "Z", "0", "1", "9"].contains(firstChar) {
            baseGuesses = 4
        } else if firstChar.isNumber {
            baseGuesses = 10 // digits
        } else {
            baseGuesses = 26
        }
        guard let ascending = match.ascending else { return baseGuesses * match.token.count }
        if !ascending {
            baseGuesses *= 2
        }
        return baseGuesses * match.token.count
    }

    func regexGuesses(match: Match) -> Int {
        guard let regexName = match.regexName else { return 0 }
        let charClassBases = [
            "alpha_lower": 26,
            "alpha_upper": 26,
            "alpha": 52,
            "alphanumeric": 62,
            "digits": 10,
            "symbols": 33
        ]
        
        if let base = charClassBases[regexName] {
            return Int(pow(Double(base), Double(match.token.count)))
        } else if let regexMatch = match.regexMatch, regexName == "recent_year", let firstChar = regexMatch.first, let year = Int(String(firstChar)) {
            let yearSpace = max(abs(year - REFERENCE_YEAR), MIN_YEAR_SPACE)
            return yearSpace
        }
        return 0
    }

    func dateGuesses(match: Match) -> Int {
        guard let year = match.year else { return 1 }
        let yearSpace = max(abs(year - REFERENCE_YEAR), MIN_YEAR_SPACE)
        var guesses = yearSpace * 365
        if match.separator != nil {
            guesses *= 4
        }
        return guesses
    }

    func spatialGuesses(match: Match) -> Int {
        let adjacencyGraphs = Helpers.shared.loadAdjacencyGraphs()
        let KEYBOARD_AVERAGE_DEGREE = calcAverageDegree(graph: adjacencyGraphs["qwerty"]!)
        let KEYPAD_AVERAGE_DEGREE = calcAverageDegree(graph: adjacencyGraphs["keypad"]!)
        let KEYBOARD_STARTING_POSITIONS = adjacencyGraphs["qwerty"]!.count
        let KEYPAD_STARTING_POSITIONS = adjacencyGraphs["keypad"]!.count

        // let (s, d): (Int, Double)
        let s: Int
        let d: Double
        if ["qwerty", "dvorak"].contains(match.graph) {
            s = KEYBOARD_STARTING_POSITIONS
            d = KEYBOARD_AVERAGE_DEGREE
        } else {
            s = KEYPAD_STARTING_POSITIONS
            d = KEYPAD_AVERAGE_DEGREE
        }
        var guesses = 0
        let L = match.token.count
        guard let t = match.turns else { return guesses }
        for i in 2...L {
            let possibleTurns = min(t, i - 1)
            for j in 1...possibleTurns {
                guesses += (nChooseK(i - 1, j - 1)) * s * Int(pow(d, Double(j)))
            }
        }
        guard let shift = match.shiftedCount else { return guesses }
        let U = match.token.count - shift
        if shift == 0 || U == 0 {
            guesses *= 2
        } else {
            var shiftedVariations = 0
            for i in 1...min(shift, U) {
                shiftedVariations += nChooseK(shift + U, i)
            }
            guesses *= shiftedVariations
        }
        return guesses
    }

    func dictionaryGuesses(match: Match) -> Int {
        guard let rank = match.rank, let reversed = match.reversed else { return 1 }
        match.baseGuesses = rank // keep these as properties for display purposes
        match.uppercaseVariations = uppercaseVariations(match: match)
        match.l33tVariations = l33tVariations(match: match)
        let reversedVariations = reversed ? 2 : 1

        return match.baseGuesses! * match.uppercaseVariations! * match.l33tVariations! * reversedVariations
    }

    func uppercaseVariations(match: Match) -> Int {
        let word = match.token
        let START_UPPER = "^[A-Z][^A-Z]+$"
        let END_UPPER = "^[^A-Z]+[A-Z]$"
        let ALL_UPPER = "^[^a-z]+$"
        let ALL_LOWER = "^[^A-Z]+$"

        if word.range(of: ALL_LOWER, options: .regularExpression) != nil || word.lowercased() == word {
            return 1
        }

        let regexes = [START_UPPER, END_UPPER, ALL_UPPER]
        for regex in regexes {
            if word.range(of: regex, options: .regularExpression) != nil {
                return 2
            }
        }
        let U = word.filter { $0.isUppercase }.count
        let L = word.filter { $0.isLowercase }.count
        var variations = 0
        for i in 1...min(U, L) {
            variations += nChooseK(U + L, i)
        }
        return variations
    }

    func l33tVariations(match: Match) -> Int {
        var variations = 1
        guard let l33t = match.l33t, l33t, let sub = match.sub else { return variations }

        for (subbed, unsubbed) in sub {
            let chrs = Array(match.token.lowercased())
            let S = chrs.filter { String($0) == subbed }.count
            let U = chrs.filter { String($0) == unsubbed }.count
            if S == 0 || U == 0 {
                variations *= 2
            } else {
                let p = min(U, S)
                var possibilities = 0
                for i in 1...p {
                    possibilities += nChooseK(U + S, i)
                }
                variations *= possibilities
            }
        }
        return variations
    }


    // MARK: - Helper functions

    func update(match: Match, l: Int, optimal: inout Optimal, password: String, excludeAdditive: Bool) {
        let k = match.j
        optimal.m[k][l] = match

        var pi = Double(estimateGuesses(match: match, password: password))
        if l > 1 {
            if let lastPi = optimal.pi[match.i - 1][l - 1] {
                pi *= lastPi
            } 
        }
        optimal.pi[k][l] = pi

        var g = factorial(l) * pi
        if !excludeAdditive {
            g += pow(Double(MIN_GUESSES_BEFORE_GROWING_SEQUENCE), Double(l - 1))
        }
        for (competingL, competingG) in optimal.g[k] {
            if competingL > l {
                continue
            }
            if competingG <= g {
                return
            }
        }
        optimal.g[k][l] = g
    }

    func bruteforceUpdate(k: Int, optimal: inout Optimal, password: String, excludeAdditive: Bool) {
        let m = makeBruteforceMatch(i: 0, j: k, password: password)
        update(match: m, l: 1, optimal: &optimal, password: password, excludeAdditive: excludeAdditive)
        for i in 1...k {
            let m = makeBruteforceMatch(i: i, j: k, password: password)
            for (l, lastM) in optimal.m[i - 1] {
                let l = l
                if lastM.pattern == "bruteforce" {
                    continue
                }
                update(match: m, l: l + 1, optimal: &optimal, password: password, excludeAdditive: excludeAdditive)
            }
        }
    }

    func makeBruteforceMatch(i: Int, j: Int, password: String) -> Match {
        let startIndex = password.index(password.startIndex, offsetBy: i)
        let endIndex = password.index(password.startIndex, offsetBy: j)
        let token = String(password[startIndex...endIndex])
        let match = Match()
        match.pattern = "bruteforce"
        match.token = token
        match.i = i
        match.j = j
        return match
    }

    func unwind(n: Int, optimal: Optimal) -> [Match] {
        var optimalMatchSequence = [Match]()
        var k = n - 1
        var l: Int? = nil
        var g = Double.infinity
        for (candidateL, candidateG) in optimal.g[k] {
            if candidateG < g {
                l = candidateL
                g = candidateG
            }
        }
        guard var l else { return optimalMatchSequence }
        while k >= 0 {
            let m = optimal.m[k][l]!
            optimalMatchSequence.insert(m, at: 0)
            k = m.i - 1
            l -= 1
        }
        return optimalMatchSequence
    }
}

struct MostGuessableMatchSequenceResult {
    var password: String
    var guesses: Double
    var guessesLog10: Double
    var sequence: [Match]
}
