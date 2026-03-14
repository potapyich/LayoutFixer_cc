import ApplicationServices

struct AXTextWriter {
    private let reader = AXTextReader()

    func write(convertedText: String, replacing range: CFRange, in element: AXUIElement, selectResult: Bool) -> Bool {
        // Strategy A: select the range, then replace via kAXSelectedTextAttribute.
        // More targeted than full-text replacement — avoids cursor-reset-to-0 in
        // apps (e.g. webview-based inputs like VS Code extensions) that ignore
        // kAXSelectedTextRangeAttribute after a full kAXValueAttribute write.
        if inPlaceReplace(convertedText: convertedText, range: range, in: element, selectResult: selectResult) {
            return true
        }
        // Strategy B: write full kAXValueAttribute, then reposition cursor.
        // Fallback for elements that don't support kAXSelectedTextAttribute writes.
        return fullTextReplace(convertedText: convertedText, range: range, in: element, selectResult: selectResult)
    }

    // MARK: - Private

    private func inPlaceReplace(convertedText: String, range: CFRange, in element: AXUIElement, selectResult: Bool) -> Bool {
        // Step 1: select the target range
        var selectRange = range
        guard let axSelectRange = AXValueCreate(.cfRange, &selectRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axSelectRange) == .success
        else { return false }

        // Step 2: replace the selection with converted text
        guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, convertedText as CFTypeRef) == .success
        else { return false }

        // Step 3: for user-selection case, re-select the converted text so it stays highlighted.
        // For lastWord case (selectResult: false), after kAXSelectedTextAttribute set the cursor
        // is naturally at the end of the replacement — no additional range set needed.
        if selectResult {
            var newRange = CFRange(location: range.location, length: convertedText.utf16.count)
            if let axNewRange = AXValueCreate(.cfRange, &newRange) {
                AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axNewRange)
            }
        }

        return true
    }

    private func fullTextReplace(convertedText: String, range: CFRange, in element: AXUIElement, selectResult: Bool) -> Bool {
        guard let fullText = reader.fullText(of: element) else { return false }

        let utf16 = fullText.utf16
        guard range.location >= 0,
              range.location + range.length <= utf16.count else { return false }

        let startIdx = utf16.index(utf16.startIndex, offsetBy: range.location)
        let endIdx = utf16.index(startIdx, offsetBy: range.length)

        var newText = String(utf16[..<startIdx])!
        newText += convertedText
        newText += String(utf16[endIdx...])!

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newText as CFTypeRef
        )

        guard result == .success else { return false }

        // If user had text selected, keep the converted text selected.
        // If it was a cursor-only position (lastWord), just place cursor at end.
        var newRange = selectResult
            ? CFRange(location: range.location, length: convertedText.utf16.count)
            : CFRange(location: range.location + convertedText.utf16.count, length: 0)
        if let axRange = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                axRange
            )
        }

        return true
    }
}
