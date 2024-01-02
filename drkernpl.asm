
%if 0

Loader adjustment for Enhanced DR-DOS kernel (single-file load)
 by E. C. Masloch, 2024

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"
	sectalign off


	struc BS
bsJump:	resb 3
bsOEM:	resb 8
bsBPB:
	endstruc

	struc EBPB		;        BPB sec
bpbBytesPerSector:	resw 1	; offset 00h 0Bh
bpbSectorsPerCluster:	resb 1	; offset 02h 0Dh
bpbReservedSectors:	resw 1	; offset 03h 0Eh
bpbNumFATs:		resb 1	; offset 05h 10h
bpbNumRootDirEnts:	resw 1	; offset 06h 11h -- 0 for FAT32
bpbTotalSectors:	resw 1	; offset 08h 13h
bpbMediaID:		resb 1	; offset 0Ah 15h
bpbSectorsPerFAT:	resw 1	; offset 0Bh 16h -- 0 for FAT32
bpbCHSSectors:		resw 1	; offset 0Dh 18h
bpbCHSHeads:		resw 1	; offset 0Fh 1Ah
bpbHiddenSectors:	resd 1	; offset 11h 1Ch
bpbTotalSectorsLarge:	resd 1	; offset 15h 20h
bpbNew:				; offset 19h 24h

ebpbSectorsPerFATLarge:	resd 1	; offset 19h 24h
ebpbFSFlags:		resw 1	; offset 1Dh 28h
ebpbFSVersion:		resw 1	; offset 1Fh 2Ah
ebpbRootCluster:	resd 1	; offset 21h 2Ch
ebpbFSINFOSector:	resw 1	; offset 25h 30h
ebpbBackupSector:	resw 1	; offset 27h 32h
ebpbReserved:		resb 12	; offset 29h 34h
ebpbNew:			; offset 35h 40h
	endstruc

	struc BPBN		; ofs B16 S16 B32 S32
bpbnBootUnit:		resb 1	; 00h 19h 24h 35h 40h
			resb 1	; 01h 1Ah 25h 36h 41h
bpbnExtBPBSignature:	resb 1	; 02h 1Bh 26h 37h 42h -- 29h for valid BPBN
bpbnSerialNumber:	resd 1	; 03h 1Ch 27h 38h 43h
bpbnVolumeLabel:	resb 11	; 07h 20h 2Bh 3Ch 47h
bpbnFilesystemID:	resb 8	; 12h 2Bh 36h 47h 52h
	endstruc		; 1Ah 33h 3Eh 4Fh 5Ah


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	strdef PAYLOAD_BIO_FILE,"drbio.bin"
	strdef PAYLOAD_DOS_FILE,"drdos.sys"


	struc LOADSTACKVARS, -10h
lsvFirstCluster:	resd 1
lsvFATSector:		resd 1
lsvFATSeg:		resw 1
lsvLoadSeg:		resw 1
lsvDataStart:		resd 1
	endstruc


lsvclSignature		equ "CL"
lsvclBufferLength	equ 256

	struc LOADDATA, LOADSTACKVARS - 10h
ldMemoryTop:	resw 1
ldLoadTop:	resw 1
ldSectorSeg:	resw 1
ldFATType:	resb 1
ldHasLBA:	resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:		; word
lsvCommandLine:		; word
.start:		equ $ - lsvclBufferLength
.signature:	resw 1
ldLoadUntilSeg:		; word
lsvExtra:		; word
.partition:	resb 1	; byte
.flags:		resb 1	; byte
	endstruc

lsvefNoDataStart	equ 1
lsvefPartitionNumber	equ 2

	struc LOADCMDLINE, LOADDATA - lsvclBufferLength
ldCommandLine:
.start:		resb lsvclBufferLength
	endstruc


	cpu 8086
	org 0
	addsection ENTRY, start=0 vstart=0
entry:

	mov ax, cs
	add ax, entry_size_p + payload_size_p
	xor bx, bx
	push ax
	push bx
	retf

	align 256, db 0		; make sure we can always move forwards
		; This is so that the drkernpl PAYLOAD is always
		;  loaded to 700h or higher, as our ENTRY must be
		;  loaded by the prior stage to 600h or higher.
		; If the PAYLOAD is at >= 700h it is valid to move
		;  forwards (Direction Flag UP) unconditionally to
		;  relocate it to the destination at 700h.

	align 16
	endarea entry


	addsection PAYLOAD, follows=ENTRY
payload:
realpayload:
	incbin _PAYLOAD_BIO_FILE
	align 16, db 38
payloaddos:
	incbin _PAYLOAD_DOS_FILE
	align 16, db 38
	endarea payloaddos

	endarea realpayload


	addsection STACKRELOCATE, follows=PAYLOAD vstart=0
