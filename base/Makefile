BUILD:=../

HD_IMG_NAME:= "hd.img"

SRC = ""

LINUX_CMD = echo "Running on Linux"
MACOS_CMD = echo "Running on macOS"

UNAME_S := $(shell uname -s)

real: ${BUILD}/boot/boot.o
	$(shell rm -rf ${BUILD}$(HD_IMG_NAME))
	bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $(HD_IMG_NAME)
	dd if=${BUILD}/boot/boot.o of=hd.img bs=512 seek=0 count=1 conv=notrunc


${BUILD}/boot/boot.o: mbr.asm
	$(shell mkdir -p ./boot)
	nasm $< -o $@

clean:
	$(shell rm -rf ${BUILD}/boot)
	$(shell rm -rf ${BUILD}/hd.img)
	$(shell rm -rf bx_enh_dbg.ini)


bochs0: real
	@if [ "$(UNAME_S)" = "Linux" ]; then 	\
		$(LINUX_CMD); 						\
		bochs -q -f ../bochsrc_linux; 		\
	elif [ "$(UNAME_S)" = "Darwin" ]; then 	\
		$(MACOS_CMD); 						\
		bochs -q -f ../bochsrc_mac;			\
	else 									\
		echo "Unsupported platform: $(UNAME_S)"; \
	fi

