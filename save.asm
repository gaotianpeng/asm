; 内存规划
;   栈段地址空间 0x0000 ~ 0x7c00
;   mbr        0x7c00 ~ 0x7c20
;   GDT        0x7e00 ~ 0x17dff (64kb)


        ; 清屏
        xor ax, ax
        mov al, 0x03
        int 0x10

        ; 设置堆栈段和栈指针
        mov ax, cs
        mov ss, ax
        mov sp, 0x7c00      ; ss:sp  0x0000:0x7c00

        ; 计算GDT所在的逻辑段地址
        ; 现在处于实模式下，在GDT中安装描述符，必须将GDT的线性地址(物理地址)转换成逻辑段地址和偏移地址
        mov ax, [cs:gdt_base + 0x7c00]          ; 低16位
        mov dx, [cs:gdt_base + 0x7c00 + 0x02]   ; 高16位
        ; 将线性地址转换为逻辑地址，方法是将 DX:AX/16，得到的商是逻辑段地址，余数是偏移地址
        mov bx, 16
        div bx
        mov ds, ax                              ; 令DS指向该段以进行操作
        mov bx, dx                              ; 段内起始偏移地址

        ; step 1创建GDT表
        ; 创建0#描述符，它是空描述符，这是处理器的要求
        mov dword [bx+0x00], 0x00
        mov dword [bx+0x04], 0x00

        ; 创建#1描述符，保护模式下的代码段描述符
        ; 线性基地址为 0x001ff, 粒度为字节(G=1)，段长度为512字节
        ; S=1 是代码段或数据段，D=1是32位的段，P=1位于内存中，DPL=00 特权级为0，TYPE=1000是一个只能执行的代码段
        ; 该描述符指向正在执行的主导引程序所在的区域
        mov dword [bx+0x08], 0x7c0001ff
        mov dword [bx+0x0c], 0x00409800

        ; 创建#2描述符，保护模式下的数据段描述符（文本模式下的显示缓冲区）
        ; 线性基地址为 0x000B800，粒度为字节(G=0), 段界限为0x0FFFF，段长度为64kb
        ; S=1, D=1, P=1,DPL=00,TYPE=0010是一个可读可写、向上扩展的数据段
        mov dword [bx+0x10],0x8000ffff
        mov dword [bx+0x14],0x0040920b

        ; 创建#3描述符，保护模式下的堆栈段描述符
        ; 线性基地址为 0x00000000，粒度为字节(G=0), 段界限为0x07A00
        ; S=1, D=1, P=1,DPL=00,TYPE=0110是一个可读可写、向下扩展的数据段
        mov dword [bx+0x18],0x00007a00
        mov dword [bx+0x1c],0x00409600

        ; 初始化描述符表寄存器GDTR
        mov word [cs: gdt_size + 0x7c00], 31    ; 描述符表的界限（总字节数减一）

        ; 加载描述符表的线性基地址和界限到GDTR寄存器
        ; 6字节，低16位是GDT界限值，高32位是GDT的基地址
        lgdt [cs: gdt_size + 0x7c00]

        ; step2 打开A20
        in al,0x92                              ; 南桥芯片内的端口
        or al,0000_0010B
        out 0x92,al                             ; 打开A20

        ; step 3 关中断
        cli                                     ; 保护模式下中断机制尚未建立，应禁止中断
        ; step 4 打开PE
        mov eax, cr0
        or eax, 1
        mov cr0, eax                            ; 设置PE位

        ; 以下进入保护模式... ...
        ; 跳转到GDT第1号索引的代码段开始执行
        jmp dword 0x0008:flush                  ; 16位的描述符选择子：32位偏移
                                                ; 清流水线并串行化处理器
        [bits 32]

    flush:
        mov cx, 00000000000_10_000B              ; 加载数据段选择子(0x10)
        mov ds, cx

        ; 在屏幕上显示"Protect mode OK."
        mov byte [0x00], 'P'
        mov byte [0x02], 'r'
        mov byte [0x04], 'o'
        mov byte [0x06], 't'
        mov byte [0x08], 'e'
        mov byte [0x0a], 'c'
        mov byte [0x0c], 't'
        mov byte [0x0e], ' '
        mov byte [0x10], 'm'
        mov byte [0x12], 'o'
        mov byte [0x14], 'd'
        mov byte [0x16], 'e'
        mov byte [0x18], ' '
        mov byte [0x1a], 'O'
        mov byte [0x1c], 'K'

        ; 32位保护模式下的堆栈操作
        mov cx, 00000000000_11_000B         ; 加载堆栈段选择子
        mov ss, cx
        mov esp, 0x7c00

        mov ebp, esp                        ; 保存堆栈指针
        push byte '.'                       ; 压入立即数（字节）

        sub ebp, 4
        cmp ebp, esp                        ; 判断压入立即数时，ESP是否减4
        jnz ghalt
        pop eax
        mov [0x1e], al                      ; 显示句点

    ghalt:
        hlt                                 ; 已经禁止中断，将不会被唤醒

;-------------------------------------------------------------------------------
        gdt_size         dw 0
        gdt_base         dd 0x00007e00     ; GDT的物理地址

        times 510-($-$$) db 0
                      db 0x55,0xaa