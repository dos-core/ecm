
%if 0

doubles.asm - Find doubled LBA search strings
 2024 by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

	defaulting

	numdef IMAGE_EXE,	0
	numdef IMAGE_EXE_CS,	-16	; relative-segment for CS
	numdef IMAGE_EXE_IP,	256	; value for IP
		; The next two are only used if _IMAGE_EXE_AUTO_STACK is 0.
	numdef IMAGE_EXE_SS,	-16	; relative-segment for SS
	numdef IMAGE_EXE_SP,	0FFFEh	; value for SP (0 underflows)
	numdef IMAGE_EXE_AUTO_STACK,	2048, 2048
					; allocate stack behind image
	numdef IMAGE_EXE_MIN,	65536	; how much to allocate for the process
%ifndef _IMAGE_EXE_MIN_CALC
 %define _IMAGE_EXE_MIN_CALC	\
		(((_IMAGE_EXE_AUTO_STACK) + 15) & ~15)
%endif
	numdef IMAGE_EXE_MAX, 0


	org 0
	addsection EXEHEADER, vstart=0 start=0
exeheader:
	db "MZ"		; exeSignature
	dw (payload_size) % 512			; exeExtraBytes

		; Carries a .COM-like executable.
		; Note: With _IMAGE_EXE_AUTO_STACK, the
		;	 stack segment will be behind the image.
	dw (payload_size + 511) / 512		; exePages
	dw 0		; exeRelocItems
	dw (exeheader_size) >> 4	; exeHeaderSize
	dw (_IMAGE_EXE_MIN_CALC + 15) >> 4	; exeMinAlloc
%if _IMAGE_EXE_MAX
	dw _IMAGE_EXE_MAX	; exeMaxAlloc
%else
	dw (_IMAGE_EXE_MIN_CALC + 15) >> 4	; exeMaxAlloc
%endif
%if _IMAGE_EXE_AUTO_STACK
	dw ((payload_size) \
		+ _IMAGE_EXE_MIN_CALC \
		- _IMAGE_EXE_AUTO_STACK + 15) >> 4	; exeInitSS
		; ss: payload size minus 512 (conservative, assume DOS
		;  treats bogus exeExtraBytes as below 512 bytes.)
		; + exeMinAlloc
		; - auto stack size
	dw _IMAGE_EXE_AUTO_STACK		; exeInitSP
		; sp = auto stack size (eg 800h)
%else
	dw _IMAGE_EXE_SS	; exeInitSS
	dw _IMAGE_EXE_SP	; exeInitSP
%endif
	dw 0		; exeChecksum
	dw _IMAGE_EXE_IP, _IMAGE_EXE_CS	; exeInitCSIP
	dw 0		; exeRelocTable

	align 16, db 0
	endarea exeheader


	cpu 8086
	addsection CODE, follows=EXEHEADER vstart=256 align=16
start:

	mov ax, ds
	add ax, paras(256 + code_size)
	mov ds, ax
	mov es, ax

	lframe
	lvar word, meta
	lvar word, data
	lenter
	xor ax, ax
	lvar word, counter
	 push ax
	mov dx, meta
	mov bx, lba_search_metadata

.looppattern:
	mov di, [bx]
	test di, di
	jz .done
	mov cx, [bx + 2]
	mov word [bp + ?data], bx
	mov word [bp + ?meta], dx
	inc word [bp + ?counter]
@@:
	call next
	jz .nextpattern
	cmp word [bx + 2], cx
	jne @B
	mov si, [bx]
	push di
	push cx
	repe cmpsb
	pop cx
	pop di
	jne @B

%if 1
	mov si, msg.double.1
	call disp_msg_si
	mov si, word [bp + ?meta]
	mov ax, [si + 2]
	mov cx, ax
	call disp_ax_hex
	mov si, msg.double.2
	call disp_msg_si
	mov si, dx
	mov ax, [si + 2]
	call disp_ax_hex
	mov si, msg.double.4
	call disp_msg_si
	xor ax, cx
	call disp_ax_hex
	mov si, msg.double.5
	call disp_msg_si

	mov si, ldos_searchflags
	test cx, cx
	jns @F
	mov si, freedos_searchflags
