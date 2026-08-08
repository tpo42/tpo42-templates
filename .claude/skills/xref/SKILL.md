---
name: xref
description: Write AsciiDoc cross-references that survive both tpo42 compile units. Resolves where an anchor is actually defined instead of inferring it from an identifier scheme.
argument-hint: <anchor> [anchor ...] [--list] [--comma] [--label "Text"]
user-invocable: true
---

# /xref — cross-references that survive both compile units

## Why this is not simply `<<anchor>>`

`arc42.adoc` and `req42.adoc` are separate compile units — `docToolchainConfig.groovy` lists both
under `inputFiles`. An anchor resolves only inside the document that defines it.

Most text never notices, because it belongs to exactly one document. Shared text does: a tagged
region lives in a req42 chapter and is converted a second time as part of arc42. A plain
`<<anchor>>` there links correctly in one document and dangles in the other, and the dangling one
fails the quality gate — `adoc-validate` runs at `--failure-level INFO`, where asciidoctor reports
"possible invalid reference".

Each document names itself for this purpose. `arc42.adoc` sets `:is-arc42:`, `req42.adoc` sets
`:is-req42:`, and shared text asks one binary question: *am I being converted in the unit from which
this anchor is reachable?*

That question is all this skill answers, which is why it does not care how many frameworks exist.
arc42 and req42 are two; ops42 and biz42 are coming; acp42 is being worked on elsewhere. None of
them needs a line here — a document named `<prefix>42-…adoc` sets `:is-<prefix>42:`, and the
question stays the same.

## What this skill refuses to assume

tpo42 prescribes no identifier scheme. A project may carry the element type in a prefix, as an
infix, or not at all — that decision belongs to the architect or product owner, and narrowing it
would narrow the audience.

So this skill never infers the owning document from the shape of an identifier. It looks the anchor
up. A scheme-based variant is a reasonable thing for a *project* to write once its own scheme is
settled; this one has to work before that.

## The two facts

Everything follows from a pair of questions, and neither may be guessed:

1. **Which compile unit is being edited?** Derive it from the path of the file being written. Take
   the shortest prefix of the file name that ends in `42` — `(.+?42).*\.adoc` — and the attribute is
   `is-` followed by that prefix. Chapter files carry the same prefix in their directory
   (`{prefix}-chapters/`).

   ```
   arc42.adoc                    → is-arc42
   arc42-meta-prd-flash.adoc     → is-arc42
   req42-xodos-full.adoc         → is-req42
   ops42-boreas.adoc             → is-ops42
   ```

   The rule is deliberately not a list of known frameworks. A framework added later needs no change
   here, as long as its main document sets the matching attribute in its header.

   Real projects rarely keep the template's bare `arc42.adoc`: main documents are named
   `{prefix}-<component>[-<variant>].adoc` so that PDFs and HTML trees generated from several
   components do not collide. A component may also own more than one document per framework —
   `req42-xodos.adoc` and `req42-xodos-full.adoc` are two compile units, and an anchor defined in
   both resolves in both.

   `inputFiles` in `docToolchainConfig.groovy` is the authority when a name does not fit the shape.
   If the caller states the unit, believe them over the path.

2. **Which compile unit defines the target anchor?** Look it up. Search the tracked `.adoc` files for
   `[[the-anchor]]` on its own line or `[#the-anchor]` as a block attribute, then apply the same
   path-to-unit mapping to whatever file defines it.

## Deciding from the pair

First, a case that overrides both: if the anchor's definition sits between a `//tag::name[]` and its
`//end::name[]`, and some file includes that tag, the anchor is carried into the other unit too. It
resolves on both sides, so a plain `<<anchor>>` is correct everywhere. Say so instead of emitting a
conditional.

Otherwise emit the pair, keyed on the unit that **defines** the anchor — never on the one being
edited. That is the whole trick: the link appears where it can resolve, and readable prose appears
everywhere else. It is correct whichever direction the reference runs, and whichever document ends
up including the passage.

Do not reason about which document "will never" convert a passage. Which content is shared, and in
which direction, is the author's composition — a req42 variant may well include arc42 components,
and tpo42 has no business deciding otherwise. The pair costs two lines and survives an include that
did not exist when the sentence was written.

A bare `<<anchor>>` remains the better choice for text you are confident stays where it is: it is
shorter and reads more clearly. That confidence is the exception, not the default. When in doubt,
write the pair.

## Output

Two lines per reference, each directive starting at column 0:

```asciidoc
ifdef::is-req42[(→ <<section-backlog>>)]
ifndef::is-req42[(→ req42 chapter 11, Roadmap & Backlog)]
```

- The attribute names the unit that **defines** the anchor, not the one being written.
- The `ifdef` branch carries the link; the `ifndef` branch carries a human-readable fallback that
  names the document, because a reader of the other document cannot follow anything.
- Punctuation and markup belong **inside** the brackets — list markers at the front, commas at the
  end. `ifdef::is-req42[* <<x>>]`, not `* ifdef::is-req42[<<x>>]`.
- Separate consecutive pairs with a blank line.
- In a table cell, put `a|` on its own line and the pair beneath it.

## Modifiers

| Modifier         | Effect                                                                      |
| ---------------- | --------------------------------------------------------------------------- |
| `--list`         | render each reference as an unordered list item, marker inside the brackets |
| `--comma`        | trailing comma inside both branches, for enumerations in running text       |
| `--label "Text"` | replace the fallback text of a single reference                             |

## Errors

- **Anchor not found** — report it rather than guessing a plausible pair. An invented anchor fails
  the gate later and reads as if it had been verified.
- **Anchor defined more than once** — report every location. Duplicate ids are a defect in their own
  right; asciidoctor keeps the first and silently drops the rest.
- **`--label` with several anchors** — a custom fallback only makes sense for one.

## Derive your own rather than growing this one

This is the base variant, and it is deliberately narrow: two facts, one binary question, no
dependencies. Every setting that needs more should **derive a variant and describe it**, not extend
this one until it fits nobody.

The cases below are the ones met so far, not a closed list — documentation is written in more ways
than any of us has seen. If you derive a variant for a situation that is missing here, sharing it
back improves this skill for the next person.

- **You import the anchor as well.** If your composition pulls the target's definition into the
  document doing the referencing, the anchor resolves there and no conditional is needed. That is a
  property of your composition, not of tpo42 — describe it in your own variant.
- **Your project has settled on an identifier scheme.** Then a variant may read the owning unit off
  the identifier instead of searching for it, which is faster and catches typos. Delphin does this
  with a prefix table.
- **Resolution needs a tool.** Once `dacli` is broadly available, a variant can ask it for the
  structure instead of grepping, and answer questions this one cannot — such as which documents
  transitively include a fragment.
- **The target is not in the repository at all.** Document-management systems, published sites,
  ticket trackers. Such a variant needs to know its source and how to look things up there; how that
  is reached is a question for whoever runs it.

Keep the derived variant's name distinct and say in its description what it assumes. A skill that
silently assumes more than it says is worse than no skill.

## Worked example

`req42-chapters/07_constraints.adoc` carries this inside the `organizational_constraints` region,
which `arc42-chapters/02_architecture_constraints.adoc` includes:

```asciidoc
Timeline Constraints:: _<Project deadlines, milestone requirements>_
ifdef::is-req42[(→ <<section-backlog>>)]
ifndef::is-req42[(→ req42 chapter 11, Roadmap & Backlog)]
```

req42 renders `<a href="#section-backlog">Roadmap &amp; Backlog</a>`; arc42 renders the same
sentence as plain text. Neither produces a warning.