stackrelocate:

	mov ax, 70h + payload_size_p
	cli
	mov ss, ax
	lea sp, [bp + ldCommandLine]	; -> behind unused memory
	sti
		; Even if the ldLoadTop => right behind our image
		;  and we started with cs = 60h, the relocated ss:sp
		;  here will never point at a higher linear than our
		;  ss:sp before this. So it cannot corrupt the LD or
		;  LSV or BPB structures on that stack.
		; (The new stack never underflows because the iniload
		;  to payload protocol always passes a stack that is
		;  set up sensibly with 256 <= sp and further sp <=
		;  bp + ldCommandLine, thus bp >= 256 + 256 + 32.)
		; Other buffers like the sector seg and FAT buffer
		;  may be below the stack and thus may be corrupted
		;  by this relocation but we do not use those nor
		;  do we pass them to the next stage (our payload).
		; So it is perfectly safe to temporarily relocate
		;  the stack this way here. It solves the (remote)
		;  possibility of the old stack corrupting the newly
		;  relocated data structures as was possible prior.
		;  Unlike the prior changeset there is no longer an
		;  error condition that has us abort loading.

	mov es, ax
	xor di, di
	xor si, si
	lea cx, [ bp + 512 ]
	rep movsb
	mov ds, ax			; drkernpl: ss == ds
	mov si, bp
	xor di, di
	cmp word [bp + ldCommandLine], 0FF00h
	je @F
	lea si, [bp + ldCommandLine + lsvclBufferLength - 2]
	lea di, [bp + lsvCommandLine.start + lsvclBufferLength - 2]
	mov cx, words(lsvclBufferLength)
%if words(lsvclBufferLength) <= 20
 %error AMD erratum 109 workaround needed
%endif
	std
	rep movsw
	cld
	lea si, [bp + lsvCommandLine.start]
	mov di, lsvclSignature
@@:
	mov sp, si			; relocate just sp, ss already set
	mov word [bp + lsvCommandLine.signature], di
		; Note that this access uses the new ss.
		; Also note: If no command line is passed,
		;  si will equal bp. That means the word
		;  written here is technically below sp,
		;  that is it belongs to the unused stack.
		; This does not cause any problems however.
		; It hardens the next load stage against
		;  accidentally expecting a command line if
		;  it does not check the offsets properly.

	mov ax, 70h + paras(payloaddos - payload)
%if 0
	mov ds, ax
	mov ax, word [bp + ldMemoryTop]
	sub ax, payloaddos_size_p
	mov es, ax
%if 1
	lea si, [bp + 512 + 15]
	mov cl, 4
	shr si, cl
	mov cx, 70h + payload_size_p
	add cx, si
	cmp ax, cx
	jb error
%endif

%if payloaddos_size > 65536
 %error Too large DOS payload
%endif
	mov cx, payloaddos_size_w
	rep movsw

	push ss
	pop ds

	mov si, payloaddos_size
	jmp 70h:0

%if 1
error:
	push cs
	pop ds
	mov si, msg.error
	call disp_error
	xor ax, ax
	int 16h
	int 19h


disp_error.loop:
	mov ah, 0Eh
	mov bx, 7
	; push bp
		; (call may change bp, but it is not used here any longer.)
	int 10h
	; pop bp
disp_error:
	lodsb
	test al, al
	jnz .loop
	retn

msg.error:		asciz "drkernpl Load Error!",13,10
%endif

%else
	mov si, payloaddos_size
	jmp 70h:0
%endif


	align 16
	endarea stackrelocate

payload_size equ realpayload_size + stackrelocate_size
	endarea payload, 1


	addsection RELOCATE, follows=STACKRELOCATE vstart=0
relocate:
	mov bx, 1000h	; = 1000h (paragraphs per 64 KiB)
	mov ax, 70h
	mov es, ax	; => destination start
	mov ax, payload_size_p
			; ax = how many paragraphs to move
	mov cx, cs
	sub cx, ax
	mov ds, cx	; => source start (is >= destination)
	jmp .first

@@:
	mov dx, es
	add dx, bx
	mov es, dx	; next segment

	mov dx, ds
	add dx, bx
	mov ds, dx	; next segment

.first:
	sub ax, bx	; = how much to relocate after this round
	mov cx, 1000h << 3	; in case another full 64 KiB to relocate
	jae @F		; another full 64 KiB to relocate -->
	add ax, bx	; restore
	shl ax, 1
	shl ax, 1
	shl ax, 1	; convert paragraphs to words
	mov cx, ax	; that many words
	xor ax, ax	; no more to relocate after this round

@@:
	xor si, si
	xor di, di
	rep movsw	; relocate next chunk
	test ax, ax	; another round needed?
	jnz @BB		; yes -->
			; ax = 0

	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
	mov bl, dl

	 push ss
	 pop ds
	cmp word [bp + bsBPB + bpbSectorsPerFAT], ax
	je @F
	 push ss
	 pop es
	lea si, [bp + bsBPB + ebpbNew]
	lea di, [bp + bsBPB + bpbNew]
	mov cx, (512 - bsBPB - bpbNew + 1) >> 1
	rep movsw
@@:

	jmp 70h + realpayload_size_p:0

	align 256, db 0		; make sure new stack is lower than LD
		; With the alignment directive in ENTRY this
		;  is probably not needed. However, there is
		;  little harm in keeping it.
