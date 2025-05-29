# sdl - Synology Download Station CLI

## Configuration

Configure via `~/.config/sdl.yml`:

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

Run `bin/sdl` to execute the CLI.

Run `just test` to lint and test.
