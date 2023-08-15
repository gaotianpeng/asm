
    core_base_address           equ 0x00040000      ; 内核加载的起始内存地址
    core_start_sector           equ 0x00000001      ; 起始逻辑扇区号
; ----------------------------------------------------
    ; 清屏
    xor ax, ax
    mov al, 0x03
    int 0x10

    ; 初始化栈段
    mov ax, cs
    mov ss, ax
    mov sp, 0x7c00

    ; 计算GDT所在的逻辑段地址
    mov eax, [cs:pgdt + 0x7c00 + 0x02]      ; pgdt 的物理地址
    xor edx, edx
    mov ebx, 16
    div ebx                                 ; 分解为16位逻辑地址

    mov ds, eax
    mov ebx, edx

    ; 跳过 0 号gdt描述符
    ; 创建 1 号gdt描述符，数据段，0~4GB
    mov dword [ebx + 0x08], 0x0000ffff      ; 基地址为0，段界限为0xffff
    mov dword [ebx + 0x0c], 0x00cf9200      ; 粒度为4kb，存储段描述符

    ; 创建 2 号gdt描述符，代码段
    mov dword [ebx + 0x10], 0x7c0001ff      ; 基地址为0x00007c00, 界限为0x1ff
    mov dword [ebx + 0x14], 0x00409800      ; 粒度为1字节，代码段描述符

    ; 创建 3 号gdt描述符，堆栈段
    mov dword [ebx + 0x18], 0x7c00fffe      ; 基地址为0x00007c00, 界限为0xfffe
    mov dword [ebx + 0x1c], 0x00cf9600      ; 粒度为4kb

    ; 创建 4 号gdt描述符，显示缓冲区
    mov dword [ebx + 0x20], 0x80007fff      ; 基地址为0x000B8000, 界限为0x7fff
    mov dword [ebx + 0x24], 0x0040920b      ; 粒度为字节

    ; 初始化描述符表寄存器GDTR
    mov word [cs:pgdt + 0x7c00], 39         ; 描述符表的界限

    lgdt [cs:pgdt + 0x7c00]

    ; 打开A20
    in al, 0x92
    or al, 0000_0010B
    out 0x92, al

    cli

    ; 设置PE位
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 进入保护模式
    jmp dword 0x0010:flush

    [bits 32]
flush:
    mov eax, 0x0008                         ; 加载数据段(0..4GB)选择子
    mov ds, eax

    mov eax, 0x0018                         ; 加载堆栈段选择子
    mov ss, eax
    xor esp, esp

    ; 加载系统核心程序
    mov edi, core_base_address
    mov eax, core_start_sector
    mov ebx, edi
    call read_hard_disk                     ; 读取核心程序的起始部分

    ; 判断整个程序有多大
    mov eax, [edi]                          ; 核心程序尺寸
    mov edx, edx
    mov ecx, 512
    div ecx

    or edx, edx
    jnz @1
    dec eax
@1:
    or eax, eax
    jz setup

    ; 读取剩余的扇区
    mov ecx, eax
    mov eax, core_start_sector
    inc eax                         ; 从下一个逻辑扇区接着读
@2:
    call read_hard_disk
    inc eax
    loop @2                         ; 循环读，直到读完整个内核

setup:
    ; 从标号pgdt处取得GDT的基地址，为其添加描述符，并修改它的大小
    ; 然后，用lgdt 指令重新加载一遍GDTR寄存器，使修改生效
    mov esi, [0x7c00 + pgdt + 0x02]

    ; 建立公用例程段描述符
    mov eax, [edi + 0x04]           ; 公用程序段代码起始汇编地址
    mov ebx, [edi + 0x08]           ; 核心数据段汇编地址
    sub ebx, eax                    ; 内核数据段的起始位置 - 公共例程段的起始汇编地址
    dec ebx                         ; 公用例程段界限，段界限在数值上等于：段的长度-1
    add eax, edi                    ; 公用例程段基地址: 内核的加载地址 + 公共例程段的起始汇编地址
    mov ecx, 0x00409800             ; 字节粒度的代码段描述符，P=1, G=0, DPL=0, S=1, TYPE=10000
    call make_gdt_descriptor
    mov [esi + 0x28], eax
    mov [esi + 0x2c], edx

    ; 建立核心数据段描述符
    mov eax, [edi + 0x08]           ; 核心数据段的起始汇编地址
    mov ebx, [edi + 0x0c]           ; 核心代码段汇编地址
    sub ebx, eax
    dec ebx
    add eax, edi                    ; 核心数据段界限
    mov ecx, 0x00409200             ; 字节粒度的数据段描述符
    call make_gdt_descriptor
    mov [esi + 0x30], eax
    mov [esi + 0x34], edx

    ; 建立核心代码段描述符
    mov eax, [edi + 0x0c]           ; 核心代码段起始汇编地址
    mov ebx, [edi + 0x00]           ; 程序总长度
    sub ebx, eax
    dec ebx                         ; 核心代码段界限
    add eax, edi                    ; 核心代码段基地址
    mov ecx, 0x00409800             ; 字节粒度的代码段描述符
    call make_gdt_descriptor
    mov [esi + 0x38], eax
    mov [esi + 0x3c], edx

    mov word [0x7c00 + pgdt], 63    ; 描述符表的界限

    lgdt [0x7c00 + pgdt]

    jmp far [edi + 0x10]

; ---------------------------------------------------
; 从硬盘读取一个逻辑扇区
; eax = 逻辑扇区号
; ds:ebx = 目标缓冲区
; 返回 ebx = ebx+512
read_hard_disk:
    push eax
    push ecx
    push edx

    push eax

    mov dx,0x1f2
    mov al,1
    out dx,al                       ; 读取的扇区数

    inc dx                          ; 0x1f3
    pop eax
    out dx,al                       ; LBA地址7~0

    inc dx                          ; 0x1f4
    mov cl,8
    shr eax,cl
    out dx,al                       ; LBA地址15~8

    inc dx                          ; 0x1f5
    shr eax,cl
    out dx,al                       ; LBA地址23~16

    inc dx                          ; 0x1f6
    shr eax,cl
    or al,0xe0                      ; 第一硬盘  LBA地址27~24
    out dx,al

    inc dx                          ; 0x1f7
    mov al,0x20                     ; 读命令
    out dx,al

.waits:
    in al,dx
    and al,0x88
    cmp al,0x08
    jnz .waits                      ; 忙

    mov ecx,256                     ; 总共要读取的次数
    mov dx,0x1f0
.readw:
    in ax, dx
    mov [ebx], ax
    add ebx, 2
    loop .readw

    pop edx
    pop ecx
    pop eax

    ret

; ----------------------------------------------------
; 构造描述符
; input     eax=线性基地址
;           ebx=段界限
;           ecx=属性
; output    edx:eax=完整的描述符
make_gdt_descriptor:
        mov edx, eax            ; 段基址传入 edx
        ; 构造描述符低32位：描述符低32位中，高16位是基地址，低16位是段界限
        shl eax, 16
        or ax, bx               ; 描述符前32位(eax)构造完毕

        and edx, 0xffff0000     ; 清除基地址中无关的位
        rol edx, 8
        bswap edx               ; 装配基地址的31~24位和23~16

        xor bx, bx
        or edx, ebx             ; 装配界限的高4位

        or edx, ecx             ; 装配属性

        ret

; ----------------------------------------------------
    pgdt                    dw 0            ; GDT的大小
                            dd 0x00007e00   ; GDT的物理地址
; ----------------------------------------------------
    times 510 - ($ - $$)    db 0x00
                            db 0x55, 0xaa
