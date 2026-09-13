# iterm-peacock

Drop a `.peacock` file in a directory and iTerm2 changes its background, text, tab
color and badge as soon as you cd into it. Leave the directory and everything goes
back. `ssh`, `mysql` and any other command can carry their own colors too, so
production never looks like staging. A zsh plugin; bash works too.

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
PROMPT_COMMAND="_peacock_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
_peacock_wrap_commands
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

## Commands

One `.ini` per command, in `~/.config/iterm-peacock/`. The presence of `mysql.ini` is
what makes `mysql` hooked, and while the command runs its colors are in effect.

```ini
# ~/.config/iterm-peacock/mysql.ini

[prod-db-* *.prod.example.com]
background=#300000
badge=PRODUCTION

[staging-db-*]
background=#000030
```

Patterns are matched against every word of the command line except the command itself
and words starting with `-`, so a host, a profile or a database name is picked up
without this tool knowing each command's options.

```
mysql -h prod-db-01 -u app mydb    prod-db-01 matches, the terminal turns red
psql -h db.staging.example.com     no section matches, nothing changes
```

When a word is not enough — tunnels that all connect to `127.0.0.1` and differ only by
port — a section can match on option values instead. Every condition has to hold, and
the section with the most conditions wins; on a tie, the one written last.

```ini
[PROD]
match-options = -h|--host=127.0.0.1 -P|--port=13306
background=#300000
```

`iterm-peacock help cmd` spells out the rules, written so a coding agent can follow them.

`ssh` is the exception: its option grammar is known, so only the destination is
matched and ssh has to hold the terminal — a login and a tunnel (`ssh -N -L 8080:localhost:80 host`)
are colored, while `ssh host ls` and `-f` are left alone.

```zsh
iterm-peacock cmd                                   # every command and its sections
iterm-peacock cmd mysql prod-db-01                  # what that word would get
iterm-peacock cmd mysql test -h 127.0.0.1 -P 13306  # what that command line would get
iterm-peacock cmd mysql set 'prod-db-*'             # pick a scheme for that section
iterm-peacock cmd mysql set 'prod-db-*' badge PROD  # set one key
iterm-peacock cmd mysql unset 'prod-db-*'           # remove that section
iterm-peacock cmd mysql edit                        # open mysql.ini in $EDITOR
```

`set` is create-or-update, so running it twice leaves the same file, and `unset` is the
only thing that removes anything — the same verbs the `.peacock` side uses.

In zsh a `preexec` hook watches the command line, so no command is wrapped; bash wraps
them, as the install snippet above does.

## Help

```
iterm-peacock --help
```

## Supported Terminal

iTerm2 Only

## Use cases

### By directory — a `.peacock` file

- **Tell projects apart across many tabs.** Give each repository its own background,
  tab color and a badge with its name, so both the tab bar and the window show which
  project a shell is in.
- **Mark directories where a mistake is expensive.** A red background and a `PROD` badge
  in the directory that holds production infrastructure code or deploy scripts, on in
  every shell opened there.
- **Different colors inside one repository.** In a monorepo, `api/` and `docs/` can each
  have a `.peacock`; a subdirectory without one gets the nearest one above it.
- **Several checkouts of the same repository.** Clones and git worktrees live in
  different directories, so each can carry its own `.peacock`.
- **A readable scheme without designing one.** `iterm-peacock` previews generated
  schemes live in the terminal; text keeps a WCAG contrast of at least 7 against the
  background, and ANSI colors at least 4.5.

### While a command runs — `~/.config/iterm-peacock/<command>.ini`

- **Production servers over ssh.** `[prod-*]` in `ssh.ini` turns the terminal red for
  `ssh prod-web-01`, and the colors come back when the session ends, an interrupted one
  included.
- **A tunnel kept open in a tab.** `ssh -N -L 13306:db:3306 prod-bastion` is colored by
  the host it connects to for as long as the tunnel is up.
- **Database clients by host name.** `mysql -h prod-db-01` or `psql -h db.prod.example.com`
  matched by a pattern on the host name.
- **Connections through a local tunnel.** When every environment is `127.0.0.1` and only
  the port differs, `match-options = -h|--host=127.0.0.1 -P|--port=13306` tells production
  from staging.
- **Any interactive command that takes a target.** `redis-cli -h prod-cache`,
  `kubectl --context prod-cluster exec -it app -- sh`: creating `<command>.ini` is all it
  takes to hook a command.
- **See what you are connected to.** A section without a badge shows the host that
  matched, or the section name, as the badge.
- **Let a coding agent write the rules.** Describe which command lines should look
  different. `iterm-peacock help cmd` gives the agent the rules, and
  `iterm-peacock cmd <command> test <argument>...` lets it check each command line.

### What it does not do

- Only iTerm2. Terminal.app and other terminals ignore the escape sequences, so nothing
  changes.
- Only zsh and bash.
- No bold, link, underline or cursor-text colors: iTerm2 cannot restore them to the
  profile, and everything this tool changes has to come back when you leave.
- It is not the VS Code Peacock extension and does not read `.vscode/settings.json`.
- It sees the command line typed in the local shell, not what happens inside a session:
  after `ssh bastion`, an `ssh prod-web-01` run on bastion does not change the colors.
- A command that finishes at once only flashes its colors, so hook commands you use
  interactively.
- In `ssh.ini` only the destination is matched; ssh options such as `-p` or `-l` cannot
  pick a section.
