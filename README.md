# Clamity Toolbox

_Because tools separate us from the animals._

Yes, another toolbox. Clamity was born from my personal approach for providing
structure, automation and repeatability for CI/CD software development and
infrastructure operations. It's opinionated. Maybe it'll work for you.

It blends a custom interface with useful documentation so my tiny brain doesn't
have to memorize the zillions of ways things work.

## Considerations

- The toolbox favors unix-like operating systems, notably linux and OSX.

- The Clamity CLI supports **zsh** and **bash**. [Read this brief about working
  in a shell environment](docs/shell-environment.md).

- Make sure you have a Clamity supported package manager installed on your
  computer and in your search path (`PATH`). Clamity builds on lots of 3rd party
  software and services and will prompt you to install additional software along
  the way.

  Package managers for macos:

  - [macports](https://macports.org) [`port version`]
  - [Homebrew](https://brew.sh) [`brew --version`]

  Package managers for supported linux distributions:

  - **yum/rpm** for Fedora/CentOS/Red Hat flavors
  - **apt/dpkg** for Ubuntu/Debian flavors

- **[Optional]** Much of clamity's functionality is written in python. It will
  create its own python virtual environment but you need to have **python3**
  version **3.10** or greater in your search. To verify, run `python3
--version`.

## Quickstart

### Install and Load It

1. Clone the repo. It's recommended to use the `ssh` protocol as many of the
   `clamity` features rely on that protocol. To do so, you'll need to add your
   ssh public key to your `github.com` account settings `Github.com > User Menu > Settings > SSH and GPG keys`.

   ```
   cd /my/src
   git clone git@github.com:clamity-toolbox/clamity
   ```

   Cloning via `https` is fine but eventually you'll want to create one or more
   ssh key pair(s) for yourself; `clamity` can help with that too.

1. The `clamity` command is implemented as a shell function so it needs to be
   loaded into your shell. It will _NOT_ be inherited when launching sub-shells
   unless you specifically configure your shell's run-commands file (`~/.zshrc`,
   `~/.bashrc`) for that.

   ```
   source /my/src/clamity/loader.sh
   ```

1. Consider adding an alias to your shell's run-commands file (`~/.bashrc` or
   `~/.zshrc`) to make it available in all shells you spawn. For example:

   ```
   echo "alias load-clamity='source /my/src/clamity/loader.sh'" >> ~/.zshrc'
   ```

   Now for all new shells (not your current one), you'll be able to type
   `load-clamity` on the command line to load it.

1. To get started, type `clamity` for a brief usage or `clamity help` for more
   detail.

### Include clamity commands in your scripts

If you want to use `clamity` commands in your scripts or programs, use the
`$CLAMITY_ROOT/bin/run-clamity` command. It has the same usage as the `clamity`
shell function. Note that any sub-commaands which mutate the shell's environment
won't survive the command's execution.

### Recommended Approach to Get Going

`clamity` is large in functionality and ever-growing. The context sensitive help
is a first-class feature because the cognative load can be daunting. That said,
start by learning the top-level sub-commands (type `clamity` to see them). The
most valuable tip is to _know where commands live_. Stating the obvious, knowing
`clamity`'s command structure and context sensitive help is key to success with
this toolbox.

The `-n | -dryrun` option makes any command safe to try out. It will
prevent any mutable behavior, reporting the work it would do without doing it.

## Contributions

Contributes are welcome with the expectation that you're consistent with the
practices and structure of the toolkit. Create your fork and submit PR's as
desired. And thanks for helping out!

## Documentation

Much of the documentation is embedded in the command structure to provide
context sensitive help. Just run incomplete `clamity` commands or add `help` to
the end of a command for more detail.

Guides and other docs can be found [here](docs/README.md).

## Notes on Developing Clamity in VS Code

- Install the Python, Flake8 & Black Formatter extensions.

- Set the python interpreter (`cmd pallet >Python: Command Interpreter`) to
  `~/.clamity/pyvenv/bin/python3` - Do _NOT_ use the file browser window, type
  the command and path in the box so VS Code doesn't infer it from a symbolic
  link.

- Create a `.env` file in the clamity repo's root directory. If `CLAMITY_ROOT`
  is defined, you can run this command: `cat .env.sample|sed "s|__CLAMITY_ROOT__|${CLAMITY_ROOT}|" >.env`
