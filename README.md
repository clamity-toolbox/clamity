# Clamity CLI

The [Clamity User's Guide](https://clamity-toolbox.github.io/clamity-guide/) is
where much of the online documentation lives, including the [CLI
installation](https://clamity-toolbox.github.io/clamity-guide/#the-clamity-cli).

## TL;DR

```
git clone git@github.com:clamity-toolbox/clamity
source clamity/loader.sh
```

## Notes on Developing Clamity in VS Code

- Install these extensions:

  - shell-format
  - Rewrap
  - Python
  - Flake8
  - Black Formatter

  ```
  code --install-extension foxundermoon.shell-format && code --install-extension stkb.rewrap && code --install-extension ms-python.python && code --install-extension ms-python.flake8 && code --install-extension ms-python.black-formatter
  ```

- Set the python interpreter (`cmd pallet >Python: Command Interpreter`) to
  `~/.clamity/pyvenv/bin/python3` - Do _NOT_ use the OS's file browser window,
  type the command and path in the box explicitly so VS Code doesn't infer a
  different location as it's a symbolic link. Obviously, you cannot do this
  until after you install clamity's python environment (JIT with a clamity
  python function or `clamity py install`).

- Create a `.env` file in the clamity repo's root directory. If `CLAMITY_ROOT`
  is defined, you can run this command: `cat .env.sample|sed "s|__CLAMITY_ROOT__|${CLAMITY_ROOT}|" >.env`
