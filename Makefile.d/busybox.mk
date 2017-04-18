BUSYBOX_VERSION = 1.26.2

src/busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget https://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2 -O $@

src/busybox-$(BUSYBOX_VERSION)/.dirstamp: src/busybox-$(BUSYBOX_VERSION).tar.bz2
	tar -C ./src -xf ./src/busybox-$(BUSYBOX_VERSION).tar.bz2
	touch $@

busybox-menuconfig: src/busybox-$(BUSYBOX_VERSION)/.dirstamp
	touch .busybox-config
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/busybox
	cp ./.busybox-config ./build/busybox/.config
	cd ./src/busybox-$(BUSYBOX_VERSION) && make -j$(CPUS) O=$(CURDIR)/build/busybox menuconfig
	# If we inside the docker container, we can replace only the content of the .busybox-config file, but not the file itself.
	cat ./build/busybox/.config >.busybox-config
endif

initramfs/bin/busybox: src/busybox-$(BUSYBOX_VERSION)/.dirstamp .busybox-config opt/kernel/.dirstamp opt/musl/.dirstamp
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/busybox ./initramfs/bin
	cp ./.busybox-config ./build/busybox/.config
	cd ./src/busybox-$(BUSYBOX_VERSION) && make -j$(CPUS) CC=$(CURDIR)/opt/musl/bin/musl-gcc CFLAGS="-I$(CURDIR)/opt/kernel/include" O=$(CURDIR)/build/busybox
	cp -p ./build/busybox/busybox ./initramfs/bin/busybox
endif

initramfs/etc/udhcpc/default.script: src/busybox-$(BUSYBOX_VERSION)/.dirstamp
	mkdir -p `dirname $@`
	cp ./src/busybox-$(BUSYBOX_VERSION)/examples/udhcp/simple.script $@

busybox-clean:
	rm -rf ./src/busybox

.PHONY: busybox-menuconfig busybox-clean
