

.PHONY: all

all:
	bash run.sh

clean:
	rm -rf ./build ./toolchain

install:
	mkdir -p $(DESTDIR)/opt/
	cp -r toolchain $(DESTDIR)/opt/blocksds-toolchain

