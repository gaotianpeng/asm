SECTION header vstart=0                     ;定义用户程序头部段
    program_length  dd program_end          ;程序总长度[0x00]

    ;用户程序入口点
    code_entry      dw start                ;偏移地址[0x04]
                    dd section.code_1.start ;段地址[0x06]

    realloc_tbl_len dw (header_end-code_1_segment)/4
                                            ;段重定位表项个数[0x0a]

    ;段重定位表
    code_1_segment  dd section.code_1.start ;[0x0c]

    header_end:

;===============================================================================
SECTION code_1 align=16 vstart=0         ;定义代码段1（16字节对齐）
        message db '1+2+3+...+100='
    start:
        ; 清屏
        ; 设置AH寄存器为0x00以选择"设置显示模式"子功能
        mov ah, 0x00
        ; 设置AL寄存器为0x03以选择文本模式 80x25
        mov al, 0x03
        int 0x10

        ; 设置数据段基地址
        mov ax, cs
        mov ds, ax

        ; 设置附加段基址到显示缓冲区
        mov ax, 0xb800
        mov es, ax

        ; 显示字符串
        mov si, message
        mov di, 0
        mov cx, start - message
    @g:
        mov al, [si]
        mov [es:di], al
        inc di
        mov byte [es:di], 0x07
        inc di
        inc si
        loop @g

        ; 计算1到100的和
        xor ax, ax
        mov cx, 1
    @f:
        add ax, cx
        inc cx
        cmp cx, 100
        jle @f


        ; 计算累加和的每个数位
        xor cx, cx
        mov ss, cx
        mov sp, cx

        mov bx, 10
        xor cx, cx
    @d:
        inc cx
        xor dx, dx
        div bx
        or dl, 0x30
        push dx
        cmp ax, 0
        jne @d

        ; 显示各个数位
    @a:
        pop dx
        mov [es:di], dl
        inc di
        mov byte [es:di], 0x07
        inc di
        loop @a

        jmp near $

SECTION trail align=16
program_end: