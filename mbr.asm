         app_lba_start equ 2             ; 用户程序起始逻辑扇区号

; 引导程序实际加载的地址是 0000:0x7c00
SECTION mbr align=16 vstart=0x7c00
        ; 清屏
        mov ah, 0x00
        mov al, 0x03
        int 0x10


        ;设置堆栈段和栈指针,栈的段地址是0x0000，段的长度是64KB，栈指针将在段内0xffff和0x0000之间变化
        mov ax,0
        mov ss,ax
        mov sp,ax

        ; 此时，段寄存器均初始化为0

        mov ax, [cs:phy_base]
        mov dx, [cs:phy_base + 0x02]
        mov bx, 16
        div bx                      ; ax商, dx余数
        mov ds, ax                  ; ds 指向 0x1000
        mov es, ax                  ; es 指向 0x1000

        ; 读取用户程序起始部分，加载到内存ds:0x0000
        xor di, di
        mov si, app_lba_start
        xor bx, bx
        call read_hard_disk

        ; 判断程序的大小
        mov dx, [2]
        mov ax, [0]
        mov bx, 512
        div bx
        cmp dx, 0
        jnz @1                      ; 不能被512整除
        dec ax                      ; 能被512整除
    @1:
        cmp ax, 0
        jz direct

        ; 扇区数>1, 读取第1个扇区之外的其它扇区
        push ds             ; 保存ds

        mov cx, ax                  ; 将剩余待读取扇区数ax赋值为cx
    @read_left_app:
        ; 每次读取一个扇区，重新计算段地址和偏移地址，防止段溢出
        ; 计算下一个扇区读取到内存的位置,更新段地址ds
        mov ax, ds
        add ax, 512
        mov ds, ax

        ; 每读取,偏移地址始终为 0x0000
        xor bx, bx
        inc si
        call read_hard_disk
        loop @read_left_app

        pop ds              ; 恢复ds
    ; 至此，已将用户程序读至内存 0x10000处. 开始重定位用户程序段地址，及跳到用户程序开始执行
    ; 计算用户代码段的入口地址
    direct:
        mov dx, [0x08]      ; 用户程序段地址高16位
        mov ax, [0x06]      ; 用户程序段地址低16位
        call calc_segment_base
        mov [06], ax        ; 回填修正后的入口点代码段基址

    ; 用户程序段重定位
        mov cx, [0x0a]      ; 取出用户程序段个数
        mov bx, 0x0c        ; 取出用户程序段表首地址

    realloc:
        mov dx, [bx + 0x02]
        mov ax, [bx]
        call calc_segment_base
        mov [bx], ax
        add bx, 4
        loop realloc

        jmp far [0x04]



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

;-------------------------------------------------------------------------------
; 计算16位段基地址
; 输入 DX:AX=32位物理地址
; 输出 AX=16位段基地址
calc_segment_base:
            push dx

            ;用户程序段32位，低16位放在ax, 高16位放在dx
            add ax, [cs:phy_base]            ; 计算低16位
            adc dx, [cs:phy_base + 0x02]    ; 计算高16位
            shr ax, 4
            ror dx, 4
            and dx, 0xf000
            or ax, dx

            pop dx

            ret

;-------------------------------------------------------------------------------

         phy_base dd 0x10000             ;用户程序被加载的物理起始地址

 times 510-($-$$) db 0
                  db 0x55,0xaa