#!/usr/bin/env xcrun swift
    
import Foundation

// MARK: - Main Execution

/// A group used to synchronize asynchronous file scans.
let fileProcessingDispatchGroup = DispatchGroup()

/// A serial queue used to safely write shared results.
let resultWriterQueue = DispatchQueue(label: "resultWriter")

/// A double quote character used for string parsing.
let doubleQuoteCharacter = "\""

if let rootDirectories = parseRootDirectories() {
    print("Searching for abandoned resource strings...")
    let includeStoryboards = shouldIncludeStoryboards()
    let ignoredFiles = parseIgnoredFiles()
    
    if !ignoredFiles.isEmpty {
        print("Ignoring \(ignoredFiles.count) file(s):")
        for file in ignoredFiles {
            print("  • \(file)")
        }
        print("")
    }
    
    
    let abandonedIdentifiers = findAllAbandonedIdentifiers(in: rootDirectories, includeStoryboards: includeStoryboards, ignoredFiles: ignoredFiles)

    if abandonedIdentifiers.isEmpty {
        print("No abandoned resource strings were detected.")
    } else {
        print("Abandoned resource strings were detected:")
        
        for identifier in abandonedIdentifiers.sorted() {
            print("- \(identifier)")
        }
    }
} else {
    print("Please provide the root directory for source code files as a command line argument.")
}

// MARK: - File Processing

/// Finds files under the given directories that match the provided extensions.
/// - Parameters:
///   - searchDirectories: Root directories to search.
///   - allowedExtensions: File extensions to include, lowercased without leading dot.
/// - Returns: An array of absolute file paths.
func findFiles(in searchDirectories: [String], withExtensions allowedExtensions: [String]) -> [String] {
    let fileManager = FileManager.default
    var matchingFiles = [String]()
    for directory in searchDirectories {
        guard let directoryEnumerator = fileManager.enumerator(atPath: directory) else {
            print("Failed to create enumerator for directory: \(directory)")
            return []
        }
        while let relativePath = directoryEnumerator.nextObject() as? String {
            let fileExtension = (relativePath as NSString).pathExtension.lowercased()
            if allowedExtensions.contains(fileExtension) {
                let absolutePath = (directory as NSString).appendingPathComponent(relativePath)
                matchingFiles.append(absolutePath)
            }
        }
    }
    return matchingFiles
}

/// Reads the contents of a file as a string or exits on failure.
/// - Parameter filePath: Absolute file path.
/// - Returns: The file contents as a string.
func readFileContents(at filePath: String) -> String {
    do {
        return try String(contentsOfFile: filePath)
    } catch {
        print("Cannot read file: \(filePath)")
        exit(1)
    }
}

/// Concatenates all source code files into a single string.
/// - Parameters:
///   - searchDirectories: Root directories to search.
///   - includeStoryboards: Whether to include storyboard files.
/// - Returns: A single string containing all matching file contents.
func concatenateSourceCode(in searchDirectories: [String], includeStoryboards: Bool) -> String {
    var allowedExtensions = ["h", "m", "swift", "jsbundle"]
    if includeStoryboards {
        allowedExtensions.append("storyboard")
    }
    let sourceFiles = findFiles(in: searchDirectories, withExtensions: allowedExtensions)
    return sourceFiles.reduce("") { concatenatedCode, sourceFilePath in
        return concatenatedCode + readFileContents(at: sourceFilePath)
    }
}

// MARK: - Identifier Extraction

/// Extracts all string identifiers from a `.strings` file.
/// - Parameter stringsFilePath: Path to the `.strings` file.
/// - Returns: An array of extracted identifiers.
func extractStringIdentifiers(from stringsFilePath: String) -> [String] {
    return readFileContents(at: stringsFilePath)
        .components(separatedBy: "\n")
        .map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        .filter {
            $0.hasPrefix(doubleQuoteCharacter)
        }
        .map {
            extractIdentifier(fromTrimmedLine: $0)
        }
}

/// Extracts the identifier from a trimmed `.strings` line.
/// - Parameter trimmedLine: A line beginning with a quote character.
/// - Returns: The identifier between the first pair of quotes.
func extractIdentifier(fromTrimmedLine trimmedLine: String) -> String {
    let indexAfterOpeningQuote = trimmedLine.index(after: trimmedLine.startIndex)
    let lineAfterOpeningQuote = trimmedLine[indexAfterOpeningQuote...]
//    print(lineAfterOpeningQuote)
    
    let closingQuoteIndex = lineAfterOpeningQuote.firstIndex(of: "\"")!
    let identifier = lineAfterOpeningQuote[..<closingQuoteIndex]
    return String(identifier)
}

// MARK: - Abandoned Identifier Detection

