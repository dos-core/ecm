
; 8086 Assembly lDOS iniload payload aPLib depacker
;  by C. Masloch, 2021
;
;  based on:
;  aplib_8088_small.S - size-optimized aPLib decompressor for 8088 - 145 bytes
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
	lvar word,	gamma_high_word
	lvar word,	distance_high_word
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

%if 0
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

%if 0 && _ALLOW_OVERLAPPING
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

%if 0 && _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif

.loop:
	mov cx, word [bp + ?length_of_source]
	mov bx, word [bp + ?length_of_source + 2]

.end:
	or bx, cx
	jnz .error

.ret:
	db __TEST_IMM8		; (skip stc, NC)
.error:
	stc

d0	mov bx, word [bp + ?errordata]
	lleave code
	lret


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 al = value read
		;	 ds:si incremented (normalised)
		;	 ?length_of_source decremented
.lodsb:
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jb .error
	lodsb
	jmp normalise_dssi_pointer


        push    di              ; remember decompression offset
        cld                     ; make string operations go forward

        ; === register map ===
        ; al: bit queue
        ; ah: unused, but value is trashed
        ; bx: follows_literal
        ; cx: scratch register for reading gamma2 codes and storing copy length
        ; dx: match offset (and rep-offset)
        ; si: input (compressed data) pointer
        ; di: output (decompressed data) pointer

        mov     al,080H         ; clear bit queue(al) and set high bit to move into carry
        xor     dx,dx           ; invalidate rep offset
	mov word [bp + ?distance_high_word], dx

.literal:
	sub word [bp + ?length_of_destination], 1
	sbb word [bp + ?length_of_destination + 2], 0
	jb .error
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jb .error
        movsb                   ; read and write literal byte
	call normalise_both_pointers
.next_command_after_literal:
        mov     bx,03H          ; set follows_literal(bx) to 3

.next_command:
        call    .get_bit        ; read 'literal or match' bit
        jnc     .literal        ; if 0: literal
                                
                                ; 1x: match

        call    .get_bit        ; read '8+n bits or other type' bit
        jc      .other          ; 11x: other type of match

                                ; 10: 8+n bits match
        call    .get_gamma2     ; read gamma2-coded high offset bits
        sub     cx,bx           ; high offset bits == 2 when follows_literal == 3 ?
                                ; (a gamma2 value is always >= 2, so substracting follows_literal when it
                                ; is == 2 will never result in a negative value)
	sbb word [bp + ?gamma_high_word], 0
        jae     .not_repmatch   ; if not, not a rep-match

        call    .get_gamma2     ; read match length
        jmp     short .got_len  ; go copy

.not_repmatch:
	mov dx, word [bp + ?gamma_high_word]
	test dh, dh		; beyond 32-bit offset ?
	jnz .error		; if so, error -->
	mov byte [bp + ?distance_high_word + 1], dl
	mov byte [bp + ?distance_high_word], ch
				; get high word of distance
        mov     dh,cl           ; transfer high offset bits to dh
	xchg ax, dx
	call .lodsb
	xchg ax, dx		; read low offset byte in dl

        call    .get_gamma2     ; read match length
	cmp word [bp + ?distance_high_word], 0
				; high word nonzero ?
	jne .increase_len_by2	; then always offset >= 32k
        cmp     dh,07DH         ; offset >= 32000 ?
        jae     .increase_len_by2 ; if so, increase match len by 2
        cmp     dh,05H          ; offset >= 1280 ?
        jae     .increase_len_by1 ; if so, increase match len by 1
        cmp     dx,0080H        ; offset < 128 ?
        jae     .got_len        ; if so, increase match len by 2, otherwise it would be a 7+1 copy
.increase_len_by2:
	add cx, 1		; increase length
	adc word [bp + ?gamma_high_word], 0
.increase_len_by1:
	add cx, 1		; increase length
	adc word [bp + ?gamma_high_word], 0

        ; copy ?gamma_high_word:cx bytes
	;  from match offset ?distance_high_word:dx

.got_len:
        push    ds              ; save ds:si (current pointer to compressed data)
        push    si

	push bx
	push cx
	mov bx, word [bp + ?distance_high_word]
	mov cx, dx

	call .get_match_pointer

	pop cx
	pop bx

