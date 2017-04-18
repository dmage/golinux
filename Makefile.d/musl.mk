MUSL_VERSION = 1.1.16

src/musl-$(MUSL_VERSION).tar.gz:
	mkdir -p `dirname $@`
	wget http://www.musl-libc.org/releases/musl-$(MUSL_VERSION).tar.gz -O $@

initramfs/lib/libc.so opt/musl/.dirstamp: src/musl-$(MUSL_VERSION).tar.gz
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build ./initramfs/lib ./opt/musl
	tar -C ./build -xf ./src/musl-$(MUSL_VERSION).tar.gz
	cd ./build/musl-$(MUSL_VERSION) && ./configure --prefix=$(CURDIR)/opt/musl && make && make install
	cp -p ./opt/musl/lib/libc.so ./initramfs/lib/
	touch ./opt/musl/.dirstamp
endif

initramfs/lib/ld-musl-x86_64.so.1:
	mkdir -p `dirname $@`
	ln -s libc.so $@
