; 从键盘读取字符并显示
section header vstart=0
        program_length dd program_end

        code_entry              dw start
                                dd section.code.start

        realloc_table_len       dw (header_end - realloc_begin) / 4

    realloc_begin:
        code_segment            dd  section.code.start
        data_segment            dd  section.data.start
        stack_segment           dd  section.stack.start

header_end:

section code align=16 vstart=0
start:
        mov ax, [stack_segment]
        mov ss, ax
        mov sp, ss_pointer
        mov ax, [data_segment]
        mov ds, ax

        mov cx, msg_end - message       ; 计算消息的长度
        mov bx, message                 ; 将字符串的起始地址加载到BX寄存器

    .putc:
        mov ah, 0x0e                    ; 选择tty模式
        mov al, [bx]                    ; 将要打印的字符加载到al
        int 0x10                        ; 调用BIOS中断0x10,在屏幕上显示字符
        inc bx                          ; 递增bx以指向下一个字符
        loop .putc


    .reps:
        mov ah, 0x00                    ; BIOS 等待键盘输入
        int 0x16                        ; 调用BIOS 0x16号中断, 等待键盘输入

        mov ah, 0x0e                    ; 选择TTY模式
        mov bl, 0x07                    ; 设置显示属性（颜色）
        int 0x10                        ; 调用BIOS中断0x10以在屏幕上显示空字符（清除之前的输入）
        jmp .reps

section data align=16 vstart=0
    message       db 'Hello, friend!',0x0d,0x0a
                  db 'This simple procedure used to demonstrate '
                  db 'the BIOS interrupt.',0x0d,0x0a
                  db 'Please press the keys on the keyboard ->'
    msg_end:

section stack align=16 vstart=0
        resb 256
    ss_pointer:

section trail align=16
program_end:

