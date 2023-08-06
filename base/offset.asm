; nasm 默认16字节对齐
; offset 的用法
; offset 是一个用于获取标签（label）的地址或偏移量的操作符
; 它的作用是将标签所在的地址或偏移量转化为一个立即数（immediate value），以便在代码中引用该地址或偏移量

; section s1 4字节对齐，不足补0
section s1
    ;str1: 0x0100
    ;str2: 0x0105
    ;num:  0x0020
    offset dw str1, str2, num

section s2 align=32 vstart=0x100
    str1 db 'hello'
    str2 db 'world'

section s3 align=16
    num dw 0xbcd

