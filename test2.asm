
%include "lmacros2.mac"

[map symbols brief test2.map]
	cpu 8086
	org 256
	sectalign off
	section lCode start=256 align=1

	call fun1
	push ax
	call fun2
	push bx
	push cx
	call fun3
	pop bx
	call fun4
	call fun5
	call fun6
	call fun7
	call fun8
	call fun9
	call fun10
	call fun11
	call fun12

	mov ax, 4C00h
	int 21h

fun1:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter
	lvar word, quux
	 push ax

	lleave
	lret

fun2:
	lframe near
	lpar word, alpha
	lvar word, foo
	lvar word, bar
	lenter
	lvar word, quux
	 push ax

	mov word [bp + ?foo], 0F00h
	mov dx, word [bp + ?alpha]

	lleave
	lret

fun3:
	lframe near
	lpar word, beta
	lpar_return
	lpar word, alpha
	lvar word, foo
	lvar word, bar
	lenter
	lvar word, quux
	 push ax

	mov word [bp + ?beta], 0BE7Ah

	lleave
	lret

fun4:
	lframe near
	lenter early
	lvar word, foo
	 push bx
	lvar word, bar
	lenter
	lvar word, quux
	 push ax

	lleave
	lret

fun5:
	lframe near
	lenter
	lvar word, foo
	 push bx
	lvar word, bar
	lreserve
	lvar word, quux
	 push ax

	lleave
	lret

fun6:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	lframe 0, nested
	lvar word, qux
	lvar word, foo
	lenter

	mov word [bp + ?foo], bx

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun7:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	lframe 0, inner
	lvar word, qux
	lvar word, foo
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun8:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	push cs
	push si

	lframe 0, inner
	lpar word, segment
	lpar word, offset
	lvar word, qux
	lvar word, foo
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]
	mov bx, word [bp + ?segment]
	mov dx, word [bp + ?offset]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun9:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	push cs
	push si

	lframe 0, inner
	lpar word, segment
	lpar word, offset
	lvar word, qux
	lvar word, foo
	lvar word, xyzzy
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]
	mov bx, word [bp + ?segment]
	mov dx, word [bp + ?offset]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun10:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	push cs
	push si

	lframe 0, inner
	lpar word, segment
	lpar word, offset
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]
	mov bx, word [bp + ?segment]
	mov dx, word [bp + ?offset]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun11:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter

	mov word [bp + ?foo], ax

	push cs
	push si

	lframe 0, inner
	lpar word, segment
	lpar_return
	lpar word, offset
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]
	mov bx, word [bp + ?segment]
	mov dx, word [bp + ?offset]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret

fun12:
	lframe near
	lvar word, foo
	lvar word, bar
	lenter
	lvar word, baz

	mov word [bp + ?foo], ax

	lframe 0, inner
	lvar word, quux
	lvar word, foo
	lenter

	mov word [bp + ?foo], bx
	mov ax, word [bp + ?bar]
	mov bx, word [bp + ?quux]
	mov dx, word [bp + ?baz]

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret
