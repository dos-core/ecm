
%if 0

Loader for Enhanced DR-DOS single-file load
 by E. C. Masloch, 2024

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%assign __lMACROS1_MAC__DEBUG_DEFAULTS 1
%include "lmacros3.mac"
	numdef DEBUG5
%idefine d5 _d 5,

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
ldQueryPatchValue:	; word
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

	struc LBAPACKET
lpSize:		resw 1
lpCount:	resw 1
lpBuffer:	resd 1
lpSector:	resq 1
	endstruc

	struc PARTINFO
piBoot:		resb 1
piStartCHS:	resb 3
piType:		resb 1
piEndCHS:	resb 3
piStart:	resd 1
piLength:	resd 1
	endstruc

ptEmpty:		equ 0
ptFAT12:		equ 1
ptFAT16_16BIT_CHS:	equ 4
ptExtendedCHS:		equ 5
ptFAT16_CHS:		equ 6
ptFAT32_CHS:		equ 0Bh
ptFAT32:		equ 0Ch
ptFAT16:		equ 0Eh
ptExtended:		equ 0Fh
ptLinux:		equ 83h
ptExtendedLinux:	equ 85h


query_no_geometry equ 4
query_no_chs equ 2
query_no_lba equ 1
query_fd_multiplier equ 1
query_hd_multiplier equ 256
query_all_multiplier equ query_fd_multiplier + query_hd_multiplier


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting

	numdef QUERY_PATCH,	1	; use new style patch of CHS/LBA/geometry
	numdef QUERY_DEFAULT,	0
	numdef RPL,		1	; support RPL and do not overwrite it
	numdef STACKSIZE,	2048
%if _STACKSIZE < 256
 %error Too small stack size
%elif _STACKSIZE > 3 * 1024
		; Note that we use 8 KiB for SectorSeg, 8 KiB for FATSeg,
		; 512 bytes + (ebpbNew - bpbNew) for the boot sector,
		; and a few paragraphs left for MCBs and headers. As the
		; protocol is implemented with a 20 KiB reserved area (below
		; EBDA / RPL / end of low memory), this results in a maximum
		; stack size around 3 KiB (substantially below 4 KiB).
 %error Too large stack size
%endif

	strdef PAYLOAD_FILE,	"edrdos.bin"
	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0


	cpu 8086
	org 0
start:
freedos_entry:
		; This is the FreeDOS compatible entry point.
		;  Supports FAT32 too.
		; cs:ip = 60h:0
		; whole load file loaded
		; first cluster of load file: not given!
		; first data sector: not given!
		; int 1Eh not modified, original address: not given!
		; bl = load unit (not used by us)
		; ss:bp -> boot sector with (E)BPB,
		;	    load unit field set, hidden sectors set
		;  (usually at 1FE0h:7C00h)
		; NEW: word [ss:bp - 14h] = "CL" to indicate command line
		;	then ss:bp - 114h -> 256 byte ASCIZ string

	lea bx, [bp + lsvCommandLine.start]
				; ss:bx -> command line buffer, if any
	cmp bp, - lsvCommandLine.start
				; enough data below bp to hold buffer ?
	jb @F			; no -->
	cmp sp, bx		; sp below-or-equal would-be buffer ?
	jbe .canbevalid		; yes, can be valid --> (and word access valid)
@@:
	cmp bp, - lsvCommandLine.signature
				; enough data below bp to hold our lsv ?
	jae @F			; yes -->
	test bp, 1		; valid to access even-aligned words ?
	jz @F			; yes -->
				; maybe not
.error:
	call error
	asciz "Invalid base pointer in FreeDOS entrypoint."
@@:
	and word [bp + lsvCommandLine.signature], 0
				; invalidate signature
.canbevalid:
	cmp word [bp + lsvCommandLine.signature], "CL"
				; valid signature ?
	je @F			; yes, keep bx pointing at buffer

	lea bx, [bp + lsvCommandLine.signature]
				; no, ss:bx -> lsv with signature
