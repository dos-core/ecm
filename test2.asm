
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

	lframe
	lvar word, qux
	lvar word, foo
	lenter

	mov word [bp + ?foo], bx

	lleave

	mov ax, word [bp + ?foo]

	lleave
	lret
