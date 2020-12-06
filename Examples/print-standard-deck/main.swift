/**
 Example program to generate a 52-card deck of French-suited playing cards.

 See https://en.wikipedia.org/wiki/Standard_52-card_deck

 This program demonstrates basic use of common visual features and layout.

 Running the program will produce an A4, portrait-oriented, PDF-document with 52 cards
 (each measuring 2.5x3.5 inches), laid out left-to-right, with 3x3 cards per page.

 As an exercise, try adding Jokers to the deck.

 There's typically only two Jokers in a standard deck of cards, and it just so happens that
 this is also the exact number of slots we have left on the final page- but you can add however
 many you want.

 Jokers should have their own design to be easily dinstinguishable from ranked cards.
 */

import Foundation
import BoardgameKit

enum Suit: String, CaseIterable {
    case clubs = "♣"
    case diamonds = "♦"
    case hearts = "♥"
    case spades = "♠"

    var color: String {
        switch self {
        case .clubs,
             .spades:
            return "black"
        case .diamonds,
             .hearts:
            return "red"
        }
    }
}

let suits = Suit.allCases
let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

// define a function to compose a card
func card(_ suit: Suit, _ rank: String) -> Component {
    // note that we remove any bleed to allow fitting more cards per page
    return Component(width: 2.5.inches, height: 3.5.inches, bleed: 0.inches) { parts in
        // define an area inside the safe zone, inset by a small distance
        let innerFrameArea = Area(inset: 1.millimeters, in: parts.safe)

        // frame the safe area with a slight, solid black border
        Box(covering: innerFrameArea)
            .border("black", width: 0.5.millimeters)

        // top-left rank
        // aligned against the top-left corner of the safe area
        // note that we intentionally do not inset this to match the frame, as we want it
        // "sticking out" slightly, for a more pleasing look
        Text(rank)
            .font(size: 40.points, name: "serif")
            .color(suit.color)
            .background("white")
            .top(parts.safe.top)
            .left(parts.safe.left)
        // bottom-right rank, flipped vertically
        Text(rank)
            .font(size: 40.points, name: "serif")
            .color(suit.color)
            .background("white")
            .bottom(parts.safe.bottom)
            .right(parts.safe.right)
            // flip it vertically
            .turn(180.degrees)

        // suit, centered and only one orientation
        Text(suit.rawValue)
            .font(size: 96.points, name: "serif")
            .color(suit.color)
            .width(parts.safe.extent.width, height: parts.safe.extent.height)
            .top(parts.safe.top)
            .left(parts.safe.left)
            .align(horizontally: .center)
            .align(vertically: .middle)
    }
}

let cards = suits.flatMap { suit in
    ranks.map { rank in
        card(suit, rank)
    }
}

// initialize a sheet to arrange all of our cards
let sheet = Sheet()
// define location to save our finished document
let url = URL(fileURLWithPath: "standard-deck.A4.pdf")
// save the sheet as a pdf on A4 paper, portrait-oriented,
// arranging cards in a natural, left-to-right order
// this should fit 3x3 cards on every page
try sheet.document(
    type: .pdf(to: pdfUrl),
    configuration: .portrait(on: .a4, arranging: [
        // note that we don't need to explicitly specify to skip backs in this case,
        // as we have not actually composed any backsides
        Layout(cards, method: .natural(orderedBy: .skippingBacks))
    ])
)
// if all went well, the pdf should now be located at the printed path
print("saved at \(url.path)")