@@:
	cmp sp, bx		; sp below-or-equal needed stack frame ?
	jbe @F			; yes -->
	and bl, ~1		; make even-aligned stack (rounding down)
	mov sp, bx		; change sp
@@:


init_memory:
; Get conventional memory size and store it
		int 12h
		mov cl, 6
		shl ax, cl
%if _RPL
	xor si, si
	xchg dx, ax
	mov ds, si
	lds si, [4 * 2Fh]
	add si, 3
	lodsb
	cmp al, 'R'
	jne .no_rpl
	lodsb
	cmp al, 'P'
	jne .no_rpl
	lodsb
	cmp al, 'L'
	jne .no_rpl
	mov ax, 4A06h
	int 2Fh
.no_rpl:
	xchg ax, dx
%endif
	push ax
	mov cx, ax

.gotsegs:
	sub cx, (+_STACKSIZE -LOADCMDLINE + 512 + (ebpbNew - bpbNew) + 32 + 15) >> 4
			; +_STACKSIZE = stack space
			; -LOADCMDLINE = load cmd line + data + lsv space
			; 512 = boot sector (allows finding filename)
			; (ebpbNew - bpbNew) = additional space for BPBN moving
			; 32 = leave space for lower buffer MCB + header
		; cx = stack seg

	mov dx, cs
	add dx, paras(payload.end - $$)
	cmp cx, dx
	jnb @F
.error_outofmemory:
	call error
	db "Out of memory.", 0
@@:

	mov dx, ss
	mov ax, bp
	add ax, 512 + 15
	jnc @F
	mov ax, 1_0000h >> 1
	db __TEST_IMM16	; (skip one shr)
