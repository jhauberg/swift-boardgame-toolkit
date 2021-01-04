# swift-boardgame-toolkit

A framework for modeling, prototyping and simulating boardgames.

| [Latest release (0.3.0)](releases/tag/0.3.0) | Download the latest stable release.                 |
| :------------------------------------------- | :-------------------------------------------------- |
| [Issue tracker](issues)                      | Contribute your bugs, comments or feature requests. |

# Features

 * Layout and design components in a declarative <abbr title="Domain-specific language">DSL</abbr>
 * Author print-and-play distributions automatically, in many configurations
 * Model your game to easily simulate and test game state scenarios

Here's a bite-sized example to whet your appetite:

```swift
let cards = [
    Component(width: 2.5.inches, height: 3.5.inches) { parts in
        Box(covering: parts.full)
            .border("black", width: 0.25.inches)
        Text("Adventurer")
            .top(parts.safe.top)
            .left(parts.safe.left)
    }
]

try Sheet().document(
    target: .pdf(to: URL(fileURLWithPath: "output.pdf")),
    configuration: .portrait(on: .a4, arranging: [
        Layout(cards, method: .natural(orderedBy: .skippingBacks)),
    ])
)
```

# Motivation

What if I told you that you should **ditch your spreadsheets** and **design tools** to instead **work entirely in code**?

Don't buy that premise? Then `swift-boardgame-toolkit` is probably not for you. Otherwise, read on.

...

Still here? Cool. Now, _"entirely in code"_ is of course a bit on the nose. There's nothing wrong with keeping spreadsheets or using graphical design tools to create amazing art. However, there _are_, without question, very real benefits to using a sound programming language to "build" your game:

 * Easy version control and better collaboration because of it
 * Confidence to make changes; tests and compilation will point out issues immediately
 * Formal definition of "how to build" your game

The benefits might be more obvious if you're already a programmer, but i'm sure others can relate to the dread one might feel when _something_ changed in your spreadsheet, but you're not sure what, and suddenly every cell is erroring out.

This is similar in regard to layout; with a declarative approach you can be confident that elements are laid out as intended, because it is _formally_ and _exactly_ described how to. A slip of the mouse in a graphics tool could move stuff around unintentionally and not be noticed until it's too late.

This is not a novel idea, and `swift-boardgame-toolkit` shares many similarities with tools like [nanDeck](http://www.nandeck.com) and [Squib](https://github.com/andymeneely/squib). 

Though the thoughts behind this implementation might go a bit further, it all boils down to act as a sort-of glorified build script; define and model all parts of your game, simulate scenarios to validate game/balance and finally design and layout the physical components and arrange them on printable pages for human playtesting.


# Installation

`swift-boardgame-toolkit` requires Swift 5.3 or later.

## Swift Package Manager

Add `swift-boardgame-toolkit` as a package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/jhauberg/swift-boardgame-toolkit.git", from: "0.3.0")
]
```

Then, for any target, add `BoardgameKit` as a named dependency:

```swift
.target(
    name: "my-target",
    dependencies: ["BoardgameKit"]
)
```

# Learn More

 * Read the Documentation (_not available yet_)
 * Try the [Examples](tree/main/Examples)
 * Join the [Discussion](discussions)

<br />

<table>
  <tr>
    <td>
      This is a Free and Open-Source Software project released under the <a href="LICENSE">MIT License</a>.
    </td>
  </tr>
</table>
