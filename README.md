# Clamity Platform

One of zillions of approaches for structuring a development and operations
platform for the purpose of automation, deployment, operational management and
the facilition of all aspects of the SDLC.

It's feature set has been driven largely as a product of necessity from a small
sample size, but it was built with extensibility in mind. Primarly built for use
on unix-like systems, noticably MacOSX and Linux, and AWS the AWS cloud platform.

It's written using a combination of Python and bash shell scripting.


## Requirements & Considerations

* clamity only supports **zsh** or **bash**
* **bash** (in your search path) is requred even if you are a **zsh** user.
* Clamity will need any number of 3rd party packages to do its work. It has a
  built in abstraction interface for managing software via Macports. If you
  choose to use this, Clamity will handle most of the package management for
  you. This requires you install [macports](https://www.macports.org).

## Quickstart

### Install and Load It

The fast way to get started is to clone this repo from within a **zsh** or
**bash** shell on a supported OS and load it into the current shell environment.
```
git clone --origin upstream git@github.com:jimmyjayp/clamity
export CLAMITY_ROOT=/path/to/repo/clamity
source $CLAMITY_ROOT/loader.sh
```

The _clamity environment_ will be available in (inherited by) all sub-shells.

Note the use of the **ssh** protocol for cloning the repo. This presumes you've
got an ssh key setup on your computer and you've added its public key to your
settings on the github server. **ssh** access to your github server is necessary
to use the _clamity platform_.

Add the `source` statement above to your preferred login profile if you want it
in every shell, or consider creating an alias in your shell's run-commands file
(**.zshrc** or **.bashrc**) like so:
```
alias load-clamity='source ~/my/source-directory/clamity/loader.sh'
```
Then just type `load-clamity` in any shell to load it.


