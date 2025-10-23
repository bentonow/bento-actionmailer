# Repository Guidelines

## Project Structure & Module Organization
- `lib/` hosts the gem; `lib/bento_actionmailer.rb` loads the delivery method defined under `lib/bento_actionmailer/`.
- `bin/setup` and `bin/console` live in `bin/` for bootstrapping and interactive debugging.
- `test/` contains Minitest suites with helpers in `test/test_helper.rb`; follow the `test_*.rb` naming.
- `sig/` mirrors public APIs with RBS types; update alongside code. `art/` keeps documentation assets lightweight.

## Build, Test, and Development Commands
- `bin/setup` runs Bundler install on fresh environments.
- `bundle exec rake` triggers the default pipeline (tests + RuboCop); run before opening a PR.
- `bundle exec rake test` gives a fast Minitest loop for focused iterations.
- `bundle exec rubocop [-a]` checks style; review auto-fixes before committing.
- `bin/console` loads the gem in IRB for manual delivery experiments against stubbed endpoints.

## Coding Style & Naming Conventions
- Follow RuboCop: Ruby 2.6 target, double-quoted strings, and 120-character lines.
- Use idiomatic casing (`snake_case` methods, `SCREAMING_SNAKE_CASE` constants, CamelCase types).
- Keep `# frozen_string_literal: true` atop Ruby files and favor immutable literals.
- Document HTTP side effects and raise specific delivery errors for clarity.

## Testing Guidelines
- Place tests in `test/**/test_*.rb` with `SomethingTest` classes and `test_` methods.
- Reuse `test/test_helper.rb` for shared setup, mocks, and requires.
- Replace the placeholder failure in `test/bento/test_actionmailer.rb` with behavior-driven assertions.
- Guard edge cases (missing HTML body, auth keys) and ensure `bundle exec rake` passes before pushing.

## Commit & Pull Request Guidelines
- Write concise, imperative subjects (`Feat: Add delivery retries`, `Fix: Guard nil recipients`) ≤72 characters.
- Link issues and describe scope, risks, and validation steps in the body.
- PRs should outline changes, note test runs (`bundle exec rake`), and attach screenshots/logs when relevant.
- Update docs or `sig/` files with API shifts; highlight breaking changes early.

## Security & Configuration Tips
- Keep API keys out of git; load via ENV and scrub them from fixtures.
- Stub remote HTTP in tests to keep runs deterministic and offline-friendly.
