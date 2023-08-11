; 计算 1 + ... + 100 ，并在屏幕上显示
        jmp near start

        message db '1+2+3+...+100='
    start:
        ; 清屏
        ; 设置AH寄存器为0x00以选择"设置显示模式"子功能
        mov ah, 0x00
        ; 设置AL寄存器为0x03以选择文本模式 80x25
        mov al, 0x03
        int 0x10

        ; 设置数据段基地址
        mov ax, 0x7c0
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


times 510 - ($ - $$) db 0x00
db 0x55, 0xaa