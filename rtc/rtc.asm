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
; 主要功能是在屏幕上显示实时时钟的小时、分钟和秒
; 代码首先等待RTC更新结束（等待UIP位为0），然后依次读取RTC的秒、分、时并转换为ASCII码后显示在屏幕上
new_int_0x70:
        push ax
        push bx
        push cx
        push dx
        push es

    .w0:
        mov al, 0x0a                ; 将0x0a（10）写入RTC的索引寄存器
        or al, 0x80                 ; 设置UIP位（RTC更新标志）为1，阻断NMI
        out 0x70, al                ; 发送命令到RTC到索引寄存器
        in al, 0x71                 ; 读取RTC状态寄存器A
        test al, 0x80               ; 测试第7位UIP是否为1, 即RTC是否正在更新
        jnz .w0                     ; 如果UIP为1, 说明RTC还在更新，继续等待

        ; 读取RTC的秒、分、时
        xor al, al
        or al, 0x80                 ; 设置UIP位为1，阻断NMI
        out 0x70, al                ; 发送命令到RTC的索引寄存器
        in al, 0x71                 ; 读取RTC的秒寄存器
        push ax                     ; 保存读取的秒

        mov al, 2                   ; 将2号写入RTC的索引寄存器，准备读取RTC的分
        or al, 0x80
        out 0x70, al
        in al, 0x71                 ; 读取RTC的分寄存器
        push ax                     ; 保存读取的分

        mov al, 4                   ; 将4号写入RTC的索引寄存器，准备读取RTC的时
        or al, 0x80
        out 0x70, al
        in al, 0x71                 ; 读取RTC的时寄存器
        push ax                     ; 保存读取的时

        mov al, 0x0c                ; 将0x0c写入RTC的索引寄存器，以准备读取寄存器C
        out 0x70, al
        in al, 0x71                 ; 读取RTC的寄存器C，确保中断只发生一次

        mov ax, 0xb800
        mov es, ax

        ; 显示读取的时、分、钞
        pop ax                      ; 恢复读取的时
        call bcd_to_ascii
        mov bx, 12*160 + 36*2       ; 屏幕上的位置

        mov [es:bx], ah             ; 显示小时的高位
        mov [es:bx + 2], al         ; 显示小时的低位

        mov al, ':'                 ; 显示分隔符
        mov [es:bx + 4], al

        not byte [es:bx + 5]        ; 反转显示属性(颜色)

        pop ax                      ; 恢复读取的分
        call bcd_to_ascii
        mov [es:bx + 6], ah         ; 显示分钟的高位
        mov [es:bx + 8], al         ; 显示分钟的低位

        mov al, ':'                 ; 显示分隔符
        mov [es:bx + 10], al

        not byte [es:bx + 11]       ; 反转显示属性(颜色)

        pop ax                      ; 恢复读取的秒
        call bcd_to_ascii
        mov [es:bx + 12], ah        ; 显示秒的高位
        mov [es:bx + 14], al        ; 显示秒的低位

        mov al, 0x20                ; 中断结束命令EOI
        out 0xa0, al                ; 向从片发送EOI
        out 0x20, al                ; 向主片发送EOI

        pop es
        pop dx
        pop cx
        pop bx
        pop ax

        iret

bcd_to_ascii:
    mov ah, al       ; 复制al到ah寄存器，备份低4位
    and al, 0x0f      ; 将al的值与0x0f进行按位与操作，仅保留低4位（个位）
    add al, 0x30      ; 将低4位的值加上0x30，转换成ASCII码

    shr ah, 4         ; 将ah寄存器的值逻辑右移4位，获取高4位的值（十位）
    and ah, 0x0f      ; 将ah的值与0x0f进行按位与操作，仅保留低4位（十位）
    add ah, 0x30      ; 将低4位的值加上0x30，转换成ASCII码（十位）

    ret               ; 返回，将转换后的ASCII码保存在AX寄存器中

; BCD（Binary-Coded Decimal）码是一种用二进制数来表示十进制数字的编码方式。
; 在BCD编码中，每个十进制数位用4位二进制数来表示，通常是将十进制的0到9每个数字分别编码为4位二进制，从0000到1001。
; 这种编码方式使得每个BCD码可以直接对应一个十进制数字，便于数字的处理和转换
; 将一个BCD（二进制码十进制）格式的数值转换为ASCII码表示，分别转换十位和个位的数字，
; 并将结果存储在AH和AL寄存器中。函数最后通过ret指令返回，此时AH中存储着十位的ASCII码，AL中存储着个位的ASCII码
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

    ; 计算0x70号中断在IVT（中断向量表）中的偏移地址
    mov al, 0x70
    mov bl, 4
    mul bl                          ; 将al乘以4，计算偏移
    mov bx, ax                      ; 将计算的偏移保存到bx


    cli                             ; 禁用中断，防止改动期间发生新的 0x70 号中断

    push es
    mov ax, 0x0000
    mov es, ax                      ; 设置es寄存器为0，用于访问IVT
    mov word [es:bx], new_int_0x70  ; 设置中断处理程序的偏移地址
    mov word [es: bx + 2], cs       ; 设置中断处理程序的段地址
    pop es

    mov al, 0x0b                    ; 设置RTC寄存器B
    or al, 0x80                     ; 阻断NMI
    out 0x70, al

    mov al, 0x12                    ; 设置寄存器B，禁止周期性中断，开放新结束后中断，BCD码，24小时制
    out 0x71, al

    mov al, 0x0c                    ; 设置RTC寄存器C
    out 0x70, al
    in al, 0x71                     ; 读RTC寄存器C，复位未决的中断状态

    in al, 0xa1                     ; 读8259 从片的IMR寄存器
    and al, 0xfe                    ; 清除bit 0
    out 0xa1, al                    ; 将修改后的IMR寄存器写回

    sti                             ; 放开中断

    mov bx, done_msg                ; 显示安装完成信息
    call put_string

    mov bx, tips_msg                ; 显示提示信息
    call put_string

    mov cx, 0xb800
    mov ds, cx
    mov byte [12*160 + 33*2], '@'

.idle:
    hlt                              ; 使CPU进入低功耗状态，直到有中断唤醒
    not byte [12*160 + 33*2 + 1]
    jmp .idle

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



















































