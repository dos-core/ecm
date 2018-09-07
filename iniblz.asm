
%if 0

lDOS iniload packed payload
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Contains BriefLZ depacker, which is under separate usage conditions.

%endif

%include "lmacros2.mac"

	struc LOADSTACKVARS, -10h
lsvFirstCluster:	resd 1
lsvFATSector:		resd 1
lsvFATSeg:		resw 1
lsvLoadSeg:		resw 1
lsvDataStart:		resd 1
	endstruc

	struc LOADDATA, LOADSTACKVARS - 10h
ldMemoryTop:	resw 1
ldLoadTop:	resw 1
ldSectorSeg:	resw 1
ldFATType:	resb 1
ldHasLBA:	resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:	resw 1
ldLoadUntilSeg:	resw 1
	endstruc


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting

	strdef PAYLOAD_FILE,	"lDOSLOAD.BLZ"
	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0

	cpu 8086
	section INIT0 start=0 vstart=0
init0_start:
	cld
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	mov dx, word [ bp + ldLoadTop ]
	sub dx, cx
	call init0_movp

	mov ax, dx
	add ax, ( \
		+ (payload_end - payload) \
		) >> 4
	xor bx, bx
	push ax
	push bx
	retf


		; Move paragraphs
		;
		; INP:	ax:0-> source
		;	dx:0-> destination
		;	cx = number of paragraphs
		; CHG:	-
		; OUT:	NC
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init0_movp:
	push cx
	push ds
	push si
	push es
	push di

	cmp ax, dx		; source below destination ?
	jb .down		; yes, move from top down -->
	je .return		; same, no need to move --> (NC)

	push ax
	push dx
.uploop:
	mov ds, ax
	mov es, dx
	xor di, di
	xor si, si		; -> start of segment
	sub cx, 1000h		; 64 KiB left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	add ax, 1000h
	add dx, 1000h		; -> next segment
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words (NC)
	rep movsw		; move last part
	pop dx
	pop ax
	jmp short .return

.down:
	std
.dnloop:
	sub cx, 1000h		; 64 KiB left ?
	jbe .dnlast		; no -->
	push ax
	push dx
	add ax, cx
	add dx, cx
	mov ds, ax		; -> 64 KiB not yet moved
	mov es, dx
	pop dx
	pop ax
	mov di, -2
	mov si, di		; moved from last word down
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	mov di, cx
	dec di
	shl di, 1		; words to offset, -> last word (NC)
	mov si, di
	mov ds, ax
	mov es, dx		; first segment correct
	rep movsw		; move first part
	cld
.return:
	pop di
	pop es
	pop si
	pop ds
	pop cx
	retn


	align 16
init0_end:


	section PAYLOAD align=16 follows=INIT0
payload:
	incbin _PAYLOAD_FILE
.end:
	align 16, db 38
payload_end:


	section INIT1 align=16 follows=PAYLOAD vstart=0
init1_start:
		; INP:	ss:bp -> LOADDATA and LOADSTACKVARS
		;	ss:sp -> valid stack above [bp + ldLoadTop]
		;	cs = INIT1
		;	cs - (payload_end - payload) >> 4 => source data
		;	60h => destination
		; CHG:	ax, bx, cx, dx, es, ds, si, di

	mov ax, cs
	sub ax, ( \
		+ (payload_end - payload) \
		) >> 4
	mov ds, ax
	xor si, si		; -> source

	mov cx, (payload_end - payload) & 0FFFFh
	mov dx, (payload_end - payload) >> 16	; = length of source

	mov ax, 60h
	mov es, ax
	xor di, di		; -> destination

		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		; Note:	The destination reaches up to below the source.
	call depack
	jc error

	mov ax, 60h + _EXEC_SEGMENT
	mov bx, _EXEC_OFFSET
	push ax
	push bx
	retf

error:
	push cs
	pop ds
	mov si, msg.error
.:
	lodsb
	test al, al
	jz .end
	mov ah, 0Eh
	mov bx, 7
	; push bp
		; (call may change bp, but it is not used here any longer.)
	int 10h
	; pop bp
	jmp short .

.end:
	xor ax, ax
	int 16h
	int 19h

msg:
.error:	db "Load error: Decompression failure.", 0


%if 0

 BriefLZ - small fast Lempel-Ziv

 8086 Assembly lDOS iniload payload depacker

 Based on: BriefLZ C safe depacker

 Copyright (c) 2002-2016 Joergen Ibsen

 This software is provided 'as-is', without any express or implied
 warranty. In no event will the authors be held liable for any damages
 arising from the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must
      not claim that you wrote the original software. If you use this
      software in a product, an acknowledgment in the product
      documentation would be appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must
      not be misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
      distribution.

%endif

depack:
	lframe near
	lenter

	lleave
	lret


	align 16
init1_end:

