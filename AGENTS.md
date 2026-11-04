# Working on AstraGlass

Read `docs/STATUS.md` first. It is the compact handoff for continuing work in a new chat.

- Continue this repository; do not start another implementation in AstrologMac.
- Keep chat output short: summarize findings, limit command output, and read only relevant files.
- Complete one coherent milestone, validate it, then update STATUS before moving on.
- Record decisions, remaining work, exact commands and blockers in STATUS rather than relying on chat history.
- Update STATUS before ending the turn and after a meaningful checkpoint. Keep it under 100 lines.
- The user's target is a native macOS 27 app with Liquid Glass, Astrolog 8.0 calculations, local Podvodny interpretations, measured CPU/memory use, and public GitHub source.
- Do not claim full Astrolog parity: `docs/FEATURES.md` records the current boundaries.
- Keep `PrivateCorpus/`, `Resources/interpretations.json`, source books, personal chart files and personal distributions out of public Git history and release assets.
- Public package: `bash scripts/package.sh --public`. Personal package: `bash scripts/package.sh --with-corpus`.
- Use the actual engine for regression checks. Preserve measurement methodology and distinguish GUI memory from subprocess/harness memory.
- Do not spawn agents unless explicitly requested.
