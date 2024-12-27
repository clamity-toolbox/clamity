# Clamity Toolbox

The [Clamity User's Guide](https://clamity-toolbox.github.io/clamity-guide/) is
where much of the online documentation lives, including the [CLI
installation](https://clamity-toolbox.github.io/clamity-guide/#the-clamity-cli).

## TL;DR

```
git clone git@github.com:clamity-toolbox/clamity
source clamity/loader.sh
```

## Notes on Developing Clamity in VS Code

- Install the Python, Flake8 & Black Formatter extensions.

- Set the python interpreter (`cmd pallet >Python: Command Interpreter`) to
  `~/.clamity/pyvenv/bin/python3` - Do _NOT_ use the file browser window, type
  the command and path in the box so VS Code doesn't infer it from a symbolic
  link.

- Create a `.env` file in the clamity repo's root directory. If `CLAMITY_ROOT`
  is defined, you can run this command: `cat .env.sample|sed "s|__CLAMITY_ROOT__|${CLAMITY_ROOT}|" >.env`
