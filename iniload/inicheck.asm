
%if 0

lDOS iniload checksum test

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"
%include "inicheck.mac"


	defaulting

	numdef STANDALONE, 1
	numdef AMOUNT, 1


%if _STANDALONE
	cpu 8086
	org 0
start:
	mov ax, cs
	add ax, 10h			; => program image
	mov bx, .continue		; -> entry point WRT org 0
	push ax
	push bx
	retf

	align 16
.continue:
	push cs
	pop ds
	push cs
	pop es

	mov si, checksumheader
	mov cx, CHECKSUMHEADER_size / 2
	xor bx, bx
@@:
	cmp si, ..@checksumfield
	 lodsw
	jne @F
	 xor ax, ax
@@:
	add bx, ax
	loop @BB

	mov dx, msg.header_success
	test bx, bx
	jz @F
	mov dx, msg.header_failure
@@:
	call disp_message

	mov ax, bx
	call disp_ax_hex

	mov dx, msg.header_end
	call disp_message

	mov cx, word [..@checksumfield]
	xor ax, ax
	mov dx, msg.no_test.1
	mov bl, 02h
	testopt [..@checksumtype], 8000h
	jnz @F

	call checksum_crc16_6_paragraphs_start_cs

	push cs
	pop ds
	push cs
	pop es

	mov cx, word [..@checksumfield]
	cmp ax, cx
	mov dx, msg.success.1
	mov bl, 00h
	je @F
	mov dx, msg.failure.1
	mov bl, 01h
@@:
	call disp_message

	call disp_ax_hex

	mov dx, msg.2
	call disp_message

	mov ax, cx
	call disp_ax_hex

	mov dx, msg.3
	call disp_message

startoffset1 equ checksumheader0 + fromparas(paras(CHECKSUMHEADER_size)) - $$
%assign ii 1
%assign startoffset startoffset1
%rep _AMOUNT - 1
	push cs
	pop ds
	push cs
	pop es

	push bx
	mov si, checksumheader %+ %[ii]
	mov cx, CHECKSUMHEADER_size / 2
	xor bx, bx
@@:
	cmp si, ..@checksumfield %+ %[ii]
	 lodsw
	jne @F
	 xor ax, ax
@@:
	add bx, ax
	loop @BB

	mov dx, msg.header_success
	test bx, bx
	jz @F
	mov dx, msg.header_failure
@@:
	call disp_message

	mov ax, bx
	call disp_ax_hex

	mov dx, msg.header_end
	call disp_message
	pop bx

	mov cx, word [..@checksumfield %+ %[ii]]
	xor ax, ax
	mov dx, msg.no_test.1
	testopt [..@checksumtype %+ %[ii]], 8000h
	jz @F
	or bl, 2
	jmp @FF
@@:

	push bx
	mov ax, cs
	add ax, paras(startoffset)
	mov cx, CHECKSUM_SIZE_P - paras(startoffset)
	call checksum_crc16_6_paragraphs_start_ax_length_cx
	pop bx

	push cs
	pop ds
	push cs
	pop es

	mov cx, word [..@checksumfield %+ %[ii]]
	cmp ax, cx
	mov dx, msg.success.1
	je @F
	mov dx, msg.failure.1
	or bl, 1
@@:
	call disp_message

	call disp_ax_hex

	mov dx, msg.2
	call disp_message

	mov ax, cx
	call disp_ax_hex

	mov dx, msg.3plus
	call disp_message

	mov ax, CHECKSUM_SIZE_P - paras(startoffset)
	call disp_ax_dec

	mov dx, msg.4
	call disp_message

%assign ii ii + 1
%assign startoffset startoffset + fromparas(paras(CHECKSUMHEADER_size))
%endrep

	mov al, bl
	mov ah, 4Ch
	int 21h

	align 16
%assign num $ - .continue
%warning Main program size = num