.match_loop:
	sub cx, 0FFF0h		; less than full transfer left ?
	sbb word [bp + ?gamma_high_word], 0
	jb .match_last		; yes -->
	push cx
	mov cx, 0FFF0h		; do full transfer
	call .match_copy
	pop cx
	jmp .match_loop		; loop for more

.match_copy:
	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], 0
	jb .error
	rep movsb		; copy matched bytes
	jmp normalise_both_pointers

.get_match_pointer:
	neg bx
	neg cx
	sbb bx, byte 0		; neg bx:cx

	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
				; -> match to copy
	 pop si
	 pop bx
	jnc .error		; if too high (underflow) -->
	cmp bx, word [bp + ?original_dst + 2]
	jne @F
	cmp si, word [bp + ?original_dst]
@@:
	jb .error		; if too low -->
	mov ds, bx		; ds:si -> match to copy
	retn

.match_last:
	add cx, 0FFF0h		; restore counter (high word discarded)
	call .match_copy	; do last transfer (0 .. 0FFEFh bytes)

        pop     si              ; restore ds:si
        pop     ds

        mov     bl,02H          ; set follows_literal to 2 (bx is unmodified by match commands)
        jmp     short .next_command

        ; read gamma2-coded value into cx

.get_gamma2:
        xor     cx,cx           ; initialize to 1 so that value will start at 2
	mov word [bp + ?gamma_high_word], cx
				; initialise high word to zero
        inc     cx              ; when shifted left in the adc below

.gamma2_loop:
        call    .get_dibits     ; read data bit, shift into cx, read continuation bit
        jc      .gamma2_loop    ; loop until a zero continuation bit is read

        ret

        ; handle 7 bits offset + 1 bit len or 4 bits offset / 1 byte copy

.other:
        xor     cx,cx
        call    .get_bit        ; read '7+1 match or short literal' bit
        jc      .short_literal  ; 111: 4 bit offset for 1-byte copy

                                ; 110: 7 bits offset + 1 bit length
	mov word [bp + ?gamma_high_word], cx
	mov word [bp + ?distance_high_word], cx
				; clear both high words

	xchg ax, dx
	call .lodsb
	xchg ax, dx		; read offset + length in dl

        inc     cx              ; prepare cx for length below
        shr     dl,1            ; shift len bit into carry, and offset in place
        je      .done           ; if zero offset: EOD
        adc     cx,cx           ; len in cx: 1*2 + carry bit = 2 or 3

        xor     dh,dh           ; clear high bits of offset
        jmp     short .got_len

        ; 4 bits offset / 1 byte copy

.short_literal:
        call    .get_dibits     ; read 2 offset bits
        adc     cx,cx
        call    .get_dibits     ; read 2 offset bits
        adc     cx,cx
        xchg    ax,cx           ; preserve bit queue in cx, put offset in ax
        jz      .write_zero     ; if offset is 0, write a zero byte

                                ; short offset 1-15
	push cx
	push ds
	push si
	xor bx, bx		; we trash bx, it will be reset to 3 when we loop
	xchg ax, cx		; bx:cx = offset to subtract
	call .get_match_pointer
	lodsb			; al = byte [ds:si]
				; read byte from short offset
	pop si
	pop ds
	pop cx
.write_zero:
	sub word [bp + ?length_of_destination], 1
	sbb word [bp + ?length_of_destination + 2], 0
	jb .error
        stosb                   ; copy matched byte
	push es
	push di
	call normalise_pointer
	pop di
	pop es
        xchg    ax,cx           ; restore bit queue in al
        jmp     .next_command_after_literal

.done:
        pop     ax              ; retrieve the original decompression offset
        xchg    di,ax           ; compute decompressed size
        sub     ax,di
        ret

.get_dibits:
        call    .get_bit        ; read data bit
        adc     cx,cx           ; shift into cx
	rcl word [bp + ?gamma_high_word], 1
	jc .error

.get_bit:
        add     al,al           ; shift bit queue, and high bit into carry
        jnz     .got_bit        ; queue not empty, bits remain
	call .lodsb		; read 8 new bits
        adc     al,al           ; shift bit queue, and high bit into carry
.got_bit:
        ret
