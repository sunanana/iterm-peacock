# Contributing

```zsh
make setup   # install what the tests need
make help    # list every target
```

## Where the documentation lives

`_usage` and the `_help_*` functions in `bin/iterm-peacock` are the source of truth for
the `.peacock` format, the keys, the picker and the environment variables. They always
match the version a user has installed, so none of it is copied into the README. When
the behavior changes, change the help text.
