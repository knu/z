all: z.sh README

clean:
	rm -f z.sh README

.PHONY: all clean

z.sh: src/build.sh src/z.main.sh src/z.cli.sh src/z.interactive.bash src/z.interactive.zsh
	(cd src && ./build.sh z.main.sh) > $@

README: z.1
	mandoc z.1 | col -bx > $@