msg:
.header_success:asciz "Header success, sum="
.header_failure:asciz "Header failure, sum="
.header_end:	asciz "h",13,10
.no_test.1:	asciz "No_Test! ax="
.failure.1:	asciz "Failure! ax="
.success.1:	asciz "Success! ax="
.2:		asciz "h [..@checksumfield]="
.3:		db "h length="
CHECKSUM_SIZE_P equ (end - $$) / 16
		_autodigits CHECKSUM_SIZE_P
.4:		asciz " paragraphs",13,10
.3plus:		asciz "h length="


%define ii
%assign startoffset 0
%rep _AMOUNT
	align 16
checksumheader %+ %[ii]:
	istruc CHECKSUMHEADER
at cshSignature,		dw "CS"
at cshLengthBytesStructure,	dw CHECKSUMHEADER_size
at cshOffsetStructure,		dw checksumheader %+ %[ii] - $$ - startoffset
at cshChecksumStructure,	dw \
	10000h-(("CS" + CHECKSUMHEADER_size \
		 + (checksumheader %+ %[ii] - $$ - startoffset) \
		 + 8006h + CHECKSUM_SIZE_P - paras(startoffset) \
		 + 0 + 0) & 0FFFFh)
at cshTypeChecksum
..@checksumtype %+ %[ii]:	dw 8006h
at cshAmountParagraphsData,	dw CHECKSUM_SIZE_P - paras(startoffset)
at cshChecksumData
..@checksumfield %+ %[ii]:	dw 0
at cshReserved,			dw 0
	iend
%assign ii ii + 1
%assign startoffset $ - $$
%endrep

	align 16
%endif


checksum_crc16_6_paragraphs_start_cs:
.:
	push bp
	mov bp, cs
	mov cx, CHECKSUM_SIZE_P
	mov bx, 1D0Fh
%if 0
	jcxz .end			; if empty -->
%else
 %if CHECKSUM_SIZE_P == 0
  %error Expected non-zero size
 %endif
%endif

.loop_segment:
	mov ds, bp
	xor si, si			; ds:si -> next segment to check
	sub cx, 1000h			; cmp cx, 1000h
	jae .not_last_segment		; (jnc)
	add cx, 1000h			; restore cx
	jz .end				; if it was zero, end -->
	shl cx, 1
	shl cx, 1
	shl cx, 1			; to words
	push si				; push a zero
	jmp @F

.not_last_segment:
	push cx
	mov cx, 8000h			; 8000h words = 1_0000h bytes = 64 KiB
@@:

.loop_word:
	mov ax, cs
	cmp ax, bp			; cs (first segment) ?
	jne @F				; no --> (NZ)
	cmp si, ..@checksumfield	; checksum field ?
@@:		; if NZ: lodsw, if ZR: lodsw then xor ax, ax
	 lodsw				; load word
	jne @F				; no, use loaded word value -->
	 xor ax, ax			; set to zero instead
@@:
	xchg al, ah
	mov dx, (16 << 8)
	xor bx, ax
.loop_bit:
	shl bx, 1
	jnc @F
	xor bx, 1021h
@@:
	dec dh
	jnz .loop_bit
	loop .loop_word

	pop cx
	add bp, 1000h			; => next segment
	jmp .loop_segment

.end:
	xchg ax, bx
	pop bp
	retn


%if _AMOUNT > 1
checksum_crc16_6_paragraphs_start_ax_length_cx:
.:
	push bp
	mov bp, ax
	mov di, ax
	mov bx, 1D0Fh
	jcxz .end			; if empty -->

.loop_segment:
	mov ds, bp
	xor si, si			; ds:si -> next segment to check
	sub cx, 1000h			; cmp cx, 1000h
	jae .not_last_segment		; (jnc)
	add cx, 1000h			; restore cx
	jz .end				; if it was zero, end -->
	shl cx, 1
	shl cx, 1
	shl cx, 1			; to words
	push si				; push a zero
	jmp @F

.not_last_segment:
	push cx
	mov cx, 8000h			; 8000h words = 1_0000h bytes = 64 KiB
