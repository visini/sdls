# sdls - Synology Download Station CLI

`sdls` is a command-line interface for adding download tasks to Synology Download Station using magnet links. It provides a simple, scriptable way to queue downloads from your terminal, including an (optional) integration with 1Password for authentication (including 2FA).

## Installation

`gem install sdls`

## Usage

```bash
❯ sdls
Commands:
  sdls add [MAGNET]    # Add a magnet link to Synology Download Station
  sdls config          # Display the current configuration
  sdls connect         # Verify connectivity and authentication
  sdls help [COMMAND]  # Describe available commands or one specific command
  sdls version         # Display the SDLS tool version
```

## Configuration

Configure via `~/.config/sdls.yml`.

You may rely on the 1Password integration (this will read the credentials from the 1Password item):

```yml
host: http://nas.local:5000
op_item_name: NameOf1PasswordItem
directories:
  - NAS/01_documents
  - NAS/02_archive
```

Or, specify username and password manually:

```yml
host: http://nas.local:5000
username: username
password: password
directories:
  - NAS/01_documents
  - NAS/02_archive
```

Note: Set `SDLS_CONFIG_PATH` to customize the config path.

## Development

Run `bin/sdls` to execute the CLI.

Run `just test` to lint and test.

## Releasing a new version

On the main branch, add the changes to `CHANGELOG.md`. Use the format:

```md
## [x.y.z] - YYYY-MM-DD

### Added

- commit_hash PR title #PR_number
```

Then, bump the version in `version.rb` and `sdls.gemspec`.

Then, run `bundle`, which will update `Gemfile.lock`.

With these four changed and staged files, tag the new version:

```rb
git commit -m "Release v0.1.0"
git tag v0.1.0
git push origin main --tags
```

Then, create a [new release](https://github.com/visini/sdls/releases/new) and choose the tag (e.g., `v0.1.0`) and title (e.g., `v0.1.0`). Copy the description from `CHANGELOG.md`. Do not use the button "Generate release notes" to automatically populate the description.

Finally, run `gem release`.
