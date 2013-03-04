all: z.sh README

.PHONY: all

z.sh: src/build.sh src/z.main.sh src/z.interactive.bash src/z.interactive.zsh
	src/build.sh

README: z.1
	mandoc z.1 | col -bx > $@