@@:
	mov cx, msg.empty
@@:
	test word [si], ax
	jz @F
	push si
	push word [si + 2]
	mov si, cx
	call disp_msg_si
	mov cx, msg.searchflag.2
	pop si
	call disp_msg_si
	mov si, msg.searchflag.1
	call disp_msg_si
	pop si
@@:
	add si, 4
	cmp word [si], 0
	jne @BB
	mov si, msg.searchflag.eol
	call disp_msg_si
%else
	mov si, msg.double.1
	call disp_msg_si
	mov si, word [bp + ?meta]
	mov si, [si]
	call disp_msg_si
	mov si, msg.double.2
	call disp_msg_si
	mov si, dx
	mov si, [si]
	call disp_msg_si
	mov si, msg.double.3
	call disp_msg_si
%endif

.nextpattern:
	mov bx, word [bp + ?data]
	mov dx, word [bp + ?meta]
	call next
	jmp .looppattern

.done:
	mov ax, word [bp + ?counter]
	mov si, msg.done.1
	call disp_msg_si
	call disp_ax_dec
	mov si, msg.done.2
	call disp_msg_si

match:
	mov bx, all_lba_search_metadata
	mov dx, all_meta
	mov ax, ds
	add ax, paras(data1_size)
	mov es, ax

.looppattern:
	mov di, [es:bx]
	test di, di
	jz .done
	mov cx, [es:bx + 2]
	mov word [bp + ?data], bx
	mov word [bp + ?meta], dx

	mov bx, lba_search_metadata

@@:
	cmp word [bx + 2], cx
	jne @F
	mov si, [bx]
	push di
	push cx
	repe cmpsb
	pop cx
	pop di
	jne @F
.next:
	mov bx, word [bp + ?data]
	mov dx, word [bp + ?meta]
	push ds
	 push es
	 pop ds
	call next
	pop ds
	jz .done
	jmp .looppattern

@@:
	call next
	jnz @BB

	mov si, msg.notfound.1
	call disp_msg_si
	mov bx, word [bp + ?meta]
	push ds
	 push es
	 pop ds
	mov si, [bx]
	call disp_msg_si
	mov ax, [bx + 2]
	mov cx, ax
	pop ds
	mov si, msg.notfound.2
	call disp_msg_si

	mov si, ldos_searchflags
	test cx, cx
	jns @F
	mov si, freedos_searchflags
@@:
	mov cx, msg.empty
@@:
	push si
	test word [si], ax
	jz @F
	push word [si + 2]
	mov si, cx
	call disp_msg_si
	mov cx, msg.searchflag.2
	pop si
	call disp_msg_si
@@:
	pop si
	add si, 4
	cmp word [si], 0
	jne @BB
	mov si, msg.searchflag.eol
	call disp_msg_si

	mov si, ldos_searchflags
	test cx, cx
	jns @F
	mov si, freedos_searchflags
@@:
	mov cx, msg.empty
@@:
	push si
	test word [si], ax
	jnz @F
	push word [si + 2]
	mov si, cx
	call disp_msg_si
	mov cx, msg.searchflag.2
	pop si
	call disp_msg_si
	mov si, msg.searchflag.0
	call disp_msg_si
@@:
	pop si
	add si, 4
	cmp word [si], 0
	jne @BB
	mov si, msg.searchflag.eol
	call disp_msg_si

	jmp .next


.done:
	lleave ctx
	mov ax, 4C00h
	int 21h


next:
	add bx, 8
@@:
	cmp word [bx], 0
	lea bx, [bx + 2]
	jne @B
	add dx, 4
	cmp word [bx], 0
	retn


disp_msg_si:
	push es
	push di
	push ax
	push bx
	push cx
	push dx

	 push ds
	 pop es
	mov di, si
	mov dx, si
	mov al, 0
	mov cx, -1
	repne scasb
	not cx
	dec cx
	mov ah, 40h
	mov bx, 1
	int 21h

	pop dx
	pop cx
	pop bx
	pop ax
	pop di
	pop es
	retn


