KERNEL_VERSION = 4.10.10

src/linux-$(KERNEL_VERSION).tar.xz:
	mkdir -p `dirname $@`
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$(KERNEL_VERSION).tar.xz -O $@

src/linux-$(KERNEL_VERSION)/.dirstamp: src/linux-$(KERNEL_VERSION).tar.xz
	tar -C ./src -xf ./src/linux-$(KERNEL_VERSION).tar.xz
	touch $@

kernel-menuconfig: src/linux-$(KERNEL_VERSION)/.dirstamp
	touch .kernel-config
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/linux
	cp ./.kernel-config ./build/linux/.config
	cd ./src/linux-$(KERNEL_VERSION) && make -j$(CPUS) O=$(CURDIR)/build/linux menuconfig
	# If we inside the docker container, we can replace only the content of the .kernel-config file, but not the file itself.
	cat ./build/linux/.config >.kernel-config
endif

boot/vmlinuz: src/linux-$(KERNEL_VERSION)/.dirstamp .kernel-config
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/linux
	cp ./.kernel-config ./build/linux/.config
	cd ./src/linux-$(KERNEL_VERSION) && make -j$(CPUS) O=$(CURDIR)/build/linux
	cp ./build/linux/arch/x86/boot/bzImage ./boot/vmlinuz
endif

opt/kernel/.dirstamp: src/linux-$(KERNEL_VERSION)/.dirstamp
ifeq ($(uname_S),Darwin)
	$(docker-make)
else
	mkdir -p ./build/linux ./opt/kernel
	cd ./src/linux-$(KERNEL_VERSION) && make headers_install O=$(CURDIR)/build/linux INSTALL_HDR_PATH=$(CURDIR)/opt/kernel
	touch ./opt/kernel/.dirstamp
endif

.PHONY: kernel-menuconfig
