DROPBEAR_VERSION = 2016.74

src/dropbear-$(DROPBEAR_VERSION).tar.bz2:
	wget https://matt.ucc.asn.au/dropbear/releases/dropbear-$(DROPBEAR_VERSION).tar.bz2 -O $@

initramfs/sbin/dropbear opt/dropbear/bin/dropbearkey: src/dropbear-$(DROPBEAR_VERSION).tar.bz2 opt/kernel/.dirstamp opt/musl/.dirstamp
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./initramfs/sbin ./opt/dropbear/bin
	tar -C ./build -xf ./src/dropbear-$(DROPBEAR_VERSION).tar.bz2
	export CC=$(CURDIR)/opt/musl/bin/musl-gcc CFLAGS="-I$(CURDIR)/opt/kernel/include" ; \
		cd ./build/dropbear-$(DROPBEAR_VERSION) && \
		./configure --prefix=$(CURDIR)/build/dropbear --host=$$(uname -m) \
			--disable-zlib --disable-lastlog --disable-wtmp && \
		make PROGRAMS="dropbear dropbearkey" && \
		make PROGRAMS="dropbear dropbearkey" install
	cp -p ./build/dropbear/sbin/dropbear ./initramfs/sbin/
	cp -p ./build/dropbear/bin/dropbearkey ./opt/dropbear/bin/
endif
