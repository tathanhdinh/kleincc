OUTPUT_DIR=out

KOKA_FLAGS=-c -O2 --no-debug --target=c --cc=clang

kleincc: main.kk
	koka $? $(KOKA_FLAGS) --outdir=$(OUTPUT_DIR) --builddir=$(OUTPUT_DIR) --outname=$@

test: kleincc
	./test.sh

clean:
	rm -rf $(OUTPUT_DIR) *~ tmp*

.PHONY: clean