/// Finds identifiers in a `.strings` file that are not referenced in source code.
/// - Parameters:
///   - stringsFilePath: Path to the `.strings` file.
///   - sourceCode: Concatenated source code to search.
/// - Returns: Identifiers that appear abandoned.
func findAbandonedIdentifiers(in stringsFilePath: String, notFoundIn sourceCode: String) -> [String] {
    return extractStringIdentifiers(from: stringsFilePath).filter { identifier in
        let standardQuotedIdentifier = "\"\(identifier)\""
        let storyboardQuotedIdentifier = "\"@\(identifier)\""
        let javascriptQuotedIdentifier = "'\(identifier)'"
        let isAbandoned = !sourceCode.contains(standardQuotedIdentifier) &&
                          !sourceCode.contains(storyboardQuotedIdentifier) &&
                          !sourceCode.contains(javascriptQuotedIdentifier)
        return isAbandoned
    }
}

func isAbandonedIdentifier(_ identifier: String, in sourceCode: String) -> Bool {
    let standardQuotedIdentifier = "\"\(identifier)\""
    let storyboardQuotedIdentifier = "\"@\(identifier)\""
    let javascriptQuotedIdentifier = "'\(identifier)'"
    return !sourceCode.contains(standardQuotedIdentifier)
    && !sourceCode.contains(storyboardQuotedIdentifier)
    && !sourceCode.contains(javascriptQuotedIdentifier)
}

/// Produces a `.strings` file content excluding specific identifiers.
/// - Parameters:
///   - stringsFilePath: Path to the `.strings` file.
///   - identifiersToRemove: Identifiers to remove.
/// - Returns: The updated `.strings` content.
func stringsFileContent(at stringsFilePath: String, excludingIdentifiers identifiersToRemove: [String]) -> String {
    return readFileContents(at: stringsFilePath)
        .components(separatedBy: "\n")
        .filter { line in
            guard line.hasPrefix(doubleQuoteCharacter) else { return true }
            let lineIdentifier = extractIdentifier(fromTrimmedLine: line.trimmingCharacters(in: .whitespaces))
            return !identifiersToRemove.contains(lineIdentifier)
        }
        .joined(separator: "\n")
}

// Finds abandoned identifiers across all `.strings` files under the given roots.
/// - Parameters:
///   - rootDirectories: Root directories to search.
///   - includeStoryboards: Whether to include storyboard files in the source search.
///   - ignoredFiles: List of `.strings` file names to ignore.
/// - Returns: A map of file paths to abandoned identifiers.
func findAllAbandonedIdentifiers(in rootDirectories: [String], includeStoryboards: Bool, ignoredFiles: [String]) -> [String] {
    let concatenatedSourceCode = concatenateSourceCode(in: rootDirectories, includeStoryboards: includeStoryboards)
    let allStringsFiles = findFiles(in: rootDirectories, withExtensions: ["strings"])
    
    // Filter out ignored files
    let stringsFilePaths = allStringsFiles.filter { filePath in
        let fileName = (filePath as NSString).lastPathComponent
        return !ignoredFiles.contains(fileName)
    }
    
    //Collect all identifiers from all .strings files, tracking which files contain each
    var identifierToFiles = [String: [String]]()
    for stringsFilePath in stringsFilePaths {
        let identifiers = extractStringIdentifiers(from: stringsFilePath)
        for identifier in identifiers {
            identifierToFiles[identifier, default: []].append(stringsFilePath)
        }
    }
    
    let allUniqueIdentifiers = Array(identifierToFiles.keys).sorted()
    var abandonedIdentifiers = Set<String>()
    
    for identifier in allUniqueIdentifiers {
        if isAbandonedIdentifier(identifier, in: concatenatedSourceCode) {
            print(identifier)
            abandonedIdentifiers.insert(identifier)
        }
    }
    
    return Array(abandonedIdentifiers).sorted()
}

// MARK: - Command Line Parsing

/// Parses command line arguments to determine root directories.
/// - Returns: An array of root directories if provided.
func parseRootDirectories() -> [String]? {
    var arguments = Array(CommandLine.arguments.dropFirst())
    
    // Remove special flags
    arguments.removeAll { $0 == "storyboard" || $0.hasPrefix("--ignore=") }
    return arguments.isEmpty ? nil : arguments
}

/// Checks whether the `storyboard` argument is present.
/// - Returns: `true` if the storyboard parameter is present.
func shouldIncludeStoryboards() -> Bool {
    return CommandLine.arguments.last == "storyboard"
}

/// Parses ignored files from command line arguments.
/// - Returns: An array of file names to ignore.
func parseIgnoredFiles() -> [String] {
    var ignoredFiles = [String]()
    
    for argument in CommandLine.arguments {
        if argument.hasPrefix("--ignore=") {
            let files = argument
                .replacingOccurrences(of: "--ignore=", with: "")
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            ignoredFiles.append(contentsOf: files)
        }
    }
    
    return ignoredFiles
}
