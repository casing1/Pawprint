# Language packs

Flat `key: template` JSON, one file per language. `ko.json` is the base: every other pack falls
back to it key by key, so a partial translation degrades to Korean rather than showing raw keys.

## Adding a language

1. Copy `ko.json` to `<code>.json` and translate the values, leaving the keys alone.
2. Add the code to `AppLanguage` and `AppLanguage.availableCodes` in
   `Sources/Pawprint/Utilities/Localization.swift`.

That's it — no Xcode, no rebuild of anything but the app itself.

## Templates

`%@` placeholders are filled positionally by `L10n.t`. **Keep the same number of `%@` as the
Korean**, in whatever order the target language needs — arguments are substituted left to right,
so reordering the sentence around them is fine but adding or dropping one is not.

A dozen keys are passed to `String(format:)` instead and use real printf verbs (`%.1f`, `%%`).
`scripts/extract_strings.py` can tell you which:

```bash
grep -rn 'String(format: L10n.t(' Sources/Pawprint
```

Everywhere else `%` is a literal percent sign — do not double it.

## Keys

`<file>.<sha1 of the Korean template, 8 chars>`. Hashing the template means a key survives code
moving between files, and rewording the Korean deliberately produces a *new* key, because a
changed sentence needs a fresh translation anyway.

Regenerate after adding Korean literals to the source:

```bash
python3 scripts/extract_strings.py --apply
```

It rewrites the literals into `L10n.t` calls and merges new keys into `ko.json`. Other packs are
left alone; missing keys simply fall back.

## What a translation can't fix

Some things are structural, not textual, and live in code:

- **Number grouping.** Korean groups by myriads (만 = 10⁴), English by thousands. See
  `LocalizationManager.usesMyriadGrouping`.
- **Object particles.** `Formatters.withObjectParticle` appends 을/를; other languages get nothing.
- **Date and weekday names.** `DateFormatter` follows `LocalizationManager.activeLocale`.