@@:
	shr ax, 1
	shr ax, 1
	shr ax, 1
	shr ax, 1
	add dx, ax
	cmp dx, cx
	ja .error_outofmemory

		; note that the next conditional doesn't jump for lsvFATSeg = 0

	pop dx		; top of memory (=> start of RPL, EBDA, video memory)
	push ss
	pop ds
	mov es, cx
	push cx		; top of memory below buffers

	xor cx, cx
	lea si, [bp + lsvCommandLine.start]
	cmp bp, si	; can have command line ?
			;  (also makes sure movsw and lodsw never run
			;  with si = 0FFFFh which'd cause a fault.)
	jb .no_cmdline

	mov di, _STACKSIZE - LOADCMDLINE + ldCommandLine.start
			; -> cmd line target
	mov cl, (LOADCMDLINE_size + 1) >> 1
	rep movsw	; copy cmd line
%if lsvCommandLine.start + fromwords(words(LOADCMDLINE_size)) != lsvCommandLine.signature
 %error Unexpected structure layout
%endif
	lodsw
	cmp ax, lsvclSignature
	je @F		; if command line given -->
.no_cmdline:
	mov byte [es: _STACKSIZE - LOADCMDLINE + ldCommandLine.start ], cl
			; truncate as if empty line given
	dec cx		; cl = 0FFh
@@:
	mov byte [es: _STACKSIZE - LOADCMDLINE + ldCommandLine.start \
		+ fromwords(words(LOADCMDLINE_size)) - 1 ], cl
			; remember whether command line given
			;  = 0 if given (also truncates if too long)
			;  = 0FFh if not given

		; si happens to be already correct here if we didn't
		;  branch to .no_cmdline, however make sure to set
		;  it here to support this case.
	lea si, [bp + lsvExtra]
			; ds:si -> lsv + BPB
	mov di, _STACKSIZE - LOADCMDLINE + lsvExtra
			; es:di -> where to place lsv
	mov cx, (- lsvExtra + 512 + 1) >> 1
	rep movsw	; copy lsv (including lsvExtra) and BPB
	xor ax, ax
	mov cx, ((ebpbNew - bpbNew + 15) & ~15) >> 1
	rep stosw	; initialise area behind sector (left so for FAT32)
	pop cx
	mov ss, cx
	mov sp, _STACKSIZE
			; -> above end of stack space
	mov bp, _STACKSIZE - LOADCMDLINE
			; -> BPB, above end of lsv
	sti

		; ax => sector buffer
		; bx => FAT buffer
		; cx => above end of memory available for load
		; dx => above end of memory used by us
	mov word [bp + ldMemoryTop], dx
	mov word [bp + ldLoadTop], cx

	push ss
	pop es
	push ss
	pop ds

	mov bx, [bp + bsBPB + bpbSectorsPerFAT]
	test bx, bx
	jz .fat32

	; lea si, [bp + 510]			; -> last source word
	mov si, _STACKSIZE - LOADCMDLINE + 510
	lea di, [si + (ebpbNew - bpbNew)]	; -> last dest word
	mov cx, (512 - bsBPB - bpbNew + 1) >> 1
			; move sector up, except common BPB start part
%if ((512 - bsBPB - bpbNew + 1) >> 1) <= 20
 %fatal Need AMD erratum 109 workaround
%endif
	std		; AMD erratum 109 handling not needed
	rep movsw
	cld

	mov word [bp + lsvFirstCluster + 2], cx
	mov word [bp + lsvFATSector + 2], cx

	mov word [bp + bsBPB + ebpbSectorsPerFATLarge], bx
	mov word [bp + bsBPB + ebpbSectorsPerFATLarge + 2], cx
	mov word [bp + bsBPB + ebpbFSFlags], cx

	xchg ax, cx		; ax = 0
	push ss
	pop es
	lea di, [bp + bsBPB + ebpbFSFlags]
	mov cx, (EBPB_size - ebpbFSFlags) / 2
	rep stosw
		; initialise ebpbFSFlags (reinit), ebpbFSVersion,
		;  ebpbRootCluster, ebpbFSINFOSector, ebpbBackupSector,
		;  ebpbReserved

.fat32:

	push ss
	pop es
	lea di, [bp + ldCommandLine.start]
	mov cx, lsvclBufferLength
	xor ax, ax
	push word [bp + ldCommandLine.start + lsvclBufferLength - 1]
				; get sentinel (whether command line given)
	repne scasb		; scan for terminator
	pop ax			; al = 0FFh if no command line given
				; al = 0 else
	rep stosb		; clear remainder of buffer

%if _QUERY_PATCH
	mov ax, word [cs:..@query_patch_site]
%else
	mov ax, _QUERY_DEFAULT
%endif
	mov word [bp + ldQueryPatchValue], ax

	mov ax, cs
	add ax, ((payload -$$+0) >> 4) + _EXEC_SEGMENT
	push ax
%if _EXEC_OFFSET
	mov ax, _EXEC_OFFSET
%else
	xor ax, ax
%endif
	push ax
		; cs:ip = xxxxh:_EXEC_OFFSET
		; entire payload loaded (payload -- payload.actual_end)
		; LOADSTACKVARS and LOADDATA and EBPB and ebpbNew BPBN set
		; LOADCMDLINE set (ASCIZ, up to 255 bytes + 1 byte terminator)
		; word [ldCommandLine.start] = 0FF00h if had invalid signature
	retf


 %if _QUERY_PATCH
query_geometry:
		; magic bytes start
	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
				; magic bytes
	mov ax, _QUERY_DEFAULT	; magic bytes, checked by patch script
..@query_patch_site equ $ - 2
	test dl, dl		; hard disk unit ?
	jns @F			; no -->
	xchg al, ah		; get high byte into al
		; magic bytes end
@@:
  %if ($ - $$) > 1536
   %error Query patch site should be in first 1536 Bytes
  %endif
 %endif


error:
	push cs
	pop ds
	mov si, msg.error
	call disp_error
	pop si
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


msg:
.error:	db "Load error: ", 0


	align 16, db 38
payload:
	incbin _PAYLOAD_FILE
	align 16, db 38
.actual_end:
.end:
