//
//  Algorithms.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.08.2019.
//

extension RandomAccessCollection where Element: Comparable, Index == Int {

    internal func binarySearch(_ element: Element) -> Int {
        var start = startIndex
        var end = endIndex
        while start < end {
            let mid = start + (end - start) / 2
            let midValue = self[mid]
            if element == midValue {
                return mid
            } else if midValue < element {
                start = mid + 1
            } else {
                end = mid
            }
        }
        return .notFound
    }
}

extension Int {
    internal static let notFound = -1
}
