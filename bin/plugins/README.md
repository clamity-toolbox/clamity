# First-class action command plugins

Executables in this directory are executed as a first class actions by the
`clamity` CLI.  Each plug-in script must have a comment in one of the following
forms to make itself available for use.

Plugins are organized into sub-directories with '_core' being the only required
grouping. It is so named to be the first directory, alphabetically.


Add a single comment line like one of these to your script to enable it.
```
# brief_description: One line description of command
// brief_description: One line description of command
```


## References

* [../clamity] entry point script
