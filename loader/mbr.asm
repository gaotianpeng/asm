         app_lba_start equ 2             ; 用户程序起始逻辑扇区号

SECTION mbr align=16 vstart=0x7c00
        ; 清屏
        mov ah, 0x00
        mov al, 0x03
        int 0x10


        ;设置堆栈段和栈指针
        mov ax,0
        mov ss,ax
        mov sp,ax

        mov cx, 0x1000
        mov ds, cx
        mov cx, 0xb800
        mov es, cx
        ;读取程序的起始部分
        xor di,di
        mov si,app_lba_start            ; 程序在硬盘上的起始逻辑扇区号
        xor bx,bx                       ; 加载到DS:0x0000处(0x1000:0x0000)
        ; di:si 起始逻辑扇区号
        ; ds:bx 内存缓存区地址
        call read_hard_disk
        mov ax, [ds:0x00]
        mov dx, [ds:0x02]

        ; 计算程序段长度，并打印出来
        call print_app_size

        jmp $



;-------------------------------------------------------------------------------
; 分4四步
; 1) 设置读取扇区数
; 2) 设置LBA地址
; 3) 设置读命令
; 4) 等待读写操作完成
read_hard_disk:                          ; 从硬盘读取一个逻辑扇区
                                         ; 输入：di:si=起始逻辑扇区号
                                         ; 输出：ds:bx=目标缓冲区地址
             push ax
             push bx
             push cx
             push dx

             ; 1) 设置读取扇区数
             mov dx,0x1f2
             mov al,1
             out dx,al                       ; 读取的扇区数

             ; 2) 设置LBA地址
             inc dx                          ; 0x1f3
             mov ax,si
             out dx,al                       ; LBA地址7~0

             inc dx                          ; 0x1f4
             mov al,ah
             out dx,al                       ; LBA地址15~8

             inc dx                          ; 0x1f5
             mov ax,di
             out dx,al                       ; LBA地址23~16

             inc dx                          ; 0x1f6
             mov al,0xe0                     ; LBA28模式，主盘
             or al,ah                        ; LBA地址27~24
             out dx,al

             ; 3) 设置读命令
             inc dx                          ; 0x1f7
             mov al,0x20                     ; 读命令
             out dx,al

            ; 4) 等待读写操作完成
      .waits:
             in al,dx
             and al,0x88
             cmp al,0x08
             jnz .waits                      ; 未准备好数据，继续等

             ; 硬盘已准备好数据传输
             mov cx,256                      ;总共要读取的次数
             mov dx,0x1f0
      .readw:
             in ax,dx                        ; 从 dx 指定的 I/O 端口读取一个字（16 位值），并将其存入 ax 寄存器
             mov [bx],ax                     ; 将 ax 中的字移动到 bx 寄存器指向的内存位置
             add bx,2
             loop .readw

             pop dx
             pop cx
             pop bx
             pop ax

             ret

; 打印用户程序的大小
; 输入 [es:si]  显存段地址
;      dx:ax   用户程序长度
; 输出 si
print_app_size:
        push ax
        push bx
        push cx
        push dx

        xor cx, cx
        mov bx, 10
    .push
        inc cx
        div bx
        add dl, 0x30
        push dx
        xor dx, dx
        cmp ax, 0
        jnz .push

    .pop
        pop ax
        mov byte [es:si], al
        inc si
        mov byte [es:si], 0x07
        inc si
        dec cx
        cmp cx, 0
        jnz .pop

        pop dx
        pop cx
        pop bx
        pop ax
        ret



; ----------------------------------------------------------------------------------------------------------------------
         phy_base dd 0x10000             ;用户程序被加载的物理起始地址

 times 510-($-$$) db 0
                  db 0x55,0xaa