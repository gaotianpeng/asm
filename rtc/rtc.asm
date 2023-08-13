section header vstart=0
        program_length          dd  program_end                             ; [0x00]

        code_entry              dw  start                                   ; [0x04]
                                dd  section.code.start                      ; [0x06]

        realloc_table_len       dw  (header_end - realloc_begin) / 4;       ; [0x0a]

    realloc_begin:
        code_segment            dd section.code.start                       ; [0x0c]
        data_segment            dd section.data.start                       ; [0x14]
        stack_segment           dd section.stack.start                      ; [0x1c]

header_end:

section code align=16 vstart=0

start:
    mov ax, [stack_segment]
    mov ss, ax
    mov sp, ss_pointer
    mov ax, [data_segment]
    mov ds, ax

    mov bx, init_msg                ; 显示初始信息
    call put_string
    mov bx, inst_msg                ; 显示安装信息
    call put_string

    jmp $

; 显示字符串(0结尾)
; 输入 DS:BX=串地址
put_string:
        mov cl, [bx]
        cmp cl, 0
        je .exit
        call put_char
        inc bx
        jmp put_string

    .exit:
        ret

; 显示一个字符
; 输入: cl=字符的ascii
put_char:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es

    ; 获取当前光标位置, 两个光标寄存器，索引分别是14, 15, 分别用于提供光标位置的高8位和低8位
    mov dx, 0x3d4       ; 端口0x3d4用于光标操作
    mov al, 14          ; 命令字节，指定高字节光标位置
    out dx, al          ; 发送命令字节到端口
    mov dx, 0x3d5       ; 端口0x3d5用于读取数据
    in al, dx           ; 读取高8位
    mov ah, al          ; 将光标高字节保存到ah寄存器

    mov dx, 0x3d4
    mov al, 15          ; 命令字节，指定低字节光标位置
    out dx, al
    mov dx, 0x3d5
    in al, dx           ; 读光标低字节
    mov bx, ax          ; 将光标位置的16位值保存到bx寄存器

    cmp cl, 0x0d        ; 是否是回车
    jnz .put_0a         ; 不是
    mov ax, bx          ; 将光标位置复制到ax寄存器
    mov bl, 80          ; 一行有80个字符
    div bl              ; 将光标位置除以80，得到行号
    mul bl              ; 将行号每次以80，得到行的起始位置
    mov bx, ax          ; 将行起始位置保存到bx寄存器
    jmp .set_cursor     ; 跳转到设置光标位置的代码处


.put_0a:
    cmp cl, 0x0a        ; 换行符？
    jnz .put_ch         ; 不是，正常显示字符
    add bx, 80          ; 增加光标位置，将光标移到下一行行首
    jmp .roll_screen    ; 处理滚屏操作


; 正常显示字符
.put_ch:
    mov ax, 0xb800
    mov es, ax
    shl bx, 1           ; 将光标位置每次以2，每个字符占两个字节
    mov [es:bx], cl     ; 将字符写入显存

    ; 推进光标位置到下一个字符
    shr bx, 1           ; 将光标位置右移1位, 除以2
    add bx, 1           ; 增加光标位置，指向下一个字符位置

.roll_screen:
    cmp bx, 2000        ; 光标超出屏幕?
    jl .set_cursor      ; 如果没有，跳转到设置光标位置的代码块

    ; 滚屏操作
    mov ax, 0xB800
    mov ds, ax
    mov es, ax
    cld                 ; 清除方向标志，用于字符串传输指令
    mov si, 0xa0        ; 源偏移，从第一行之外开始复制
    mov di, 0x00        ; 目标偏移，从第一行开始
    mov cx, 1920        ; 复制字符的总数量(80*24)
    rep movsw           ; 重复执行movsw指令，复制数据
    mov bx, 3840        ; 清屏屏幕底部一行的偏移位置
    mov cx, 80          ; 一行有80个字符

.cls:
    mov word [es:bx], 0x0720        ; 将空白字符写入显存，以清除一行
    add bx, 2           ; 增加偏移以处理下一字符
    loop .cls           ; 循环处理直到下一行清除完成

    mov bx, 1920        ; 将光标位置设置为新的屏幕底部

.set_cursor:
    ; 更新光标位置
    mov dx, 0x3d4       ; 设置光标位置的端口
    mov al, 14          ; 命令字节，高字节光标位置
    out dx, al
    mov dx, 0x3d5       ; 数据传输端口
    mov al, bh          ; 将光标高字节写入数据端口
    out dx, al
    mov dx, 0x3d4
    mov al, 15          ; 命令字节，低字节光标位置
    out dx, al          ; 发送命令到端口
    mov dx, 0x3d5       ; 数据传输端口
    mov al, bl          ; 将光标的低字节（bl）写入数据端口
    out dx, al          ; 将光标低字节写入数据端口

    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax

    ret

section data align=16 vstart=0
    init_msg            db 'Starting...', 0x0d, 0x0a, 0
    inst_msg            db 'Installing a new interrupt 70H...', 0
    done_msg            db 'Done.', 0x0d, 0x0a, 0
    tips_msg            db 'Clock is now working.', 0


section stack align=16 vstart=0
        resb 256
ss_pointer:

section program_trail
program_end:



















































