#error("""
The code provided in this repo is for illustrative purposes only. It has not been independently
tested, verified, or hardened for production use. Portions of the code were generated with the
assistance of a large language model (LLM) and may contain errors, omissions, or inefficiencies.
Users are strongly advised to conduct thorough independent testing, validation, and security
hardening before deploying this code in any production environment. The author(s) assume no
responsibility or liability for any issues, errors, or damages arising from the use of this code.
Use it at your own risk.

To compile this code, simply delete this #error directive.
""")
 
 import Foundation

class IPuzPuzzle {
    var solutionGrid: [[String?]] = []
    var puzzleGrid: [[String?]] = []
    var clueList: [Clue] = []
    var puzzleData: IPuzPuzzleData?
    var title: String = ""
    var author: String = ""
    var copyright: String = ""
    var intro: String = ""
    var notes: String = ""
    var hasSolution: Bool = false
    var showEnumerations: Bool = false
    
    init(filePath: String) {
        do {
            puzzleData = try loadPuzzleData(from: filePath)
            processPuzzleGrids()
            processClues()
            processMetadata()
        } catch {
            print("Error loading puzzle: \(error)")
        }
    }

    private func loadPuzzleData(from filePath: String) throws -> IPuzPuzzleData {
        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(IPuzPuzzleData.self, from: data)
    }

    private func processPuzzleGrids() {
        // Process solution grid
        if let solution = puzzleData?.solution {
            self.solutionGrid = solution.map { row in
                row.map { cell in
                    cell.stringValue()
                }
            }
            self.hasSolution = true
        } else {
            self.hasSolution = false
            print("No solution grid found in the puzzle data.")
        }
        
        // Process puzzle grid
        if let puzzle = puzzleData?.puzzle {
            self.puzzleGrid = puzzle.map { row in
                row.map { cell in
                    cell.stringValue()
                }
            }
        } else {
            print("No puzzle grid found in the puzzle data.")
        }
    }

    private func processClues() {
        guard let cluesDict = puzzleData?.clues else {
            print("No clues found in the puzzle data.")
            return
        }
        
        for (direction, cluesArray) in cluesDict {
            for clueData in cluesArray {
                if let clue = Clue(from: clueData, direction: direction) {
                    self.clueList.append(clue)
                    processReferenceClues(for: clue, from: clueData)
                }
            }
        }
    }

    private func processReferenceClues(for clue: Clue, from clueData: ClueData) {
        if case .clueDict(let dict) = clueData, let continued = dict.continued {
            for reference in continued {
                if let refDirection = reference.direction,
                   let refNumber = reference.number?.toString() {
                    let referenceClue = Clue(
                        number: refNumber,
                        direction: refDirection,
                        text: "See \(clue.number ?? "") \(clue.direction)",
                        continued: [CrossReference(direction: clue.direction, number: clue.number.map { ClueNum.string($0) })] + continued
                    )
                    self.clueList.append(referenceClue)
                }
            }
        }
    }

    private func processMetadata() {
        guard let puzzleData = puzzleData else { return }
        
        self.title = puzzleData.title ?? ""
        self.author = puzzleData.author ?? ""
        self.copyright = puzzleData.copyright ?? ""
        self.intro = puzzleData.intro ?? ""
        self.notes = puzzleData.notes ?? ""
        self.showEnumerations = puzzleData.showEnumerations ?? false
    }

    func getSolutionAt(row: Int, column: Int) -> String? {
        guard let solution = puzzleData?.solution,
              isValid(row: row, column: column, in: solution) else {
            return nil
        }
        return solution[row][column].stringValue()
    }

    
    func getStyleAt(row: Int, column: Int) -> [String: String]? {
        guard let puzzle = puzzleData?.puzzle,
              row >= 0, row < puzzle.count,
              column >= 0, column < puzzle[row].count else {
            return nil
        }
        
        if case .dict(let styleDict) = puzzle[row][column].style {
            return styleDict
        }
        return nil
    }

    private func isValid(row: Int, column: Int, in grid: [[GridCell]]) -> Bool {
        return row >= 0 && row < grid.count && column >= 0 && column < grid[row].count
    }
    
    func getCellNumberAt(row: Int, column: Int) -> Int? {
        guard let puzzle = puzzleData?.puzzle,
              isValid(row: row, column: column, in: puzzle) else {
            return nil
        }
        
        if case .dict(let cellDict) = puzzle[row][column],
           let cellNum = cellDict.cell?.toInt() {
            return cellNum
        } else {
            return puzzle[row][column].toInt()
        }
    }

    func getCellContentAt(row: Int, column: Int) -> String? {
        guard let puzzle = puzzleData?.puzzle,
              row >= 0, row < puzzle.count,
              column >= 0, column < puzzle[row].count else {
            return nil
        }
        
        return puzzle[row][column].stringValue()
    }
}

// MARK: - Data Models

struct IPuzPuzzleData: Decodable {
    var version: String?
    var kind: [String]?
    var dimensions: Dimensions?
    var puzzle: [[GridCell]]?
    var solution: [[GridCell]]?
    var clues: [String: [ClueData]]?
    var title: String?
    var author: String?
    var copyright: String?
    var intro: String?
    var notes: String?
    var showEnumerations: Bool?
}

struct Dimensions: Decodable {
    var width: Int?
    var height: Int?
}

struct Clue {
    var number: String?
    var label: String?
    var direction: String
    var text: String
    var answer: String?
    var enumeration: String?
    var continued: [CrossReference]?
}

extension Clue {
    init?(from clueData: ClueData, direction: String) {
        self.direction = direction
        switch clueData {
        case .string(let clueText):
            self.number = nil
            self.text = clueText
            self.answer = nil
            self.enumeration = nil
        case .numberedClue(let clueNum, let clueText):
            self.number = clueNum.toString()
            self.text = clueText
            self.answer = nil
            self.enumeration = nil
        case .clueDict(let clueDict):
            guard let clueText = clueDict.clue else { return nil }
            self.answer = clueDict.answer
            self.enumeration = clueDict.enumeration
            self.text = clueText
            // Handle continued clues
            self.continued = clueDict.continued
            // Updated number/label logic
            if let clueNum = clueDict.number {
                self.number = clueNum.toString()
                self.label = clueDict.label
            } else if let clueNums = clueDict.numbers, !clueNums.isEmpty {
                self.number = clueNums.map { $0.toString() }.joined(separator: ", ")
                self.label = clueDict.label
            } else {
                self.label = clueDict.label
                self.number = nil
            }
        }
    }
}

enum ClueData: Decodable {
    case string(String)
    case numberedClue(ClueNum, String)
    case clueDict(ClueDict)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as String
        if let clueString = try? container.decode(String.self) {
            self = .string(clueString)
            return
        }
        
        // Try to decode as [ClueNum, String]
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            if let clueNum = try? unkeyedContainer.decode(ClueNum.self),
               let clueText = try? unkeyedContainer.decode(String.self) {
                self = .numberedClue(clueNum, clueText)
                return
            }
        }
        
        // Try to decode as ClueDict
        if let clueDict = try? container.decode(ClueDict.self) {
            self = .clueDict(clueDict)
            return
        }
        
        throw DecodingError.typeMismatch(ClueData.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode ClueData"))
    }
}

enum ClueNum: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else {
            throw DecodingError.typeMismatch(ClueNum.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }

    func toString() -> String {
        switch self {
        case .int(let intVal):
            return String(intVal)
        case .string(let strVal):
            return strVal
        }
    }

    func toInt() -> Int? {
        switch self {
        case .int(let intVal):
            return intVal
        case .string(let strVal):
            return Int(strVal)  // Returns nil if string can't be converted to Int
        }
    }
}

struct ClueDict: Decodable {
    var number: ClueNum?
    var numbers: [ClueNum]?
    var label: String?
    var cells: [[Int]]?
    var clue: String?
    var hints: [String]?
    var image: String?
    var answer: String?
    var enumeration: String?
    var continued: [CrossReference]?
    var references: [CrossReference]?
    var type: String?
    var explanation: String?
    var tags: [String]?
    var highlight: Bool?
    var location: [Int]?
}

struct CrossReference: Decodable {
    var direction: String?
    var number: ClueNum?
}

// Updated to handle both puzzle and solution grids
enum GridCell: Decodable {
    case null
    case string(String)
    case dict(GridCellDict)
    case number(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
            return
        }
        
        // Try decoding in order: Int, String, Dictionary
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let strValue = try? container.decode(String.self) {
            self = .string(strValue)
        } else if let dictValue = try? container.decode(GridCellDict.self) {
            self = .dict(dictValue)
        } else {
            throw DecodingError.typeMismatch(
                GridCell.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected null, number, string, or dictionary for GridCell"
                )
            )
        }
    }

    func stringValue() -> String? {
        switch self {
        case .null:
            return nil
        case .string(let str):
            return str
        case .number(let num):
            return String(num)
        case .dict(let dict):
            return dict.cellValue
        }
    }

    var style: StyleSpec? {
        switch self {
        case .dict(let cellDict):
            return cellDict.style
        case .string, .number, .null:
            return nil
        }
    }

    /// Attempts to convert the grid cell value to an Int.
    func toInt() -> Int? {
        switch self {
        case .null:
            return nil
        case .string(let str):
            return Int(str)
        case .number(let num):
            return num
        case .dict(let dict):
            if let cell = dict.cell {
                return cell.toInt()
            }
            return nil
        }
    }
}

struct GridCellDict: Decodable {
    // For "puzzle" grid cells
    var cell: ClueNum?
    var style: StyleSpec?
    var value: String? // For "solution" grid cells
    var direction: [String: GridCell]?
    var empty: String?
    var block: String?
    var given: String?

    // Extract the appropriate value for the grid cell
    var cellValue: String? {
        // Try "value" first (used in "solution" grid)
        if let val = value {
            return val
        }
        // Try "given" (used in some puzzle types)
        if let givenVal = given {
            return givenVal
        }
        // Try "cell" (used for labels/clue numbers)
        if let cellNum = cell?.toString() {
            return cellNum
        }
        // If none of the above, return empty string or block
        if let emptyVal = empty {
            return emptyVal
        }
        if let blockVal = block {
            return blockVal
        }
        // You can add more logic here if needed
        return nil
    }
}

enum StyleSpec: Decodable {
    case dict([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: String].self) {
            self = .dict(dict)
            return
        }
        throw DecodingError.typeMismatch(StyleSpec.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode StyleSpec"))
    }
}

// MARK: - Example Usage

// Assuming you have a valid .ipuz file at the specified path
// let puzzle = IPuzPuzzle(filePath: "/path/to/your/puzzle.ipuz")
