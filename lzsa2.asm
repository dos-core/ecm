
; 8086 Assembly lDOS iniload payload LZSA2 depacker
;  by C. Masloch, 2021
;
;  based on:
;  decompress_small.S - space-efficient decompressor implementation for 8088
;
;  Copyright (C) 2019 Emmanuel Marty
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.


	numdef COUNTER,		0, 128
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
%endif


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
%if _IMAGE_EXE || _DEBUG0 || _COUNTER
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _DEBUG0 || _COUNTER
	xor bx, bx
 %endif
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
%endif
	lvar word,	counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar dword,	length_of_source_after_block
	lvar word,	matchlength
	lenter

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx

%if 0 ; && _PAYLOAD_KERNEL_MAX_PARAS
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
%endif

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

	call .lodsw
	cmp ax, 7Bh | (9Eh << 8)	; signature
	jne .error
	call .lodsb
	cmp al, 1 << 5			; traits byte, check for lzsa2
	jne .error

.loop:
	call normalise_both_pointers

	xor dx, dx
	call .lodsw			; bits 0 to 15 of length
	xchg ax, dx
	call .lodsb
	test al, 0111_1111b		; reserved bits + bit 16 of length
	jnz .error			; error if nonzero -->

	call normalise_dssi_pointer

		; This first check is only really relevant
		;  for uncompressed blocks.
	mov bx, di
	add bx, dx			; fits in destination segment ?
	jc .error			;  (assuming bit 16 = 0)
		; This second check is to insure we don't
		;  have to normalise the source pointer
		;  until after the end of the block.
	mov bx, si
	add bx, dx			; fits in source segment ?
	jc .error

	test al, al			; uncompressed ?
	xchg ax, dx
	jns .compressed			; no -->
.uncompressed:
	xchg ax, cx
	rep movsb			; copy this
	jmp .loop

.compressed:
	mov cx, word [bp + ?length_of_source]
	mov bx, word [bp + ?length_of_source + 2]

	test ax, ax
	jz .end

	sub cx, ax
	sbb bx, 0
	jc .error
	mov word [bp + ?length_of_source_after_block], cx
	mov word [bp + ?length_of_source_after_block + 2], bx

	push es
	push di
	call lzsa2_decompress
	cmp ax, 1			; CY if ax == 0
	xchg cx, ax
	sbb bx, bx			; -1 if cx == 0, else 0
	neg bx				; 1 if cx == 0, else 0
	call normalise_pointer_with_displacement_bxcx
	pop di
	pop es
	jmp .loop

.end:
	or bx, cx
	jnz .error

.ret:
	db __TEST_IMM8		; (skip stc, NC)
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


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 al = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?length_of_source decremented
.lodsb:
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jb .error
	lodsb
.retn:
	retn


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 ax = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?length_of_source decremented
.lodsw:
	sub word [bp + ?length_of_source], 2
	sbb word [bp + ?length_of_source + 2], 0
	jb .error
	lodsw
	retn


		; Decompress LZSA2 block
		;
		; INP:	ds:si -> LZSA2 block
		;	es:di -> output buffer
		;	?length_of_source
		;	?length_of_source_after_block = block end target
		;	?original_dst -> lowest valid back reference
		; OUT:	ax = decompressed size (0 means 64 KiB)
		;	ds:si -> behind source data
		;	jumps to depack.error if error condition detected
		; CHG:	all except bp
lzsa2_decompress:
.lodsb equ depack.lodsb
.lodsw equ depack.lodsw

   push di                 ; remember decompression offset

   xor cx,cx
   mov bx,0100H
   and word [bp + ?matchlength], 0

.decode_token:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif
	mov ax, word [bp + ?length_of_source]
	mov dx, word [bp + ?length_of_source + 2]

	cmp word [bp + ?length_of_source_after_block + 2], dx
	jne @F
	cmp word [bp + ?length_of_source_after_block], ax
@@:
	je .end
	ja depack.error

   mov ax,cx               ; clear ah - cx is zero from above or from after rep movsb in .copy_match
	call .lodsb		; read token byte: XYZ|LL|MMMM
   mov dx,ax               ; keep token in dl
   
   and al,018H             ; isolate literals length in token (LL)
   mov cl,3
   shr al,cl               ; shift literals length into place

   cmp al,03H              ; LITERALS_RUN_LEN_V2?
   jne .got_literals       ; no, we have the full literals count from the token, go copy

   call .get_nibble        ; get extra literals length nibble
   add al,cl               ; add len from token to nibble 
   cmp al,012H             ; LITERALS_RUN_LEN_V2 + 15 ?
   jne .got_literals       ; if not, we have the full literals count, go copy

	call .lodsb		; grab extra length byte
   add al,012H             ; overflow?
   jnc .got_literals       ; if not, we have the full literals count, go copy

	call .lodsw		; grab 16-bit extra length

