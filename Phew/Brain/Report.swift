import AppKit
import CoreText

/// Saves a finished task's report (PA.3, docs/03-experience.md 3.6): a PDF in the folder the user chose, else
/// Downloads, and its Markdown copy in Phew's own storage. Phew's code writes them, never the model. New files only:
/// a taken name gets " 2", " 3"…, and a file is created only where none exists, so nothing is ever replaced.
enum Report {
    /// Phew's own copies, for Phew and the agents. A var only so unit tests can write elsewhere.
    nonisolated(unsafe) static var copies = URL.applicationSupportDirectory.appending(path: "Phew/reports")

    struct Saved: Sendable, Equatable {
        var pdf: URL
        var copy: URL
    }

    enum SaveError: Error { case noFolder, outsideFolder, noFreeName }

    /// The PDF in `folder` (nil: Downloads) and the Markdown copy, both named from the date and the task's first
    /// words, never from the model or a web page.
    static func save(_ markdown: String, task words: String, folder: URL?, now: Date = .now) throws -> Saved {
        guard let folder = folder ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw SaveError.noFolder
        }
        try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)
        let base = name(words, now: now)
        let pdf = try writeNew(pdf(markdown), in: folder, base: base, ext: "pdf")
        let copy = try writeNew(Data(markdown.utf8), in: copies, base: base, ext: "md")
        return Saved(pdf: pdf, copy: copy)
    }

    /// "2026-11-20 Kerning sources": the day, then the first five words of the task. No slash, no colon, no "..",
    /// no dot at the start, at most 60 characters.
    static func name(_ words: String, now: Date = .now) -> String {
        let day = now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())  // the user's day, not UTC's
        let cleaned = words.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" ? Character($0) : " " }
        let first = String(cleaned).split(separator: " ").prefix(5).joined(separator: " ")
        let title = String(first.prefix(60)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "\(day) Report" : "\(day) \(title.prefix(1).uppercased())\(title.dropFirst())"
    }

    /// Creates `base.ext`, else `base 2.ext`, `base 3.ext`… Each try fails if anything exists at that path, a
    /// shortcut included (`withoutOverwriting` creates with O_EXCL), so no file is replaced and none is followed.
    static func writeNew(_ data: Data, in folder: URL, base: String, ext: String) throws -> URL {
        let folder = folder.standardizedFileURL
        for n in 1...999 {
            let url = folder.appending(path: n == 1 ? "\(base).\(ext)" : "\(base) \(n).\(ext)")
            guard url.deletingLastPathComponent().standardizedFileURL == folder else { throw SaveError.outsideFolder }
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw SaveError.noFreeName
    }

    // MARK: PDF

    static let page = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4, in points
    static let margin: CGFloat = 56

    /// The Markdown as an A4 PDF, drawn with Core Text into a PDF context: no view, no window, any thread.
    static func pdf(_ markdown: String) -> Data {
        let data = NSMutableData()
        var box = page
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        let text = styled(markdown)
        let setter = CTFramesetterCreateWithAttributedString(text)
        let area = CGPath(rect: page.insetBy(dx: margin, dy: margin), transform: nil)
        var start = 0
        repeat {
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), area, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let shown = CTFrameGetVisibleStringRange(frame).length
            start += max(shown, 1)  // a line too tall for a page still moves on
        } while start < text.length
        context.closePDF()
        return data as Data
    }

    /// One paragraph per line: "#" headings, "-" or "*" bullets, the rest body text. Bold, italics and code inside a
    /// line come from Foundation's Markdown reader; a link shows its address after its words, so it survives print.
    static func styled(_ markdown: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for raw in markdown.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            var size: CGFloat = 11, bold = false, space: CGFloat = 4
            if let hashes = line.firstIndex(where: { $0 != "#" }), hashes > line.startIndex, line[hashes] == " " {
                let level = line.distance(from: line.startIndex, to: hashes)
                size = [20, 15, 13][min(level, 3) - 1]
                bold = true
                space = 8
                line = String(line[hashes...]).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                line = "•  " + line.dropFirst(2)
            } else if line == "---" {
                line = ""
            }
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = space
            style.lineSpacing = 2
            let inline = (try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(line)
            for run in inline.runs {
                let piece = String(inline[run.range].characters)
                let intent = run.inlinePresentationIntent ?? []
                var traits: NSFontDescriptor.SymbolicTraits = []
                if bold || intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                let base = intent.contains(.code) ? NSFont.monospacedSystemFont(ofSize: size - 1, weight: .regular) : NSFont.systemFont(ofSize: size)
                let font = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits), size: base.pointSize) ?? base
                out.append(NSAttributedString(string: piece, attributes: [.font: font, .paragraphStyle: style]))
                if let link = run.link?.absoluteString, link != piece {
                    out.append(NSAttributedString(string: " (\(link))", attributes: [
                        .font: NSFont.systemFont(ofSize: size - 2), .paragraphStyle: style,
                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.4, alpha: 1),
                    ]))
                }
            }
            out.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: size), .paragraphStyle: style]))
        }
        return out
    }
}
