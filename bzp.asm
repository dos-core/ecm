
%if 0

8086 Assembly lDOS iniload payload bzpack depacker
 by C. Masloch, 2021

BSD 2-Clause License

Copyright (c) 2021, Milos Bazelides
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

%endif


%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 0


		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	if _IMAGE_EXE:
		;	 bx = EXE mode flag (bit 0)
		;	else:
		;	 bx = 0
		;	if _PAYLOAD_KERNEL_MAX_PARAS:
		;	 ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
		;	else:
		;	 ax = -1
		; OUT:	NC if success
		;	CY if error,
		;	 bx = ?errordata (if _DEBUG0)
		; CHG:	ax, (bx), cx, dx, es, ds, si, di
		; STT:	UP
		;
		; Note:	The destination reaches up to below the source.
		; Note:	The input pointers need not be normalised yet.
		;	 Normalised means that the offset part is below 16.
depack:
	lframe near
	lenter
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _DEBUG0 || _COUNTER
	xor bx, bx
  %if _DEBUG0
	lvar word,	errordata
	 push bx
  %endif
  %if _COUNTER
	lvar word,	counter
	 push bx		; initialise counter to zero
  %endif
 %endif

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx

%if _PAYLOAD_KERNEL_MAX_PARAS
	cmp ax, -1		; no maximum specified ?
	je @FF			; retain -1 in ax -->
	test di, di		; do we need an additional paragraph ?
	jz @F			; no -->
	inc ax			; es + ax => paragraph after necessary part
@@:
	mov dx, es
	add ax, dx		; => paragraph after necessary part
		; If the normalised destination pointer's segment grows
		;  to this segment then enough has been decompressed.
d0	mov byte [bp + ?errordata], 40h
	jc .error_CY		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax
%endif

	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	xchg cx, ax		; bx:cx = source linear

	 push es
	 push di
	call pointer_to_linear

%if _ALLOW_OVERLAPPING
	add cx, word [bp + ?length_of_source]
	adc bx, word [bp + ?length_of_source + 2]
		; In case of allowing overlapping source and destination,
		;  the ?length_of_destination variable is set to
		;  ?src + ?length_of_source - ?dst, allowing to write to
		;  all of the source buffer (with the checks already in place
		;  from the default handling). Additional checks are done by
		;  calling check_pointers_not_overlapping. This is done after
		;  every change of ?dst to verify that the write pointer stays
		;  below-or-equal the read pointer.
		; This means the remaining source data may be corrupted by a
		;  write, but nothing after the source data is written to,
		;  so the error handling (in INIT1 after the data) still works.
%endif

	sub cx, ax
	sbb bx, dx		; bx:cx = source linear - destination linear

	lvar dword,	length_of_destination
	 push bx		; push into [bp + ?length_of_destination + 2]
	 push cx		; push into [bp + ?length_of_destination]

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error_CY
%endif

	xor dx, dx		; dh = mask, dl = bitbyte

.loop:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif
	; call decode_elias_1		; cx = value of length
		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	Only returns iff successful,
		;	 cx = decoded value
		;	 ds:si incremented by at most 32,
		;	 not normalised
		;	Jumps to depack.error_CY if failure
		; CHG:	ax
; decode_elias_1:
	xor cx, cx			; value = 0 (next inc sets it to 1)
@@:
	inc cx				; value += 1
@@:
	call getbit
	jz @F				; read zero
	shl cx, 1			; value <<= 1
	jc .error_CY			; value error
	call getbit
	jz @B
	jmp @BB

@@:
	; retn
		; ds:si not normalised, incremented by at most 32
	test ch, ch			; cx > 255 ? (NC)
	jnz .end_check			; yes, end marker -->
	call getbit
		; ds:si not normalised, incremented by at most 33
	jz .bitzero

.bitone:
	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jc .error_CY
	call .copy_to_destination
		; ds:si not normalised, incremented by at most 33 + 256
.next:
	call normalise_dssi_pointer
	; call normalise_esdi_pointer_at_least_256
		; INP:	es:di = pointer
		; OUT:	es:di normalised,
		;	 di < 256 + 16
		;	 di >= 256 if possible
; normalise_esdi_pointer_at_least_256:
	mov ax, 256
	sub di, ax			; subtract base and compare
	jbe @F				; below/equal base,
					;  just branch and restore -->
	 push es
	 push di
	call normalise_pointer		; normalise pointer to offset 0..15
	 pop di
	 pop es
@@:
	add di, ax			; restore base, now 0..256+15
	; retn

%if _PAYLOAD_KERNEL_MAX_PARAS
	mov ax, es
	mov bx, di
	mov cl, 4
	shr bx, cl			; round DOWN !
	add ax, bx
	cmp ax, word [bp + ?dst_max_segment]
	jae .end_NC			; (NC if it branches)
%endif

	jmp .loop

.bitzero:
	xor ax, ax			; initialise ah = 0
	call getbyte			; ax = al = offset
		; ds:si not normalised, incremented by at most 34
	inc cx				; length ++
%if _ALLOW_OVERLAPPING
	mov word [bp + ?src + 2], ds
	mov word [bp + ?src], si	; preserve pointer here,
					;  also to initialise for check
%else
	 push ds
	 push si			; preserve pointer on stack
%endif
	push es
	pop ds
	mov si, di			; (at least 256 normalised)
	sub si, ax			; should not carry
	jc .error_CY
	call .copy_to_destination
%if _ALLOW_OVERLAPPING
	mov word [bp + ?dst + 2], es
	mov word [bp + ?dst], di	; (needn't be normalised)
	push dx
	call check_pointers_not_overlapping
	pop dx
	jc .error_CY
	lds si, [bp + ?src]		; restore pointer
%else
	 pop si
	 pop ds				; restore pointer
%endif
	jmp .next

.end_check:
		; The end marker should code 1FFh. Refer to
		;  https://github.com/mbaze/bzpack/issues/7
	cmp cx, 1FFh			; correct end marker ?
	je .end_NC			; yes --> (NC)
	stc				; no, error!

.error_CY:
.end_NC:

%if _COUNTER
	lahf
	mov al, 13
	call disp_al
	mov al, 10
	call disp_al
	sahf
%endif
d0	mov bx, word [bp + ?errordata]
	lleave code
	lret


.copy_to_destination:
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jc .error_CY
	rep movsb
	retn


		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	Only returns iff successful,
		;	 al = byte read
		;	 ds:si incremented by at most one,
		;	 not normalised
		;	Jumps to depack.error_CY if failure
		; CHG:	-
getbyte:
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jc depack.error_CY
	lodsb
	retn


		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	Only returns iff successful,
		;	 ah = zero if bit clear, and ZR
		;	 ah = nonzero if bit set, and NZ
		;	 ds:si incremented by at most one,
		;	 not normalised
		;	Jumps to depack.error_CY if failure
		; CHG:	al
getbit:
	mov ah, dh
	test ah, ah
	jnz @F
	mov ah, 128
	call getbyte
	mov dx, ax
@@:
	shr dh, 1
	and ah, dl
	retn
