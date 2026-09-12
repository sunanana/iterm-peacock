# iterm-peacock

Drop a `.peacock` file in a directory and iTerm2 changes its background, text, tab
color and badge as soon as you cd into it. Leave the directory and everything goes
back. A zsh plugin; bash works too.

![iterm-peacock demo](demo.gif)

## Install

### zsh

```zsh
git clone https://github.com/sunanana/iterm-peacock ~/.zsh/iterm-peacock
echo 'source ~/.zsh/iterm-peacock/iterm-peacock.plugin.zsh' >> ~/.zshrc
source ~/.zshrc
```

### bash

```bash
git clone https://github.com/sunanana/iterm-peacock ~/.zsh/iterm-peacock
cat >> ~/.bashrc <<'EOF'
source ~/.zsh/iterm-peacock/iterm-peacock.sh
PROMPT_COMMAND="_peacock_apply${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
EOF
source ~/.bashrc
```

## Usage

```zsh
iterm-peacock
```

## Resolution

The nearest `.peacock` found by walking up from the current directory wins.

```
~/src/
├── .peacock              # background=#2a0d0d
├── api/
│   ├── .peacock          # background=#0d2a1a
│   └── internal/
└── docs/
```

| Current directory | Applied |
| :-- | :-- |
| `~/src` | `~/src/.peacock` |
| `~/src/api` | `~/src/api/.peacock` |
| `~/src/api/internal` | `~/src/api/.peacock` |
| `~/src/docs` | `~/src/.peacock` |
| `~` | none — the profile colors are restored |

## Help

```
iterm-peacock --help
```

## Supported Terminal

iTerm2 Only