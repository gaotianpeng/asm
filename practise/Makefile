BUILD:=./

HD_IMG_NAME:= "hd.img"

SRC = ""

LINUX_CMD = echo "Running on Linux"
MACOS_CMD = echo "Running on macOS"

UNAME_S := $(shell uname -s)

all: ./boot/mbr.o ./boot/loader.o
	$(shell rm -rf $(HD_IMG_NAME))
	bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $(HD_IMG_NAME)
	dd if=${BUILD}/boot/mbr.o of=hd.img bs=512 seek=0 count=1 conv=notrunc
	dd if=${BUILD}/boot/loader.o of=hd.img bs=512 seek=2 count=4 conv=notrunc


${BUILD}/boot/%.o: %.asm
	$(shell mkdir -p ./boot)
	nasm -I include/ $< -o $@


clean:
	$(shell rm -rf ./boot)
	$(shell rm -rf hd.img)
	$(shell rm -rf bx_enh_dbg.ini)

bochs: all
	@if [ "$(UNAME_S)" = "Linux" ]; then 	\
		$(LINUX_CMD); 						\
		bochs -q -f ./bochsrc_linux; 		\
	elif [ "$(UNAME_S)" = "Darwin" ]; then 	\
		$(MACOS_CMD); 						\
		bochs -q -f ./bochsrc_mac;			\
	else 									\
		echo "Unsupported platform: $(UNAME_S)"; \
	fi

