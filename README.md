# sdls - Synology Download Station CLI

`sdls` is a command-line interface for adding download tasks to Synology Download Station using magnet links. It provides a simple, scriptable way to queue downloads from your terminal, including integration with 1Password for 2FA.

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

Configure via `~/.config/sdls.yml`:

```yml
host: http://nas.local:5000
username: username
password: password
op_item_name: NameOf1PasswordItem
directories:
  - NAS/01_documents
  - NAS/02_archive
```

Note: Set `SDLS_CONFIG_PATH` to customize the config path.

## Development

Run `bin/sdls` to execute the CLI.

Run `just test` to lint and test.

## Releasing a new version

On the main branch, add the changes to `CHANGELOG.md` and stage it.

Then, tag the new version:

```rb
git commit -am "Release v0.1.0"
git tag v0.1.0
git push origin main --tags
```

Then, create a [new release](https://github.com/visini/sdls/releases/new) and choose the tag (e.g., `v0.1.0`) and title (e.g., `v0.1.0`). Copy the description from `CHANGELOG.md`.

Finally, run `gem release`.
