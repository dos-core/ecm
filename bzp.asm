
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


		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	if _IMAGE_EXE:
		;	 bx = EXE mode flag (bit 0)
		;	else:
		;	 bx = 0
		;	ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
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
	lenter early		; (unconditionally)
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
	xor bx, bx		; (unconditionally)
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
	lvar word,	bitbyte_and_mask
	lequ ?bitbyte_and_mask + 1, mask
	lequ ?bitbyte_and_mask, bitbyte
	 push bx		; initialise mask to zero
%if _COUNTER
	lvar word,	counter
	 push bx		; initialise counter to zero
%endif
	lenter

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
	jc .error		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax

	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

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
	jc .error
%endif

	lds si, [bp + ?src]
	les di, [bp + ?dst]

.loop:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif
	call decode_elias_1		; cx = value of length
	jc .error
	test ch, ch			; cx > 255 ?
	jnz .end			; yes, end marker -->
	call getbit
	jc .error
	jz .bitzero

.bitone:
	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jc .error
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jc .error
	rep movsb
.next:
	call normalise_dssi_pointer
	call normalise_esdi_pointer_at_least_256

	mov ax, es
	mov bx, di
	mov cl, 4
	shr bx, cl			; round DOWN !
	add ax, bx
	cmp ax, word [bp + ?dst_max_segment]
	jae .end

	jmp .loop

.bitzero:
	xor ax, ax			; initialise ah = 0
	call getbyte			; ax = al = offset
	jc .error
	inc cx				; length ++
	 push ds
	 push si
	push es
	pop ds
	mov si, di			; (at least 256 normalised)
	sub si, ax			; should not carry
	jc .error
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jc .error
	rep movsb
	 pop si
	 pop ds
%if _ALLOW_OVERLAPPING
	mov word [bp + ?src + 2], ds
	mov word [bp + ?src], si
	mov word [bp + ?dst + 2], es
	mov word [bp + ?dst], di	; (needn't be normalised)
	call check_pointers_not_overlapping
	jc .error
%endif
	jmp .next

.end:
	db __TEST_IMM8			; (NC)
.error:
	stc

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


		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	NC iff successful,
		;	 al = byte read
		;	 ds:si incremented, normalised
		; CHG:	-
getbyte:
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jc .ret
	lodsb
	call normalise_dssi_pointer
	clc
.ret:
	retn


		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	NC iff successful,
		;	 ah = zero if bit clear, and ZR
		;	 ah = nonzero if bit set, and NZ
		;	 ds:si may be incremented, normalised
		; CHG:	al
getbit:
	mov ah, byte [bp + ?mask]
	test ah, ah
	jnz @F
	mov ah, 128
	call getbyte
	jc .ret
	mov word [bp + ?bitbyte_and_mask], ax
@@:
	and ah, byte [bp + ?bitbyte]
	shr byte [bp + ?mask], 1
	test ah, ah			; (NC)
.ret:
	retn


		; INP:	depack stack frame
		;	ds:si -> source
		; OUT:	NC iff successful,
		;	 cx = decoded value
		;	 ds:si may be incremented, normalised
		; CHG:	ax
decode_elias_1:
	mov cx, 1			; value = 1
@@:
	call getbit
	; jc .ret			; read error
	; jz .ret			; read zero (NC)
	jbe .ret			; (branch if CY || ZR)
	shl cx, 1			; value <<= 1
	jc .ret				; value error
	call getbit
	jc .ret				; read error
	jz @B
	inc cx				; value += 1
	jmp @B

.ret:
	retn


		; INP:	es:di = pointer
		; OUT:	es:di normalised,
		;	 di < 256 + 16
		;	 di >= 256 if possible
normalise_esdi_pointer_at_least_256:
	sub di, 256			; subtract base and compare
	jbe @F				; below/equal base,
					;  just branch and restore -->
	 push es
	 push di
	call normalise_pointer		; normalise pointer to offset 0..15
	 pop di
	 pop es
@@:
	add di, 256			; restore base, now 0..256+15
	retn
