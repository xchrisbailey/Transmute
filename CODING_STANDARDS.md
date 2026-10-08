# Coding standards

Rules a reviewer applies to a diff. Each one is a judgement call that no build step checks; SwiftLint and swift-format own the rest. The coder instructions in `.claude/agents/coder.md` cover how to work; this file covers what the result should look like.

## Domain language

Names, comments, test names, and on-screen text use the terms in `GLOSSARY.md` once it exists. A word on a term's _Avoid_ list is a finding when it stands for that term, and fine when it means something else.

## On-screen text

- Every string a person reads comes from `Copy` in TransmuteUI, backed by a key in `Apps/Shared/Localizable.xcstrings`. A string literal passed straight to a view is a finding.
- A key starts with `voice.` or `plain.`. `voice.` is for the alchemy verbs of the brand. `plain.` is for anything read mid-set or on the watch, and for errors, deletes, and Health.

## Model and storage

- Code outside the model layer names a model by its alias in `Model/Schema.swift` (`Workout`, `PlanDay`), not `SchemaV1.Workout`.
- A new model attribute is optional or has a default. CloudKit requires it, and nothing fails locally when it is missing.
- Until the first TestFlight build (#20), a new defaulted attribute goes onto the `SchemaV1` model in place. After that, a model change needs a new schema version and a stage in `TransmuteMigrationPlan`.
- Values are stored metric and converted at the edges through `Units`. A stored pound, inch, or mile is a finding.

## Mirrored sessions

The device that starts a workout owns it and is the only one that writes it. The other device shows the owner's `SessionSnapshot` and sends a `SessionCommand` back. A change that saves the workout from the mirroring device is a finding: iCloud sync would turn it into a duplicate.
