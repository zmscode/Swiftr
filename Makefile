.DEFAULT_GOAL := run

.PHONY: run r

# Build and run, forwarding ARGS: `make r` or `make r ARGS=MyApp.json`.
run:
	@swift run Swiftr $(ARGS)

r: run
