# Teaching method

Teach explains the real thing the builder made. The page should leave a non-developer able to describe what it does, follow how it works, and understand the technical words they will see when they return to the build.

## 1. What did I build?

Start with the outcome, not the implementation.

Explain:

- what now exists
- who it is for
- what problem it solves
- what a person can do now that they could not do before
- which details are confirmed by the chat or code, and which are inferred

Use the builder's actual product language. Do not turn this section into a list of files or frameworks.

## 2. How does it work?

Choose one real user action, request, message, object, or piece of information and trace it from start to finish.

At every step answer:

- What has just happened?
- Which real part of the build receives it?
- What does that part decide, change, remember, or send?
- Where does it go next?
- What does the user see because of it?

Use the actual components, routes, events, state, fields, and data shapes when they matter. Clearly distinguish verified behavior from a reasonable inference.

## 3. Name the actual tech stack

Give the learner a compact map of the real technologies used in this build. For each one, explain:

- what it is in ordinary language
- where it runs
- why this build uses it
- the one responsibility it owns
- what it receives from and sends to the other parts

Cover the interface, frontend, backend, database, state, function calls, APIs, authentication, and hosting when they exist. Do not force every build into those layers. If the build has no separate backend or database, say so.

A brand name is not an explanation. “This uses Convex” must be followed by what Convex stores or runs here and how information reaches it. When a function call is important, show the caller, the information going in, the work performed, the result, and the next destination.

## 4. Show the moving parts

Give each important part one responsibility in plain English. Then show how the parts connect. Prefer a small accurate model over an exhaustive architecture dump.

Build the explanation at three depths:

1. **What you built:** the useful outcome and experience
2. **How it works:** the complete cause-and-effect path
3. **Under the hood:** the real implementation details worth recognizing

The learner can stop after any depth and still leave with a coherent explanation.

## 5. Make the invisible visible

Choose the visual from the behavior:

- **Flow:** a request or object moves through ordered steps
- **Layers:** responsibilities sit on top of one another
- **Comparison:** two approaches or states differ in meaningful ways
- **Timeline:** state changes over time
- **Map:** parts communicate in more than one direction

Each clickable state must explain a real change or responsibility, not merely change color. At least one visual must show the complete end-to-end path.

Keep diagrams clean, classy, and minimal:

- show only the parts needed for the current idea
- prefer 3 to 7 well-spaced nodes over an exhaustive architecture chart
- use short labels and place explanations in the selected detail panel
- use a neutral base with one accent for the active path
- keep connector directions obvious and avoid crossing lines
- use icons or decoration only when they carry meaning
- make the diagram readable on a phone without pinching or sideways scrolling

## 6. Define every technical word

Keep a jargon inventory while writing. A jargon word is any term a thoughtful non-developer might have to leave the page to look up: component names, frameworks, protocols, data terms, file types, architecture terms, commands, and abbreviations.

For every jargon term used in visible lesson copy:

- add one entry to `concepts`
- define it in ordinary language
- explain exactly what it does or means in this build
- add common visible variants to `aliases`

The HTML turns these terms into Kindle-style dotted-underlined definitions. The learner can hover, focus, or tap a term to read its meaning without losing their place. The dictionary at the end contains the same complete set.

If a term does not help the learner understand their build, remove the term instead of defining it.

## 7. Use analogies as a bridge

An analogy is useful when it makes a hard mechanism easier to picture, but the lesson must return to the real system.

Every analogy needs:

- the familiar situation
- a direct mapping from familiar parts to real parts
- a brief note about where the comparison stops being accurate

Avoid analogies that are longer than the concept or hide important behavior.

## 8. Let people break it

Use the playground to compare a normal path with one or two realistic failure paths from the build. Explain what the person sees, what the system does, and which part owns the recovery.

## 9. Quiz for understanding

Ask what would happen in a realistic scenario. Avoid definition recall. After each choice, explain why it works or what part of the mental model to revisit. Use 3 to 5 questions.

Score copy:

- Full score: “you can explain this system now”
- Partial score: “you have the shape of it. try the questions from another angle”
- Low score: “the system is still new. revisit the moving diagram, then try again”

Never use failure language, countdowns, streaks, leaderboards, or social comparison.

## Final clarity check

Before building the page, verify:

- A non-developer can say what was built in two sentences.
- One visual traces how it works from user action to visible result.
- The actual technologies are named, and each one's role and connections are explained.
- Any important function call shows what goes in, what happens, and what comes out.
- Important parts have one clear responsibility each.
- Every technical word used is in the jargon dictionary.
- Each dictionary entry explains the term generally and in this build.
- Tooltips work with hover, keyboard focus, and tap.
- The quiz tests how the system behaves, not vocabulary.
