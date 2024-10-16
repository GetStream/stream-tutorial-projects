import Foundation
import PencilKit

enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil
    case pen
    case monoline
    case fountain
    case marker
    case crayon
    case watercolor
    case eraser
    case ruler
    case undo
    case redo
    case cut

    var id: String { self.rawValue }

    var symbolName: String {
        switch self {
        case .pencil:
            return "pencil"
        case .pen:
            return "pen.tip"
        case .monoline:
            return "line.horizontal"
        case .fountain:
            return "fountainpen.tip"
        case .marker:
            return "highlighter"
        case .crayon:
            return "paintbrush"
        case .watercolor:
            return "drop"
        case .eraser:
            return "eraser"
        case .ruler:
            return "ruler"
        case .undo:
            return "arrow.uturn.left"
        case .redo:
            return "arrow.uturn.right"
        case .cut:
            return "scissors"
        }
    }

    var toolType: PKInkingTool.InkType? {
        switch self {
        case .pencil:
            return .pencil
        case .pen:
            return .pen
        case .monoline:
            return .marker
        case .fountain:
            return .fountainPen
        case .marker:
            return .marker
        case .crayon:
            return nil // Custom implementation needed
        case .watercolor:
            return nil // Custom implementation needed
        default:
            return nil
        }
    }

    var isCustomTool: Bool {
        return self == .crayon || self == .watercolor
    }
}