@@:

.loop_word:
	cmp di, bp			; cs (first segment) ?
	jne @F				; no --> (NZ)
	cmp si, cshChecksumData		; checksum field ?
@@:		; if NZ: lodsw, if ZR: lodsw then xor ax, ax
	 lodsw				; load word
	jne @F				; no, use loaded word value -->
	 xor ax, ax			; set to zero instead
@@:
	xchg al, ah
	mov dx, (16 << 8)
	xor bx, ax
.loop_bit:
	shl bx, 1
	jnc @F
	xor bx, 1021h
@@:
	dec dh
	jnz .loop_bit
	loop .loop_word

	pop cx
	add bp, 1000h			; => next segment
	jmp .loop_segment

.end:
	xchg ax, bx
	pop bp
	retn
%endif


%if _STANDALONE
	align 16
%assign num $ - .
%warning Checksumming size = num


		; INP:	ds:dx -> message
		;	cx = length
		; CHG:	-
		; STT:	ds, es don't care
disp_message_length_cx:
	push bx
	push ax
	mov bx, 1
	mov ah, 40h
	int 21h
	pop ax
	pop bx
	retn


		; INP:	ds:dx -> message, ASCIZ
		; CHG:	-
		; STT:	ds, es don't care
disp_message:
	push cx
	push ax
	push di
	push es
	 push ds
	 pop es
	mov di, dx
	mov cx, -1
	mov al, 0
	repne scasb
	pop es
	pop di
	not cx
	dec cx
	call disp_message_length_cx
	pop ax
	pop cx
	retn


		; INP:	al = character to display
		; CHG:	-
		; STT:	ds, es don't care
disp_al:
	push ds
	push dx
	push cx
	push bx
	push ax
	mov dx, sp
	 push ss
	 pop ds
	mov cx, 1
	mov bx, 1
	mov ah, 40h
	int 21h
	pop ax
	pop bx
	pop cx
	pop dx
	pop ds
	retn


		; Display number in ax hexadecimal, always 4 digits
		;
		; INP:	ax = number
		; OUT:	displayed using disp_al
		; CHG:	none
disp_ax_hex:
	xchg al, ah
	call disp_al_hex
	xchg al, ah
disp_al_hex:
	push cx
	mov cl, 4
	rol al, cl
	call disp_al_nybble_hex
	rol al, cl
	pop cx
disp_al_nybble_hex:
	push ax
	and al, 0Fh
	add al, '0'
	cmp al, '9'
	jbe @F
	add al, -'9' -1 +'A'
@@:
	call disp_al
	pop ax
	retn


		; Display number in ax decimal
		;
		; INP:	ax = number
		; OUT:	displayed using disp_al
		; CHG:	none
disp_ax_dec:			; ax (no leading zeros)
		push bx
		xor bx, bx
.pushax:
		push dx
		push ax
		or bl, bl
		jz .nobl
		sub bl, 5
		neg bl
.nobl:
		push cx
		mov cx, 10000
		call .divide_out
		mov cx, 1000
		call .divide_out
		mov cx, 100
		call .divide_out
		mov cl, 10
		call .divide_out
							; (Divisor 1 is useless)
		add al, '0'
		call disp_al
		pop cx
		pop ax
		pop dx
		pop bx					; Caller's register
		retn


		; INP:	ax = number
		;	cx = divisor
		; OUT:	ax = remainder of operation
		;	result displayed
.divide_out:
		push dx
		xor dx, dx
		div cx				; 0:ax / cx
		push dx				; remainder
		dec bl
		jnz .nobl2
		or bh, 1
.nobl2:
		or bh, al
		jz .leadingzero
		add al, '0'
		call disp_al			; display result
 .leadingzero:
		pop ax				; remainder
		pop dx
		retn


	align 16
	numdef TESTDATA, 1
%if _TESTDATA
	times 120 * 1024 db 26h
%endif

	align 16
end:
%endif
