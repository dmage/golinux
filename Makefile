KERNEL_VERSION=4.10-rc8
CPUS=3

uname_S = $(shell uname -s)

define prepare-golinux-fedora-image
docker build -t golinux-fedora ./golinux-fedora
endef

define prepare-linux-src
docker volume create --name golinux-build
test -e ./src/linux-$(KERNEL_VERSION) || tar -C ./src -xf $^
ln -sfh linux-$(KERNEL_VERSION) ./src/linux
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

ifeq ($(uname_S),Darwin)
initramfs/lib/libc.so: src/musl-1.1.16.tar.gz
	$(prepare-golinux-fedora-image)
	docker run --rm -i -t \
		-v golinux-build:/srv/build \
		-v "$(CURDIR)/src:/srv/src:ro" \
		-v "$(CURDIR)/initramfs/lib:/srv/initramfs/lib" \
		golinux-fedora \
		sh -c "mkdir /build && tar -C /build -xf /srv/src/musl-1.1.16.tar.gz && cd /build/musl-1.1.16 && ./configure --prefix=/build/musl && make && make install && cp /build/musl/lib/libc.so /srv/initramfs/lib"
else
initramfs/lib/libc.so: src/musl-1.1.16.tar.gz
	mkdir -p ./build
	tar -C ./build -xf ./src/musl-1.1.16.tar.gz
	cd ./build/musl-1.1.16 && ./configure --prefix $(CURDIR)/build/musl && make && make install
	cp ./build/musl/lib/libc.so ./initramfs/lib
endif

initramfs/bin/backdoor: backdoor/backdoor.go
	docker run --rm -i -t \
		-v "$(CURDIR)/backdoor:/go/src/github.com/dmage/golinux/backdoor:ro" \
		-v "$(CURDIR)/initramfs/bin:/srv/initramfs/bin" \
		golang \
		sh -c "go install github.com/dmage/golinux/backdoor && cp /go/bin/backdoor /srv/initramfs/bin"

boot/initrd.img: initramfs/bin/busybox initramfs/etc/udhcpc/default.script initramfs/lib/libc.so initramfs/bin/backdoor
	@mkdir -p `dirname $@`
	cd initramfs && find . | cpio -o -H newc | gzip > ../$@

src/linux-$(KERNEL_VERSION).tar.xz:
	mkdir -p `dirname $@`
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/testing/linux-$(KERNEL_VERSION).tar.xz -O $@

boot/vmlinuz: src/linux-$(KERNEL_VERSION).tar.xz .config
	$(prepare-golinux-fedora-image)
	$(prepare-linux-src)
	mkdir -p ./boot
	docker run --rm -i -t \
		-v golinux-build:/srv/build \
		-v "$(CURDIR)/.config:/srv/build/.config:ro" \
		-v "$(CURDIR)/src:/srv/src:ro" \
		-v "$(CURDIR)/boot:/srv/boot" \
		golinux-fedora \
		sh -c "cd /srv/src/linux && make -j$(CPUS) O=/srv/build && cp /srv/build/arch/x86/boot/bzImage /srv/boot/vmlinuz"

menuconfig: src/linux-$(KERNEL_VERSION).tar.xz
	$(prepare-golinux-fedora-image)
	$(prepare-linux-src)
	touch .config
	docker run --rm -i -t \
		-v golinux-build:/srv/build \
		-v "$(CURDIR)/.config:/srv/.config" \
		-v "$(CURDIR)/src:/srv/src:ro" \
		golinux-fedora \
		sh -c "cd /srv/src/linux && mkdir -p /srv/build && cp /srv/.config /srv/build/.config && make O=/srv/build menuconfig && cat /srv/build/.config >/srv/.config"

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

.PHONY: boot/initrd.img menuconfig build run
