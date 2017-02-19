KERNEL_VERSION = 4.10-rc8
CPUS ?= 3

uname_S = $(shell uname -s)

define docker-make
docker build -t golinux-fedora ./golinux-fedora
docker volume create --name golinux-build
docker run --rm -i -t \
	-v golinux-build:/srv/build \
	-v "$(CURDIR)/.config:/srv/.config" \
	-v "$(CURDIR)/boot:/srv/boot" \
	-v "$(CURDIR)/initramfs:/srv/initramfs" \
	-v "$(CURDIR)/src:/srv/src:ro" \
	-v "$(CURDIR)/backdoor:/srv/backdoor:ro" \
	-v "$(CURDIR)/Makefile:/srv/Makefile:ro" \
	golinux-fedora \
	sh -c "cd /srv && make MAKEFLAGS='$(MAKEFLAGS)' $@"
endef

define unpack-linux-src
test -e ./src/linux-$(KERNEL_VERSION) || tar -C ./src -xf ./src/linux-$(KERNEL_VERSION).tar.xz
endef

all: build

initramfs/bin/busybox:
	mkdir -p `dirname $@`
	wget https://www.busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/busybox-x86_64 -O $@
	chmod +x $@

initramfs/etc/udhcpc/default.script:
	mkdir -p `dirname $@`
	wget https://raw.githubusercontent.com/mirror/busybox/master/examples/udhcp/simple.script -O $@
	chmod +x $@

src/musl-1.1.16.tar.gz:
	mkdir -p `dirname $@`
	wget http://www.musl-libc.org/releases/musl-1.1.16.tar.gz -O $@

initramfs/lib/libc.so: src/musl-1.1.16.tar.gz
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build ./initramfs/lib
	tar -C ./build -xf ./src/musl-1.1.16.tar.gz
	cd ./build/musl-1.1.16 && ./configure --prefix=$(CURDIR)/build/musl && make && make install
	cp -a ./build/musl/lib/libc.so ./initramfs/lib/
endif

initramfs/bin/backdoor: backdoor/backdoor.go
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	cd ./backdoor && go build -o ../initramfs/bin/backdoor .
endif

boot/initrd.img: initramfs/bin/busybox initramfs/etc/udhcpc/default.script initramfs/lib/libc.so initramfs/bin/backdoor
	@mkdir -p `dirname $@`
	cd initramfs && find . | cpio -o -H newc | gzip > ../$@

src/linux-$(KERNEL_VERSION).tar.xz:
	mkdir -p `dirname $@`
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-$(KERNEL_VERSION).tar.xz -O $@

boot/vmlinuz: src/linux-$(KERNEL_VERSION).tar.xz .config
	$(unpack-linux-src)
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/linux
	cp ./.config ./build/linux/.config
	cd ./src/linux-$(KERNEL_VERSION) && make -j$(CPUS) O=$(CURDIR)/build/linux
	cp ./build/linux/arch/x86/boot/bzImage ./boot/vmlinuz
endif

menuconfig: src/linux-$(KERNEL_VERSION).tar.xz
	$(unpack-linux-src)
	touch .config
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/linux
	cp ./.config ./build/linux/.config
	cd ./src/linux-$(KERNEL_VERSION) && make -j$(CPUS) O=$(CURDIR)/build/linux menuconfig
	# If we inside the docker container, we can replace only the content of the .config file, but not the file itself.
	cat ./build/linux/.config >.config
endif

build: boot/vmlinuz boot/initrd.img

run: build
	@mkdir -p ./vfat
	qemu-system-x86_64 \
		-kernel ./boot/vmlinuz \
		-initrd ./boot/initrd.img \
		-append 'console=ttyS0 quiet' \
		-drive file=fat:rw:./vfat/,format=raw,if=virtio \
		-net nic,vlan=0 \
		-net user,vlan=0,hostfwd=tcp:127.0.0.1:8080-:8080 \
		-serial stdio

clean:
ifeq ($(uname_S),Darwin)
	docker volume rm golinux-build
else
	-rm -rf ./build
endif

.PHONY: boot/initrd.img menuconfig build run clean
