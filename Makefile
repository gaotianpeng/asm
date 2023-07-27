BUILD:=./

HD_IMG_NAME:= "hd.img"

all: ./boot/boot.o
	$(shell rm -rf $(HD_IMG_NAME))
	bximage -q -hd=16 -func=create -sectsize=512 -imgmode=flat $(HD_IMG_NAME)
	dd if=${BUILD}/boot/boot.o of=hd.img bs=512 seek=0 count=1 conv=notrunc

${BUILD}/boot/boot.o: ./hello.asm
	$(shell mkdir -p ./boot)
	nasm $< -o $@

clean:
	$(shell rm -rf ./boot)
	$(shell rm -rf hd.img)

bochs: all
	bochs -q -f ./bochsrc_mac
