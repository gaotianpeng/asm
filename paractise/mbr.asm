; 主引导程序
section mbr vstart=0x7c00
        mov ax, cs
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov fs, ax
        mov sp, 0x7c00


; 清屏利用0x06号功能，上卷全部行，则可清屏
; INT 0x10      功能号:0x06    功能描述: 上卷窗口

; 输入：
;   ah 功能号=0x06
;   al = 上卷的行数，如果为0，表示全部
;   bh = 上卷行的属性
;   (CL, CH) = 窗口的左上角的(X, Y)位置
;   (DL, DH) = 窗口的右下角的(X, Y)位置
    mov ax, 0x600
    mov bx, 0x700

    mov cx, 0           ; 左上角:(0, 0)
    mov dx, 0x184f      ; 右下角:(80, 25)
    ; VGA文本模式中,一行只能容纳80个字符,共25行｡27　　　　　　　
    ; 下标从0开始,所以0x18=24,0x4f=79
    int 0x10

; 获取光标位置
    mov ah, 3           ; 输入：3号子功能是获取光标位置，需要存入ah寄存器
    mov bh, 0           ; bh 寄存器存储的是待获取光标的页号

    int 0x10            ; 输出：ch=光标的开始行，cl=光标结束行，dh=光标所在行号，dl=光标所在的列号

; 调用 13号子功能打印字符串
    mov ax, message
    mov bp, ax          ; es:bp 为串首地址

; 光标位置要用到dx寄存器中的内容，cx中的光标位置可忽略
    mov cx, 5           ; cx 为串长度，不包括结束符0的字符个数
    mov ax, 0x1301      ; 子功能号13显示字符及属性,要存入ah寄存器,
                        ; al设置写字符方式 ah=01: 显示字符串,光标跟随移动
    mov bx, 0x02        ; bh存储要显示的页号，此处是第0页
                        ; bl 中是字符属性，属性黑底绿字(bl=02h)
    int 0x10

    jmp $

message db "1 MBR"
    times 510 - ($ - $$) db 0
    db 0x55, 0xaa
























