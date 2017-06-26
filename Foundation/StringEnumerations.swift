//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

internal extension String {
    internal func _character(_ char: Character, matchesSet characterSet: NSMutableCharacterSet) -> Bool {
        var found = true
        for ch in String(char).utf16 {
            if !(characterSet as CharacterSet).contains(UnicodeScalar(ch)!) {
                found = false
            }
        }
        return found
    }
    
    internal func _matchWordsInString(str: String, in range: NSRange, using block: (String?, NSRange, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let startIndex = str.index(str.startIndex, offsetBy: range.location)
        let endIndex = str.index(startIndex, offsetBy: range.length)
        
        var currentIdx = startIndex
        
        while currentIdx < endIndex {
            let (word, wordRange, enclosingRange) = matchNextWord(in: str, range: currentIdx..<endIndex)
            var stop: ObjCBool = false
            block(word, NSRange(wordRange, in: str), NSRange(enclosingRange, in: str), &stop)
            
            if stop.boolValue {
                return
            }
            
            currentIdx = enclosingRange.upperBound
        }
    }
    
    internal func _matchLinesInString(str: String, in range: NSRange, using block: (String?, NSRange, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let startIndex = str.index(str.startIndex, offsetBy: range.location)
        let endIndex = str.index(startIndex, offsetBy: range.length)
        
        var currentIdx = startIndex
        
        while currentIdx < endIndex {
            if let (line, lineRange, enclosingRange) = matchNextLine(in: str, range: currentIdx..<endIndex) {
                currentIdx = enclosingRange.upperBound
                var stop: ObjCBool = false
                block(line, NSRange(lineRange, in: str), NSRange(enclosingRange, in: str), &stop)
                if stop.boolValue {
                    return
                }
            } else {
                return
            }
        }
    }
    
    internal func _matchNextWord(in str: String, range: Range<String.Index>) -> (word: String, range: Range<String.Index>, enclosingRange: Range<String.Index>){
        // Characters that words can begin or end with
        let wordStartEndSet = NSMutableCharacterSet()
        wordStartEndSet.formUnion(with: CharacterSet.letters)
        wordStartEndSet.addCharacters(in: "_")
        
        // Characters that can be in the middle of words
        let midWordSet = NSMutableCharacterSet()
        midWordSet.formUnion(with: CharacterSet.letters)
        midWordSet.addCharacters(in: "'_")
        
        var currentIdx = range.lowerBound
        var inWord = false
        var foundWord = false
        var wordStartIdx = currentIdx
        var wordEndIdx = currentIdx
        
        while currentIdx < range.upperBound {
            if inWord {
                if !_character(str.characters[currentIdx], matchesSet: midWordSet) {
                    inWord = false
                    wordEndIdx = currentIdx
                    foundWord = true
                }
            } else if foundWord {
                if _character(str.characters[currentIdx], matchesSet: wordStartEndSet) {
                    return (
                        word: str.substring(with: wordStartIdx..<wordEndIdx),
                        range: wordStartIdx..<wordEndIdx,
                        enclosingRange: range.lowerBound..<currentIdx
                    )
                }
            } else {
                if _character(str.characters[currentIdx], matchesSet: wordStartEndSet) {
                    inWord = true
                    wordStartIdx = currentIdx
                }
            }
            
            currentIdx = str.index(after: currentIdx)
        }
        
        return (
            word: str.substring(with: wordStartIdx..<wordEndIdx),
            range: wordStartIdx..<wordEndIdx,
            enclosingRange: range.lowerBound..<currentIdx
        )
    }
    
    internal func _matchNextLine(in str: String, range: Range<String.Index>) -> (line: String, range: Range<String.Index>, enclosingRange: Range<String.Index>)? {
        let linebreakSet = NSMutableCharacterSet()
        linebreakSet.formUnion(with: CharacterSet.newlines)
        
        var currentIdx = range.lowerBound
        let lineStartIdx = currentIdx
        var lineEndIdx = currentIdx
        
        while currentIdx < range.upperBound {
            if _character(str.characters[currentIdx], matchesSet: linebreakSet) {
                lineEndIdx = currentIdx
                return (
                    line: str.substring(with: lineStartIdx..<lineEndIdx),
                    range: lineStartIdx..<lineEndIdx,
                    enclosingRange: range.lowerBound..<str.index(after: currentIdx)
                )
            }
            
            currentIdx = str.index(after: currentIdx)
        }
        
        return nil
    }
    
}
