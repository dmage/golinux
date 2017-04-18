CPUS ?= 3

srctree := $(CURDIR)

uname_S = $(shell uname -s)

define docker-shell
docker build -t golinux-fedora ./golinux-fedora
docker volume create --name golinux-build
docker run --rm -i -t \
	-v golinux-build:/srv/build \
	-v "$(CURDIR)/.busybox-config:/srv/.busybox-config" \
	-v "$(CURDIR)/.kernel-config:/srv/.kernel-config" \
	-v "$(CURDIR)/boot:/srv/boot" \
	-v "$(CURDIR)/initramfs:/srv/initramfs" \
	-v "$(CURDIR)/opt:/srv/opt" \
	-v "$(CURDIR)/secrets:/srv/secrets" \
	-v "$(CURDIR)/src:/srv/src:ro" \
	-v "$(CURDIR)/backdoor:/srv/backdoor:ro" \
	-v "$(CURDIR)/Makefile:/srv/Makefile:ro" \
	-v "$(CURDIR)/Makefile.d:/srv/Makefile.d:ro" \
	golinux-fedora \
	sh -c $1
endef

define docker-make
$(call docker-shell,"cd /srv && make MAKEFLAGS='$(MAKEFLAGS)' $@")
endef

INITRAMFS_BUILD_TARGETS=\
	initramfs/bin/busybox \
	initramfs/etc/udhcpc/default.script \
	initramfs/lib/libc.so \
	initramfs/lib/ld-musl-x86_64.so.1 \
	initramfs/sbin/dropbear

all: build

docker-sh:
	$(call docker-shell,"cd /srv && exec /bin/bash -il")

-include $(srctree)/Makefile.d/*.mk

initramfs/bin/backdoor: backdoor/backdoor.go
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	cd ./backdoor && go build -o ../initramfs/bin/backdoor .
endif

boot/initrd.img: $(INITRAMFS_BUILD_TARGETS) $(shell find ./initramfs)
	mkdir -p `dirname $@`
	cd initramfs && find . | cpio -o -H newc | gzip -1 > ../$@

boot/poweroff.img: src/poweroff.S
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	as -c -o ./build/poweroff.o ./src/poweroff.S
	objcopy -O binary ./build/poweroff.o ./boot/poweroff.img
endif

build: boot/vmlinuz boot/initrd.img boot/poweroff.img

secrets/root/id_rsa secrets/root/id_rsa.pub:
	mkdir -p `dirname $@`
	ssh-keygen -t rsa -N "" -f secrets/root/id_rsa

secrets: secrets/root/id_rsa.pub

run: boot/vmlinuz boot/initrd.img secrets
	qemu-system-x86_64 \
		-kernel ./boot/vmlinuz \
		-initrd ./boot/initrd.img \
		-append 'console=ttyS0 quiet initcall_debug' \
		-drive file=fat:rw:./secrets,format=raw,if=virtio \
		-netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
		-device virtio-net,netdev=net0 \
		-serial stdio

clean:
ifeq ($(uname_S),Darwin)
	docker volume rm golinux-build
else
	-rm -rf ./build
endif

.PHONY: docker-sh build secrets run clean