disp_ax_hex:
		xchg al, ah
		call disp_al_hex
		xchg al, ah
disp_al_hex:
		push cx
		mov cl, 4
		ror al, cl
		call .nibble
		ror al, cl
		pop cx
.nibble:
		push ax
		and al, 0Fh
		add al, '0'
		cmp al, '9'
		jbe .isdigit
		add al, 'A'-('9'+1)
.isdigit:
		push dx
		xchg dl, al
		mov ah, 02h
		int 21h
		pop dx
		pop ax
		retn


disp_ax_dec:
decword:
	push dx
	xor dx, dx
	call decdword
	pop dx
	retn


decdword:
	push cx
	xor cx, cx
	call dec_dword_minwidth
	pop cx
	retn


		; Dump dword as decimal number string
		;
		; INP:	dx:ax = dword
		;	cx = minimum width (<= 1 for none, must be < 10)
		;	es:di -> where to store
		; OUT:	es:di -> behind variable-length string
		; CHG:	-
		; STT:	UP
dec_dword_minwidth:
	lframe near
	lequ 12,	bufferlen
	lvar ?bufferlen,buffer
	lenter
	lvar dword,	dividend
	 push dx
	 push ax
	dec cx
	lvar word,	minwidth
	 push cx
	inc cx

	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push es

	 push ss
	 pop es

	lea di, [bp + ?buffer + ?bufferlen - 1]
	mov bx, di
	std			; _AMD_ERRATUM_109_WORKAROUND does not apply
	mov al, '$'
	stosb			; 21.09 dollar terminator

		; dword [bp + ?dividend] = number to display
	mov cx, 10		; divisor
.loop_write:

	xor dx, dx
	push di
	mov di, 4
.loop_divide:
	mov ax, [bp + ?dividend - 2 + di]
	div cx
	mov word [bp + ?dividend - 2 + di], ax
	dec di
	dec di
	jnz .loop_divide
				; dx = last remainder
	pop di
	xchg ax, dx		; ax = remainder (next digit)
				; dword [bp + ?dividend] = result of div
	add al, '0'
	stosb
	dec word [bp + ?minwidth]
	jns .loop_write

	cmp word [bp + ?dividend + 2], 0
	jnz .loop_write
	cmp word [bp + ?dividend], 0
				; any more ?
	jnz .loop_write		; loop -->

	cld

	sub bx, di
	mov cx, bx
	mov dx, di
	inc dx
	push ds
	 push ss
	 pop ds
	mov ah, 09h
	int 21h			; display to stdout
	pop ds

	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	lleave
	retn

	align 16
	code_size equ $ - start

	addsection DATA1, vstart=0 follows=CODE align=16
data1:

%define PREFIX
%assign ALL 0
%include "lbasuch.asm"

	align 2, db 0
meta:
dumpsearches METASEARCHES

	align 2, db 0
dumpsearches SEARCHFLAGS
	dw 0

dumpsearches METASTRINGS


	addsection DATA2, vstart=0 follows=DATA1 align=16
data2:
%define PREFIX all_
%assign ALL 1
%include "lbasuch.asm"

	align 2, db 0
all_meta:
dumpsearches METASEARCHES

dumpsearches METASTRINGS

	align 16, db 0
	endarea data2

	usesection DATA1
msg:
.double.1:	asciz "Double "
.double.2:	asciz ", "
.double.4:	asciz " XOR="
.double.5:	asciz " is "
.double.3:	asciz 13,10
.notfound.1:	asciz "Not found: "
.notfound.2:	asciz " is "
.done.1:	asciz "Processed "
.done.2:	asciz " strings.",13,10
.empty:		asciz
.searchflag.1:	asciz
.searchflag.2:	asciz ", "
.searchflag.0:	asciz "=0"
.searchflag.eol:asciz 13,10

	align 16, db 0
	endarea data1

payload_size equ code_size + data2_size + data2_size
