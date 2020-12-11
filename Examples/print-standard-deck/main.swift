/**
 Example program to generate a 52-card deck of French-suited playing cards.

 See https://en.wikipedia.org/wiki/Standard_52-card_deck

 This program demonstrates basic use of common visual features and layout.

 Running the program will produce two outputs:

  1) an A4, portrait-oriented, PDF-document with 52 cards (each measuring 2.5x3.5 inches),
     laid out left-to-right, with 3x3 cards per page - no card backs
  2) same as 1), except including card backs, laid out for duplex printing

 As an exercise, try adding Jokers to the deck.

 There's typically only two Jokers in a standard deck of cards, and it just so happens that
 this is also the exact number of slots we have left on the final page- but you can add however
 many you want.

 Jokers should have their own design to be easily dinstinguishable from ranked cards.
 However, they should also share the same back as the ranked cards.
 */

import BoardgameKit
import Foundation

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
    // note that we only add a very slight bleed to allow fitting more cards per page
    // if we were not interested in producing backs at all (_and_ our front design allowed for it),
    // we could eliminate the bleed entirely (e.g. `.zero`) for more efficient cuts
    Component(width: 2.5.inches, height: 3.5.inches, bleed: 1.millimeters) { parts in
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
    }.backside { parts in
        // the freeform feature allows you to put in any arbitrary HTML/CSS;
        // the custom code is wrapped by a surrounding <div> that conforms to typical Feature
        // properties, such as positioning and sizing
        Freeform(
            // here we make use of a cool CSS feature allowing for easily making a striped background
            """
            <style>
            .striped {
                background: repeating-linear-gradient(
                  45deg,
                  #606dbc,
                  #606dbc 10px,
                  #465298 10px,
                  #465298 20px
                );
            }
            </style>
            <!--
               note that our custom styled div does not have any intrinsically-sized content,
               so dimensions must be specified to take up the space we want to fill (all of it)
               this also requires the Freeform feature itself to have an explicit width and height
              -->
            <div class=\"striped\" style=\"width: 100%; height: 100%;\"></div>
            """
        )
            .width(parts.full.extent.width)
            .height(parts.full.extent.height)
            // note the omission of any insets (e.g. top/left); these are not required if you
            // don't want to position the feature and simply want it to originate from its default
            // (which happens to be top/left corner of the component)

            // technically, setting both top and left to `0.inches` would produce the same result
            // however, setting bottom and right to `0.inches` would instead make the feature
            // originate from the bottom right corner; you can sometimes use this to your advantage
            // depending on your designs and layouts

            // additionally, and important to keep in mind, feature insets are directionally
            // mutually-exclusive; this means that a feature can not have both a left and a
            // right inset; only the last set inset would apply; same goes for top/bottom
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
let url = URL( // "simplex" is just another word for "single-sided printing"
    fileURLWithPath: "standard-deck.A4.simplex.pdf")
// save the sheet as a pdf on A4 paper, portrait-oriented,
// arranging cards in a natural, left-to-right order
// this should fit 3x3 cards on every page
try sheet.document(
    target: .pdf(to: url),
    configuration: .portrait(on: .a4, arranging: [
        // note that we explicitly skip backs for this target
        Layout(cards, method: .natural(orderedBy: .skippingBacks)),
    ])
)

try sheet.document(
    // similarly to "simplex", "duplex" just means "double-sided printing"
    target: .pdf(to: URL(fileURLWithPath: "standard-deck.A4.duplex.pdf")),
    configuration: .portrait(on: .a4, arranging: [
        Layout(cards, method: .duplex()),
    ])
)

// if all went well, the pdf should now be located at the printed path
print("saved at \(url.path)")
