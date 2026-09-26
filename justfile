set quiet
alias r := run

# Build and run, forwarding any extra arguments: `just r` or `just r MyApp.json` to open a project.
run *args:
    swift run Swiftr {{ args }}
