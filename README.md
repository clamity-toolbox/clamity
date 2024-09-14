# Clamity - Yet Another Toolkit

_Because tools separate us from the animals._

Clamity was born from my personal journey and approach for providing structure,
automation and repeatability for CI/CD software development and infrastructure
operations.

## Considerations

* The toolbox favors unix-like operating systems, notably linux and OSX.

* Where the Clamity CLI is concerned, **zsh** or **bash** are supported.

* Make sure you have a Clamity supported package manager installed on your
  computer and in your search path (`PATH`). Clamity builds on lots of 3rd party
  software and services and will prompt you to install additional software along
  the way.

  Package managers for macos:
   - [macports](https://macports.org) [`port version`]
   - [Homebrew](https://brew.sh) [`brew --version`]
  Package managers for supported linux distros:
   - **yum/rpm** for Fedora/CentOS/Red Hat flavors
   - **apt/dpkg** for Ubuntu/Debian flavors


## Quickstart

### Install and Load It

1. Clone the repo. It's recommended to use the `ssh` protocol as many of the
   `clamity` features use that protocol. To do so, you'll need to add your ssh
   public key to your `github.com` account settings.
   ```
   cd /my/src/tree
   git clone git@github.com:jimmyjayp/clamity
   ```
   Cloning via `https` is fine but eventually you'll want to create one or more
   ssh key pair(s) for yourself; `clamity` can help with that too.

1. The `clamity` command is implemented as a shell function so it needs to be
   loaded into your shell.
   ```
   source /my/src/tree/clamity/loader.sh
   ```

1. Consider adding a command in your shell's run-commands file (`~/.bashrc` or
   `~/.zshrc`) to make it available in all shells you spawn. Add the `--quiet`
   option to prevent any load-time messages. For exmaple:
   ```
   echo 'source /my/src/tree/clamity/loader.sh --quiet' >> ~/.zshrc
   ```

1. To get started, type `clamity` for a brief usage or `clamity help` for more
   detail.


### Include clamity commands in your scripts

If you want to use `clamity` commands in your scripts or programs, add the
`clamity/bin` directory to your search path:
```
export PATH=/my/src/tree/clamity/bin:$PATH
```
Then you can use the `run-clamity` command. It has the same usage as the
`clamity` shell function. Note that any sub-commaands which mutate the shell's
environment won't survive the command's execution.

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