.got_literals:
   xchg cx,ax
	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jb depack.error
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jb depack.error
   rep movsb               ; copy cx literals from ds:si to es:di

	push dx
	push ax
	mov ax, word [bp + ?length_of_source]
	mov dx, word [bp + ?length_of_source + 2]

	cmp word [bp + ?length_of_source_after_block + 2], dx
	jne @F
	cmp word [bp + ?length_of_source_after_block], ax
@@:
	pop ax
	pop dx
	je .end
	ja depack.error

   test dl,0C0h            ; check match offset mode in token (X bit)
   js .rep_match_or_large_offset

   ;;cmp dl,040H             ; check if this is a 5 or 9-bit offset (Y bit)
                           ; discovered via the test with bit 6 set
   xchg cx,ax              ; clear ah - cx is zero from the rep movsb above
   jne .offset_9_bit

                           ; 5 bit offset
   cmp dl,020H             ; test bit 5
   call .get_nibble_x
   jmp short .dec_offset_top

.offset_9_bit:             ; 9 bit offset
	call .lodsb		; get 8 bit offset from stream in A
   dec ah                  ; set offset bits 15-8 to 1
   test dl,020H            ; test bit Z (offset bit 8)
   je .get_match_length
.dec_offset_top:
   dec ah                  ; clear bit 8 if Z bit is clear
                           ; or set offset bits 15-8 to 1
   jmp short .get_match_length

.rep_match_or_large_offset:
   ;;cmp dl,0c0H             ; check if this is a 13-bit offset or a 16-bit offset/rep match (Y bit)
   jpe .rep_match_or_16_bit

                           ; 13 bit offset

   cmp dl,0A0H             ; test bit 5 (knowing that bit 7 is also set)
   xchg ah,al
   call .get_nibble_x
   sub al,2                ; substract 512
   jmp short .get_match_length_1

.rep_match_or_16_bit:
   test dl,020H            ; test bit Z (offset bit 8)
   jne .repeat_match       ; rep-match

                           ; 16 bit offset
	call .lodsb		; Get 2-byte match offset

.get_match_length_1:
   xchg ah,al
	call .lodsb		; load match offset bits 0-7

.get_match_length:
	xchg word [bp + ?matchlength], ax
			; bp: offset
.repeat_match:
   xchg ax,dx              ; ax: original token
   and al,07H              ; isolate match length in token (MMM)
   add al,2                ; add MIN_MATCH_SIZE_V2

   cmp al,09H              ; MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2?
   jne .got_matchlen       ; no, we have the full match length from the token, go copy

   call .get_nibble        ; get extra literals length nibble
   add al,cl               ; add len from token to nibble 
   cmp al,018H             ; MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2 + 15?
   jne .got_matchlen       ; no, we have the full match length from the token, go copy

	call .lodsb		; grab extra length byte
   add al,018H             ; overflow?
   jnc .got_matchlen       ; if not, we have the entire length
	je depack.error		; detect EOD code

	call .lodsw		; grab 16-bit length

.got_matchlen:
   xchg cx,ax              ; copy match length into cx
   push ds                 ; save ds:si (current pointer to compressed data)
   xchg si,ax          
   push es
   pop ds
	mov si, di
	add si, word [bp + ?matchlength]
			; ds:si now points at back reference in output data
	jc @FF		; simple case branches here -->
	push bx
	push cx
	mov cx, word [bp + ?matchlength]
	mov bx, -1
	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop bx
	jnc depack.error
	cmp bx, word [bp + ?original_dst + 2]
	jne @F
	cmp si, word [bp + ?original_dst]
@@:
	jb depack.error
	mov ds, bx
	pop cx
	pop bx
@@:
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jb depack.error
   rep movsb               ; copy match
   xchg si,ax              ; restore ds:si
   pop ds
%if _ALLOW_OVERLAPPING
	mov word [bp + ?src + 2], ds
	mov word [bp + ?src], si
	mov word [bp + ?dst + 2], es
	mov word [bp + ?dst], di
	push bx
	call check_pointers_not_overlapping
	pop bx
	jc depack.error
	xor cx, cx
%endif
   jmp .decode_token       ; go decode another token

.end:
   pop ax                  ; retrieve the original decompression offset
   xchg di,ax              ; compute decompressed size
   sub ax,di
   ret                     ; done

.get_nibble_x:
   cmc                     ; carry set if bit 4 was set
   rcr al,1
   call .get_nibble        ; get nibble for offset bits 0-3
   or al,cl                ; merge nibble
   rol al,1
   xor al,0E1H             ; set offset bits 7-5 to 1
   ret

.get_nibble:
   neg bh                  ; nibble ready?
   jns .has_nibble
   
   xchg bx,ax
	call .lodsb		; load two nibbles
   xchg bx,ax

.has_nibble:
   mov cl,4                ; swap 4 high and low bits of nibble
   ror bl,cl
   mov cl,0FH
   and cl,bl
   ret
