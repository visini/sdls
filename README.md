# sdls - Synology Download Station CLI

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

## Development

Run `bin/sdls` to execute the CLI.

Run `just test` to lint and test.

## Releasing a new version

First, tag the new version:

```rb
git commit -am "Release v0.1.0"
git tag v0.1.0
git push origin main --tags
```

Then, create a [new release](https://github.com/visini/sdls/releases/new) and choose the tag (e.g., `v0.1.0`) and title (e.g., `v0.1.0`). Copy the description from `CHANGELOG.md`.
