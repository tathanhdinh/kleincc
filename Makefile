.DEFAULT_GOAL := kleincc

OUTPUT_DIR := out

KOKA_FLAGS := -c -O2 --no-debug --target=c --cc=clang

kleincc: main.kk tokenize.kk parse.kk typen.kk codegen.kk kleincc.kk
	koka $< $(KOKA_FLAGS) --outdir=$(OUTPUT_DIR) --builddir=$(OUTPUT_DIR) --outname=$@

test: kleincc
	./test.sh

clean:
	rm -rf $(OUTPUT_DIR) *~ tmp*

.PHONY: clean
