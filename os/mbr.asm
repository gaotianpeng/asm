        core_base_address equ 0x00040000            ; 内核加载的起始内存地址
        core_start_sector equ 0x00000001            ; 内核的起始逻辑扇区号

        mov ax, cs
        mov ss, ax
        mov sp, 0x7c00

        ; 计算GDT所在的逻辑段地址
        mov eax, [cs:pgdt + 0x7c00 + 0x02]          ; GDT的32位物理地址
        xor edx, edx
        mov ebx, 16
        div ebx                                     ; 分解成16位逻辑地址

        ; 跳过 0# 号描述符
        ; 1# 描述符，是一个数据段， 对应0~4GB的线性地址空间
        mov dword [ebx + 0x08], 0x0000ffff          ; 基地址为0，段界限为0xfffff
        mov dword [ebx + 0x0c], 0x00cf9200          ; 粒度为4KB, 存储器段描述符

        ; 2# 初始代码段描述符
        mov dword [ebx + 0x10], 0x7c0001ff          ; 基地址为 0x00007c00, 界限为1ff
        mov dword [ebx + 0x14], 0x00409800          ; 粒度为1个字节, 代码段描述符

        ; 3# 堆栈段描述符
        mov dword [ebx + 0x18], 0x7c00fffe          ; 基地址为0x00007C00，界限0xFFFFE
        mov dword [ebx + 0x1c], 0x00cf9600          ; 粒度为4KB

        ; 4# 显示缓冲区描述符
        mov dword [ebx + 0x20], 0x80007fff          ; 基地址为0xB800, 界限 0x07FFF
        mov dword [ebx + 0x24], 0x0040920b          ; 粒度为字节

        ; 初始化描述符表寄存器GDTR
        mov word [cs:pgdt + 0x7c00], 39             ; 设置段描述符界限

        lgdt [cs:pgdt + 0x7c00]

        in al, 0x92
        or al, 0000_0010B
        out 0x92, al                                ; 打开A20

        cli

        mov eax, cr0
        or eac, 1
        mov cr0, eax                                ; 设置PE位

        ; 进入保护模式
        jmp dword 0x0010, flush

        [bits 32]
    flush:
        mov eax, 0x0008                             ; 加载数据段选择子(0~4GB)
        mov ds, eax

        mov eax, 0x0018                             ; 加载堆栈段选择子
        mov ss, eax
        xor esp, esp

        ; 加载系统核心程序
        mov edi, core_base_address

        mov eax, core_start_sector
        mov ebx, edi
        call read_hard_disk

        ; 判断整个程序有多大
        mov eax, [edi]




; ---------------------------------------------------------------------
setup:

; ---------------------------------------------------------------------
read_hard_disk:



; ----------------------------------------------------------------------
make_gdt_descriptor:





; ----------------------------------------------------------------------
        pgdt        dw 0
                    dd 0x00007e00               ; GDT的物理地址


times 510 - ($-$$) db 0
db 0x55, 0xaa