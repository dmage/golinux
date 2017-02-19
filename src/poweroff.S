.code16

// connect real-mode interface
// http://www.delorie.com/djgpp/doc/rbinter/id/02/14.html
mov $0x5301, %ax
xor %bx, %bx
int $0x15

// driver version
// http://www.delorie.com/djgpp/doc/rbinter/id/18/14.html
mov $0x530e, %ax
xor %bx, %bx
mov $0x0102, %cx  /* APM v1.2 */
int $0x15

// turn off system
// http://www.delorie.com/djgpp/doc/rbinter/id/11/14.html
mov $0x5307, %ax
mov $0x0001, %bx
mov $0x0003, %cx
int $0x15

// MBR boot signature
.org 510
.word 0xaa55
