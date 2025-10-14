
%if 0

Loader for finishing file system booting
 by E. C. Masloch, 2017--2025

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

	struc LOADMULTIVARS, LOADCMDLINE - 8
ldmCluster:	resd 1
ldmSector:	resd 1
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
	numdef QUERY_GEOMETRY,	1	; query geometry via 13.08 (for CHS access)
	numdef RPL,		1	; support RPL and do not overwrite it
	numdef CHS,		1	; support CHS (if it fits)
	numdef LBA,		1	; support LBA (if available)
	numdef LBA_33_BIT,	1	; support 33-bit LBA
	numdef LBA_CHECK_NO_33,	1	; else: check that LBA doesn't carry
	numdef MULTISECTOR,	1	; stash multi-sector loader into end2
	numdef LBA_MULTI,	1	; stash LBA multi-sector loader into end3
	numdef ADDPROGRESS,	1	; patch to display progress dots in end3
	numdef MULTIBOOT1,	1	; use Multiboot specification loader
	numdef MULTIBOOT2,	1	; use Multiboot2 specification loader
	numdef EDRDOS,		0	; use heuristic to detect EDR-DOS entry
	numdef EDRDOS_AUTO,	1	; support EDR-DOS entry if large enough
	numdef LSVEXTRA,	1	; use lsvExtra field
		; (needed if to use partition scanner)

	numdef LBA_SKIP_CHECK,	0	; don't use proper LBA extensions check
	numdef LBA_RETRY,	1	; retry LBA reads
	numdef CHS_RETRY,	1	; retry CHS reads
	numdef DMA_BOUNDARY_CHECK_CODE,0; check for DMA boundary error code,
					;  if 0 then always try sectorseg read
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
	numdef CHECKSUM,	0	; include checksumming of kernel image
%if _CHECKSUM
 %include "inicheck.mac"
%endif

	numdef PADDING, 0
	strdef PAYLOAD_FILE,	"lDOSLOAD.BIN"
	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0
	strdef INILOAD_SIGNATURE,	"XX"
	numdef TEST_PROGRAM,	0

	numdef IMAGE_EXE,	0
	numdef IMAGE_EXE_CS,	-16	; relative-segment for CS
	numdef IMAGE_EXE_IP,	256 +64	; value for IP
		; The next two are only used if _IMAGE_EXE_AUTO_STACK is 0.
	numdef IMAGE_EXE_SS,	-16	; relative-segment for SS
	numdef IMAGE_EXE_SP,	0FFFEh	; value for SP (0 underflows)
	numdef IMAGE_EXE_AUTO_STACK,	0, 2048	; allocate stack behind image
	numdef IMAGE_EXE_MIN,	65536	; how much to allocate for the process
%ifndef _IMAGE_EXE_MIN_CALC
 %define _IMAGE_EXE_MIN_CALC	\
		(((_IMAGE_EXE_MIN \
		- (payload.actual_end - payload) \
		- 256 \
		+ _IMAGE_EXE_AUTO_STACK) + 15) & ~15)
%endif
	numdef IMAGE_EXE_MAX, -1

	numdef SECOND_PAYLOAD_EXE,	0
	numdef SECOND_PAYLOAD_EXE_CS,	-16
	numdef SECOND_PAYLOAD_EXE_IP,	256 +64
	numdef SECOND_PAYLOAD_EXE_SS,	-16
	numdef SECOND_PAYLOAD_EXE_SP,	0FFFEh
	numdef SECOND_PAYLOAD_EXE_AUTO_STACK,	0, 2048
	numdef SECOND_PAYLOAD_EXE_MIN,	65536
%ifndef _SECOND_PAYLOAD_EXE_MIN_CALC
 %define _SECOND_PAYLOAD_EXE_MIN_CALC	\
		(((_SECOND_PAYLOAD_EXE_MIN \
		- (second_payload.actual_end - second_payload) \
		- 256 \
		+ _SECOND_PAYLOAD_EXE_AUTO_STACK) + 15) & ~15)
%endif
	numdef SECOND_PAYLOAD_EXE_MAX, -1
	strdef SECOND_PAYLOAD_FILE,	"lDOSEXEC.COM"
	strdef EXE_TRAIL_INCBIN, ""


%define MODULE iniload
	strdef INILOAD_CFG, ""
%ifnidn _INILOAD_CFG, ""
 %include _INILOAD_CFG
%endif


	cpu 8086
	org 0

%if _EDRDOS_AUTO
filesize equ end_of_file - $$
 %if filesize >= (32 * 1024)
  %assign _EDRDOS 1
 %else
  %assign _EDRDOS 0
 %endif
%endif

%if _IMAGE_EXE && _SECOND_PAYLOAD_EXE
 %error Cannot use both of these.
%endif

%ifn _LBA || _CHS
 %error Neither disk access method enabled.
%endif

%push
%define %$string _INILOAD_SIGNATURE
%strlen %$length %$string
%if %$length != 2
 %error Invalid signature
%endif
%substr %$letter %$string 1
%if %$letter <= 32 || %$letter >= 127
 %error Invalid signature
%endif
%substr %$letter %$string 2
%if %$letter <= 32 || %$letter >= 127
 %error Invalid signature
%endif
%pop


start:
	db "MZ"		; exeSignature
		; dec bp, pop dx
	jmp strict short ms6_entry	; exeExtraBytes
			; db 0EBh, 16h	; dw 16EBh
%if _IMAGE_EXE
		; For now hardcoded to carry a .COM-like executable.
		; Note: With _IMAGE_EXE_AUTO_STACK, the
		;	 stack segment will be behind the image.
	dw (payload.end - $$ + 511) / 512	; exePages
	dw 0		; exeRelocItems
	dw (payload -$$+0) >> 4	; exeHeaderSize
	dw (_IMAGE_EXE_MIN_CALC + 15) >> 4	; exeMinAlloc
%if _IMAGE_EXE_MAX
	dw _IMAGE_EXE_MAX	; exeMaxAlloc
%else
	dw (_IMAGE_EXE_MIN_CALC + 15) >> 4	; exeMaxAlloc
%endif
%if _IMAGE_EXE_AUTO_STACK
	dw ((payload.actual_end - payload) \
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
%elif _SECOND_PAYLOAD_EXE
		; For now hardcoded to carry a .COM-like executable.
		; Note: With _SECOND_PAYLOAD_EXE_AUTO_STACK, the
		;	 stack segment will be behind the image.
	dw (second_payload.end - $$ + 511) / 512	; exePages
	dw 0		; exeRelocItems
	dw (second_payload -$$+0) >> 4	; exeHeaderSize
	dw (_SECOND_PAYLOAD_EXE_MIN_CALC + 15) >> 4	; exeMinAlloc
%if _SECOND_PAYLOAD_EXE_MAX
	dw _SECOND_PAYLOAD_EXE_MAX	; exeMaxAlloc
%else
	dw (_SECOND_PAYLOAD_EXE_MIN_CALC + 15) >> 4	; exeMaxAlloc
%endif
%if _SECOND_PAYLOAD_EXE_AUTO_STACK
	dw ((second_payload.actual_end - second_payload) \
		+ _SECOND_PAYLOAD_EXE_MIN_CALC \
		- _SECOND_PAYLOAD_EXE_AUTO_STACK + 15) >> 4	; exeInitSS
	dw _SECOND_PAYLOAD_EXE_AUTO_STACK	; exeInitSP
%else
	dw _SECOND_PAYLOAD_EXE_SS	; exeInitSS
	dw _SECOND_PAYLOAD_EXE_SP	; exeInitSP
%endif
	dw 0		; exeChecksum
	dw _SECOND_PAYLOAD_EXE_IP, _SECOND_PAYLOAD_EXE_CS	; exeInitCSIP
	dw 0		; exeRelocTable
%else
	dw -1		; exePages
	dw 0		; exeRelocItems
	dw 0		; exeHeaderSize
	dw -1		; exeMinAlloc
	dw -1		; exeMaxAlloc
	dw -16, 0	; exeInitSS, exeInitSP
	dw 0		; exeChecksum
	dw 100h, -16	; exeInitCSIP
	dw 0		; exeRelocTable
%endif

ms6_entry:
		; This is the MS-DOS 6 / IBMDOS compatible entry point.
		;  Note that this supports FAT32 for PC-DOS 7.10!
		; cs:ip = 70h:0
		; ax:bx = first data sector of first cluster,
		;	including hidden sectors
		; 0:7C00h-> boot sector with BPB,
		;	    load unit field set, hidden sectors set
		; (actually boot unit in dl; because the "MZ" signature
		;  destroys dl we assume it's in the BPB too)
		; ss:sp is expected to -> below-or-equal 0:7C00h, this fact
		;  is used to detect EDR-DOS load if cs = 70h as EDR-DOS load
		;  will never overlap the stack with the loaded file data.
		; Note that bp may be unset by MS-DOS 6 loaders!
		; Either:
		;	dword [ss:sp] = 0:78h = 1Eh * 4 (IVT entry of int 1Eh)
		;	dword [ss:sp + 4] = old int 1Eh address
		; Or:
		;	ds:si = old int 1Eh address
		; 0:500h-> directory entry for BIO file
	cli
	push dx
	inc bp		; undo signature instructions

d3	call d3_display_two_characters
d3	test ax, "00"

	mov cx, cs
	cmp cx, 70h
	je @F
.freedos_or_msdos1_com_entry:
	jmp freedos_or_msdos1_com_entry
@@:

%if _EDRDOS
	mov di, sp			; -> sp
	mov cl, 4
	shr di, cl			; to paragraphs, rounding down
	mov cx, ss			; => ss
	add di, cx			; ss:sp converted to paragraphs
	cmp di, 70h + paras(end_of_file - $$)
	jae .freedos_or_msdos1_com_entry; doesn't overlap file data -->
%endif

;	xor cx, cx
;;	test dx, dx
;;	jnz @FF
		; Actual DOS will always put a zero word on top of
		;  the stack. But when the debugger loads us as
		;  a flat format binary it may set up another
		;  stack segment or not initialise the stack slot.
		;  (So as to avoid corrupting the binary.)
		; The offset check should suffice anyway.
	call @F
@@:
	pop cx
	sub cx, @B	; cx == 0 iff entered at offset 0
	jne .freedos_or_msdos1_com_entry
@@:
			; cx = 0

		; Note: It has been observed that some IBMBIO.COM / IO.SYS
		;	 boot sector loaders pass the int 1Eh address on the
		;	 stack (like MS-DOS 7 loading does). So we detect
		;	 whether the first dword (far pointer to IVT entry)
		;	 matches and then assume that the second dword has
		;	 the original int 1Eh address. Else, ds:si is used.
	mov bp, sp
	mov di, 1Eh * 4	; -> IVT entry of int 1Eh
	cmp dx, di	; int 1Eh address on stack ?
	jne .dssi	; no -->
	cmp word [bp + 2], cx	; segment 0 in next word ?
	jne .dssi	; no -->
	pop si
	pop ds		; discard
	pop si
	pop ds		; get old int 1Eh address from stack
.dssi:
	cld
	mov bp, 7C00h			; 0:bp -> boot sector with BPB
	jmp ms6_continue1


error:
%if _MULTISECTOR
.multi_patch:
	test ax, restore_dpt - @F
@@:
%endif
	mov si, msg.error
	call disp_error		; display "Load error: "
	pop si			; -> ASCII string terminated by dot
	call disp_error		; display up to before dot
	dec si			; -> point back at dot to return after display
	call disp_error.loop	; display the dot, ah = 0
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
	cs lodsb
	cmp al, '.'
	jne .loop
	cbw			; al = 2Eh '.' so ah here becomes zero
	retn


		; INP:	EBPB new unit field
		;	query patch site
		; OUT:	BPB CHS heads and sectors rewritten (if query success)
		;	ldHasLBA set to 1 or 0 to use LBA or CHS accesses
		; CHG:	ax, bx, cx, dx, es, di
query_geometry:
%if _QUERY_GEOMETRY || !_LBA_SKIP_CHECK
		; magic bytes start
	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
				; magic bytes
 %if _QUERY_PATCH
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
%endif

%if _QUERY_GEOMETRY	; +30 bytes
 %if !_LBA_SKIP_CHECK
	push dx
  %if _QUERY_PATCH
	push ax
  %endif
 %endif

  %if _QUERY_PATCH
	test al, 4		; don't query geometry ?
	jnz @F			; yes -->
  %endif

		; Note:	The int 13h function 08h call may change or
		;	 set ax, bx, cx, dx, es, di. es is left as
		;	 indeterminate afterwards.
;	test dl, dl		; floppy?
;	jns @F			; don't attempt query, might fail -->
	; Note that while the original PC BIOS doesn't support this function
	;  (for its diskettes), it does properly return the error code 01h.
	; https://sites.google.com/site/pcdosretro/ibmpcbios (IBM PC version 1)
	mov ah, 08h
	xor cx, cx		; initialise cl to 0
	stc			; initialise to CY
	int 13h			; query drive geometry
	jc @F			; apparently failed -->
	and cx, 3Fh		; get sectors
	jz @F			; invalid (S is 1-based), don't use -->
	mov [bp + bsBPB + bpbCHSSectors], cx
	mov cl, dh		; cx = maximum head number
	inc cx			; cx = number of heads (H is 0-based)
	mov [bp + bsBPB + bpbCHSHeads], cx
@@:
%endif

%if !_LBA_SKIP_CHECK
 %if _QUERY_GEOMETRY
  %if _QUERY_PATCH
	pop ax			; restore query patch flags in al
  %endif
	pop dx			; restore unit number in dl
 %endif
 %if _QUERY_PATCH
	shr al, 1		; CY if force CHS
	jc @F			; if so -->
	and al, 1		; force LBA ?
	jnz .done_lba		; yes -->
 %endif
	push ds
	mov bx, 40h	; bx = 40h
	mov ds, bx	; ds = 40h
; Setting ds = 40h is a Book8088 bugfix, refer to
;  http://www.bttr-software.de/forum/forum_entry.php?id=21061

	mov ax, 4100h
	mov bx, 55AAh
	xor cx, cx
	xor dh, dh
	stc
	int 13h		; 13.41.bx=55AA extensions installation check
	pop ds
@@:
	mov al, 0	; zero in case of no LBA support
	jc .no_lba
	cmp bx, 0AA55h
	jne .no_lba
	shr cl, 1	; support bitmap bit 0
	jnc .no_lba
	inc ax		; al = 1 to indicate LBA support
.no_lba:
.done_lba:
	mov byte [bp + ldHasLBA], al
%else
	mov byte [bp + ldHasLBA], 0
%endif

%if 1 || _QUERY_GEOMETRY || !_LBA_SKIP_CHECK
	retn
%endif


		; Read a sector using Int13.02 or Int13.42
		;
		; INP:	dx:ax = sector number within partition
		;	bx:0-> buffer
		;	(_LBA) ds = ss
		; OUT:	If unable to read,
		;	 ! jumps to error instead of returning
		;	If sector has been read,
		;	 dx:ax = next sector number (has been incremented)
		;	 bx:0-> next buffer (bx = es+word[para_per_sector])
		;	 es = input bx
		; CHG:	-
		; STT:	ds = ss
		;
		; Note:	If error 09h (data boundary error) is returned,
		;	 the read is done into the ldSectorSeg buffer,
		;	 then copied into the user buffer.
		; Note:	With _DMA_BOUNDARY_CHECK_CODE=0 we don't check
		;	 for error 09h, rather we assume that an error
		;	 will always be either a data boundary error
		;	 what can be cured by using the sectorseg, or
		;	 else the sectorseg attempt will error out on
		;	 its own eventually doing no additional harm.
read_sector:
	push dx
	push cx
	push ax
	push si

%if _ADDPROGRESS
.patch_progress:
	test ax, read_progress_single - @F
@@:
%endif
	mov es, bx

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[bp + bsBPB + bpbHiddenSectors + 0]
		adc dx,[bp + bsBPB + bpbHiddenSectors + 2]

 %if (!_LBA || !_LBA_33_BIT) && _LBA_CHECK_NO_33
	jc .err_CY_2
  %if !_LBA
.err_CY_2: equ .err_CY_1
  %endif
 %endif
%if _LBA		; +70 bytes (with CHS, +63 bytes without CHS)
 %if _LBA_33_BIT
	sbb si, si	; -1 if was CY, 0 else
	neg si		; 1 if was CY, 0 else
 %endif
	xor cx, cx	; cx = 0 (needed if jumping to .no_lba_checked)
 %if !_LBA_SKIP_CHECK
	test byte [bp + ldHasLBA], 1
	jz .no_lba_checked
 %endif
	push cx
 %if _LBA_33_BIT
	push si		; bit 32 = 1 if operating in 33-bit space
 %else
	push cx		; second highest word = 0
 %endif
	push dx
	push ax		; qword sector number (lpSector)
	push bx
	push cx		; bx:0 -> buffer (lpBuffer)
	push cx		; word number of sectors to read (lpCount),
			;  only need to init the high byte here (0)
	mov cl, 10h
	push cx		; word size of disk address packet (lpSize)
	mov si, sp	; ds:si -> disk address packet (on stack)

	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
%if _LBA_RETRY
	mov ah, 42h	; 13.42 extensions read
	call .int13_retry	; clobbers cx if NC
%else
	mov ax, 4201h	; 13.42 extensions read
	call .int13_set_lpcount
%endif
	jnc .lba_done

%if _LBA_SKIP_CHECK
	cmp ah, 1	; invalid function?
	je .no_lba_skip	; try CHS instead -->
%endif
%if _DMA_BOUNDARY_CHECK_CODE
	cmp ah, 9	; data boundary error?
	jne .lba_error
%endif

	; push word [si + 4 + 0]
	push es		; => user buffer
	 mov es, word [bp + ldSectorSeg]
	 mov word [si + 4 + 2], es
	; and word [si + 4 + 0], byte 0

%if _LBA_RETRY
	mov ah, 42h
	call .int13_retry	; clobbers cx if NC
%else
	mov ax, 4201h	; 13.42 extensions read
	call .int13_set_lpcount
%endif
.err_CY_2:
	jc .err_CY_1
%ifn _CHS
.err_CY_1: equ .err
%endif

	pop es
	; pop cx
	add sp, word [si + lpSize]
	jmp .sectorseg_helper_then_done

.lba_error: equ .err

 %if !_CHS
.no_lba_skip: equ .err
.no_lba_checked: equ .err
 %elif _LBA_SKIP_CHECK
.no_lba_skip:
	add sp, 8
	pop ax
	pop dx
  %if _LBA_33_BIT
	pop si
	pop cx		; cx = 0 (needed as input for next cwd instruction)
	test si, si
	mov si, sp	; si == sp
  %else
	pop cx
	pop cx
		; si == sp - 16
  %endif
 %else
.no_lba_checked:
  %if _LBA_33_BIT
	test si, si
  %endif
	mov si, sp	; si == sp
 %endif
%endif

%if _CHS		; +70 bytes
 %if _LBA && _LBA_33_BIT
	jnz .err_NZ_2
 %endif
 %if _LBA
	sub si, lpCount + 2 + 16
		; point byte [ds:si + lpCount] -> unclaimed stack space
		;  the lpCount + 2 is for the offset,
		;  the 16 is to cover subsequent allocations on the stack
		;  (watch for {lpcountalloc})
 %endif
; dx:ax = LBA sector number, (if _LBA) cx = 0
; divide by number of sectors per track to get sector number
; Use 32:16 DIV instead of 64:32 DIV for 8088 compatability
; Use two-step 32:16 divide to avoid overflow
 %if !_LBA
			xchg cx, ax	; cx = low word of sector, clobbers ax
			xchg ax, dx	; ax = high word of sector, clobbers dx
			xor dx, dx	; dx:ax = high word of sector
 %else
			xchg cx, ax	; cx = low word of sector, ax = 0
			push dx		; stack = high word of sector
			cwd		; dx = 0 (because ax was 0)
			pop ax		; ax = high word of sector
					; dx:ax = high word of sector
 %endif
.dx_ax_cx_lba_to_chs:
			div word [bp + bsBPB + bpbCHSSectors]
			xchg cx,ax
			div word [bp + bsBPB + bpbCHSSectors]
			xchg cx,dx

; DX:AX=quotient, CX=remainder=sector (S) - 1
; divide quotient by number of heads
			xchg bx, ax	; bx = low word of quotient, clobbers ax
			xchg ax, dx	; ax = high word of quotient, clobbers dx
			xor dx, dx	; dx = 0
			div word [bp + bsBPB + bpbCHSHeads]
					; ax = high / heads, dx = high % heads
			xchg bx, ax	; bx = high / heads, ax = low quotient
			div word [bp + bsBPB + bpbCHSHeads]

; bx:ax=quotient=cylinder (C), dx=remainder=head (H)
; move variables into registers for INT 13h AH=02h
			mov dh, dl	; dh = head
			inc cx		; cl5:0 = sector
			xchg ch, al	; ch = cylinder 7:0, al = 0
			shr ax, 1
			shr ax, 1	; al7:6 = cylinder 9:8
	; bx has bits set iff it's > 0, indicating a cylinder >= 65536.
			 or bl, bh	; collect set bits from bh
			or cl, al	; cl7:6 = cylinder 9:8
	; ah has bits set iff it was >= 4, indicating a cylinder >= 1024.
			 or bl, ah	; collect set bits from ah
			mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
					; dl = drive
.err_NZ_2:
			 jnz .err_NZ_1	; error if cylinder >= 1024 -->
					; ! bx = 0 (for 13.02 call)

; we call INT 13h AH=02h once for each sector. Multi-sector reads
; may fail if we cross a track or 64K boundary

%if _CHS_RETRY
.dx_ax_cx_lba_to_chs_patch_E8:		; = 0E8h if to continue
					; = 0C3h if to return
			call .int13_retry_ah	; clobbers cx if NC
					; {lpcountalloc} near call
%else
.dx_ax_cx_lba_to_chs_patch_B8:		; = 0B8h if to continue
					; = 0C3h if to return
			mov ax, 0201h	; read one sector
			int 13h
%endif
			jnc .done

%if _DMA_BOUNDARY_CHECK_CODE
	cmp ah, 9	; data boundary error?
.err_NZ_1:
	jne .err
%else
.err_NZ_1: equ .err
%endif

	push es		; user buffer, {lpcountalloc}
	 mov es, word [bp + ldSectorSeg]

%if _CHS_RETRY
	call .int13_retry_ah		; clobbers cx if NC
					; {lpcountalloc} near call
%else
	mov ax, 0201h
	int 13h
%endif
.err_CY_1:
	jnc .sectorseg_helper_es
%endif		; _CHS
.err:
error_diskaccess: equ $
	call error
	db "Disk read error."


%if _CHS
.sectorseg_helper_es:
	pop es
%endif

.sectorseg_helper_then_done:
	xor si, si
	mov ds, word [bp + ldSectorSeg]
	 push di
	; mov di, cx
	xor di, di
	mov cx, word [bp + bsBPB + bpbBytesPerSector]
	rep movsb
	 pop di

	push ss
	pop ds

%if _LBA
	db __TEST_IMM16			; skip add sp
.lba_done:
	add sp, word [si + lpSize]
 %if ($ - .lba_done) != 2
  %error Unexpected add sp instruction size
 %endif
%endif
.done:
; increment segment
	mov bx, es
	add bx, word [bp + ldParaPerSector]

	pop si
	pop ax
	pop cx
	pop dx
.increment_sector_number:
; increment LBA sector number
	inc ax
	jne @F
	inc dx
@@:
	db __TEST_IMM8		; skip pop cx
.popcxret:		; NC stack has function number
	pop cx		; discard word on stack, preserve NC, clobber cx
	retn


%if (_LBA && _LBA_RETRY) || (_CHS && _CHS_RETRY)
 %if _CHS && _CHS_RETRY
.int13_retry_ah:
	mov ah, 02h	; CHS read function
 %endif
.int13_retry:
	mov al, 01h	; counter for CHS read, lpCount value for LBA read
	push ax		; {lpcountalloc}
%if _LBA
	call .int13_set_lpcount
			; {lpcountalloc} near call
%else
	int 13h		; first try
%endif
	jnc .popcxret	; NC, success on first attempt --> (clobbers cx)

; reset drive
	xor ax, ax
	int 13h		; ignore CF status from the reset, to save on code size

; try read again
	pop ax		; restore function number
%if ! _LBA
	int 13h		; retry, CF error status, ah error number
	retn
%endif		; else: fall through to .int13_set_lpcount
%endif

%if _LBA
		; have to (re)set the LBAPACKET's lpCount, as the handler may
		;  set it to "the number of blocks successfully transferred".
		;  rather than preserve it as before, always set it to 1 here.
		;  the high byte is already initialised to zero and cannot be
		;  changed by the call, so the entire word equals 1 after the
		;  low byte is set here.

		; hack: si points into unclaimed stack space
		;  when this is called from the CHS handler.
		;  this should not cause any issues however.
		;  {lpcountalloc}

		; INP:	ah = function number
		;	al = count of sectors (always 1)
		; OUT:	NC if success
		;	CY if error,
		;	 ah = error code
.int13_set_lpcount:
	mov byte [si + lpCount], al
	int 13h
	retn
%endif


error_shortfile:
	call error
	db "File is too short."

error_badchain:
	call error
	db "Bad cluster chain."

error_badclusters:
	call error
	db "Bad amount of clusters."

error_outofmemory:
	call error
	db "Out of memory."

%assign num 512-($-$$)
%if num >= 3
%assign num num - 3
 %warning %[num]+3 bytes in front of ms7_entry
	_fill 512 - 3,38,start
error_outofmemory_j1:
	jmp error_outofmemory
%else
error_outofmemory_j1: equ error_outofmemory
 %warning num bytes in front of ms7_entry
%endif
	_fill 512,38,start
ms7_entry:
		; This is the MS-DOS 7 compatible entry point.
		;  Supports FAT32 too.
		; cs:ip = 70h:200h
		; (si:)di = first cluster of load file
		; dwo [ss:bp - 4] = first data sector (with hidden sectors)
		; dwo [ss:sp] = 0:78h (IVT entry of int 1Eh)
		; dwo [ss:sp + 4] = old int 1Eh address
		; ss:bp -> boot sector with (E)BPB,
		;	    load unit field set, hidden sectors set
	inc dx
	dec dx		; "BJ" signature (apparently not about FAT32 support)

	jmp .continue	; jump to handler above 600h (sector loads 800h bytes)

.ms6_common:		; cx = 0
	mov ax, 70h + ((3 * 512) >> 4)	; MS6 entry has 3 sectors loaded
					;  (and is always segment 70h)

.continue2_set_extra_and_empty_cmdline:	; cx = 0, ax => behind loaded
%if _LSVEXTRA
	mov word [bp + lsvExtra], cx
%endif
	mov word [bp + lsvCommandLine], cx
.continue2:				; cx = 0, ax => behind loaded
	mov word [bp + lsvLoadSeg], ax

	mov word [bp + lsvFATSeg], cx	; initialise to zero (for FAT12)
	dec cx
	mov word [bp + lsvFATSector + 0], cx
	mov word [bp + lsvFATSector + 2], cx	; initialise to -1

		; Actually it seems that the MS-DOS 7 loaders load 4 sectors
		;  instead of only three (as the MS-DOS 6 loaders do).
		;  We use this to store specific handling in that last sector.

	jmp ldos_entry.ms7_common

msg:
.error:	db "Load error: ."


finish_continue:
	mov word [bp + lsvFATSeg], cx
	mov ax, (payload.actual_end -$$+0 +15) >> 4
	push ax
		; on stack: payload.actual_end in paragraphs
	mov bx, [bp + ldParaPerSector]
	dec bx		; para per sector - 1
	add ax, bx	; round up
		; assumed to not overflow, (payload.actual_end + 8192) < 10_0000h
payload_actual_end_equate equ payload.actual_end -$$+0
%ifn (payload_actual_end_equate + 15 + 8192) < 10_0000h
 %error Overflow possible
%endif
	not bx		; ~ (para per sector - 1)
	and ax, bx	; rounded up,
		; ((payload.actual_end -$$+0 +15) >> 4 + pps - 1) & ~ (pps - 1)
	mov bx, cs
	add ax, bx	; = cs + rounded up length
	jc @F		; overflow ? then we're near top of memory -->
	cmp ax, word [bp + ldLoadTop]	; = paras to move down
	; ja @FF	; end of load > available, then need to relocate -->
	jbe short finish_load
@@:
	sub ax, word [bp + ldLoadTop]	; = paras to move down
			; calculate end of wanted load minus available,
			;  will CY if branched to this @@, NC if fell through
	mov cx, word [bp + lsvLoadSeg]
			; => after end of loaded data
	sub word [bp + lsvLoadSeg], ax
			; relocate this pointer already
	neg ax
	add ax, bx	; ax = cs - paras to move down
			; want to relocate cs to this
	jnc short error_outofmemory_j1
	cmp ax, 60h + 1
	jb short error_outofmemory_j1

	push ax
	call finish_relocation
			; dword on stack: relocate_to


		; ds => first chunk of to be relocated data
		; es => first chunk of relocated data
		; bx = 1000h (64 KiB >> 4)
		; ax = number of paragraphs after first chunk (in next chunk)
		; cx = 0
relocate_to:
		; when branched here from relocator: cx = 0,
		;  makes the following rep movsw a nop
@@:		; when branched back here from later: cx = 8000h
	rep movsw	; subsequent but not last relocation

	mov dx, es
	add dx, bx
	mov es, dx	; next segment

	mov dx, ds
	add dx, bx
	mov ds, dx	; next segment

		; If there is another part to move then the
		;  prior move was a full 64 KiB, so the si
		;  and di registers have wrapped around back
		;  to zero. Therefore we needn't re-initialise
		;  them here, the next part wants zeroes too.
		; If there's no next part then the final move
		;  will run with cx = 0 so it doesn't matter
		;  what the si and di registers hold.

	sub ax, bx	; = how much to relocate after this round
		; cx = 0
	mov ch, (1000h << 3) >> 8
			; in case another full 64 KiB to relocate
		; cl = 0
	jae @B		; another full 64 KiB to relocate -->
	add ax, bx	; restore
	mov cl, 3
	shl ax, cl	; convert paragraphs to words
	xchg cx, ax	; cx = that many words
	rep movsw	; relocate last chunk (possibly zero length)

	push ss
	pop ds

		; ds = ss
		; cs = low enough to complete load
		; lsvLoadSeg => after last loaded fragment
		; ldLoadTop => after last available memory
		; ldParaPerSector = initialised
		; word [ss:sp] = payload.actual_end in paras
finish_load:
	pop ax
	mov bx, cs
	add ax, bx

	mov word [bp + ldLoadUntilSeg], ax
		; ldLoadUntilSeg => after last to-be-loaded paragraph

	cmp word [bp + lsvLoadSeg], ax
	jae short loaded_all_if_ae	; (for FreeDOS entrypoint) already loaded -->

	mov word [bp + ldLoadingSeg], cs

	mov ax, [bp + lsvFirstCluster]
	mov dx, [bp + lsvFirstCluster + 2]
	call check_clust
	jnc short error_badchain_j

skip_next_clust:
	push dx
	push ax
	call clust_to_first_sector
skip_next_sect:
	cmp bx, [bp + ldLoadUntilSeg]
	jae loaded_all.2stack

	add bx, [bp + ldParaPerSector]
				; bx += paras per sector
	cmp bx, [bp + lsvLoadSeg]
	ja skipped_all
				; emulate read_sector:
	call read_sector.increment_sector_number
				; dx:ax += 1
	loop skip_next_sect
loadorskip_next_cluster:
	pop ax
	pop dx
	call clust_next
	jc skip_next_clust
end_of_chain:
	inc ax
	inc ax
	test al, 8	; set in 0FFF_FFF8h--0FFF_FFFFh,
			;  clear in 0, 1, and 0FFF_FFF7h
	jz short error_badchain_j
	mov bx, [bp + ldLoadingSeg]
	cmp bx, [bp + ldLoadUntilSeg]
loaded_all_if_ae:
	jae loaded_all
	jmp error_shortfile


skipped_all:
	sub bx, [bp + ldParaPerSector]
				; restore bx => next sector to read
%if _MULTISECTOR
.multipatch:
	test ax, skipped_all_multi - @F
@@:
.single_sector:
%endif
	call read_sector
		; we can depend on the fact that at least
		;  up to end was already loaded, so this
		;  (successful) read_sector call loaded
		;  at least 32 bytes starting at end.
		; therefore, we can put part of the
		;  remaining handler into these 32 bytes.
	jmp skipped_all_continue


error_badchain_j:
	jmp error_badchain


		; ds => first chunk of to be relocated data
		; word [ss:sp] => first chunk of relocation destination
		; cx = number of words in first chunk
relocator:
	pop es		; => where to relocate to
	rep movsw
	retf		; jump to relocated relocate_to
.end:


finish_relocation:
	push ax		; word on stack => where to relocate to
	dec ax		; one less to allow relocator
	mov es, ax
	xor di, di	; es:di -> where to put relocator

	push es
	push di		; dword on stack: relocator destination

	mov ds, bx	; ds => unrelocated cs
	mov si, relocator	; ds:si -> relocator
relocator_size equ relocator.end - relocator
%rep (relocator_size + 1) / 2
	movsw		; place relocator
%endrep
%if relocator_size > 16
 %error Relocator is too large
%endif
	xor di, di	; word [ss:sp+4]:di -> where to relocate to
	xor si, si	; ds:si = cs:0

			; cx => after end of loaded data
	sub cx, bx	; length of currently loaded fragment
	mov bx, 1000h	; = amount paragraphs per 64 KiB
	mov ax, cx	; = amount paragraphs to relocate total
	cmp ax, bx	; > 64 KiB ?
	jbe @F		; no, do entire relocation at once -->
	mov cx, bx	; yes, first relocate the first 64 KiB
@@:			; cx = amount paragraphs to relocate first
	sub ax, cx	; ax = amount paragraphs to relocate later
	shl cx, 1
	shl cx, 1
	shl cx, 1	; how much to relocate first,
			;  << 3 == convert paragraphs to words
	retf		; jump to relocator


		; INP:	dx:ax = cluster - 2 (0-based cluster)
		; OUT:	dx:ax = first sector of that cluster
		;	cx = adjusted sectors per cluster
		;	bx => buffer, from ldLoadingSeg
clust_to_first_sector:
	mov cx, word [bp + ldClusterSize]
	 push dx
	mul cx			; dx:ax = low times SpC
	xchg bx, ax		; bx = low word result
	 pop ax			; ax = high
	push dx			; stack = low times SpC, high word
	mul cx			; dx:ax = high times SpC
	test dx, dx
	jnz short error_badchain_j
				; ax = high times SpC, low word
	pop dx			; dx = low times SpC, high word
	add dx, ax		; dx = high word result
.cy_error_badchain:
	jc short error_badchain_j
	xchg ax, bx		; ax = low word result, dx:ax = result

	add ax, [bp + lsvDataStart]
	adc dx, [bp + lsvDataStart + 2]
	jc short .cy_error_badchain
				; dx:ax = first sector in cluster
	mov bx, [bp + ldLoadingSeg]
	retn


		; INP:	dx:ax = cluster (0-based)
		; OUT:	NC if no next cluster
		;	CY if next cluster found
		;	dx:ax = next cluster value (0-based)
		; CHG:	es, cx, bx, si
clust_next:
	mov [bp + ldLoadingSeg], bx
	add ax, 2
	adc dx, 0

	mov es, [bp + lsvFATSeg]
	cmp byte [bp + ldFATType], 16
	je .fat16
	ja .fat32

.fat12:
; FAT12 entries are 12 bits, bytes are 8 bits. Ratio is 3 / 2,
;  so multiply cluster number by 3 first, then divide by 2.
					; ax = cluster number (up to 12 bits set)
		mov dx, ax
		shl ax, 1		; = 2n (up to 13 bits set)
		add ax, dx		; = 2n+n = 3n (up to 14 bits set)
		shr ax, 1		; ax = byte offset into FAT (0..6129)
					; CF = whether to use high 12 bits

; Use the calculated byte offset as an offset into the FAT
;  buffer, which holds all of the FAT's relevant data.
		xchg si, ax		; si -> 16-bit word in FAT to load

; get 16 bits from FAT
		es lodsw		; ax = word [es:si], clobber si

		mov cl, 4
		jc @F
		shl ax, cl	; shift up
@@:
		shr ax, cl	; shift down
	jmp short .gotvalue_zero_dx

.fat32:
		; * 4 = byte offset into FAT (0--4000_0000h)
	add ax, ax
	adc dx, dx
.fat16:
		; * 2 = byte offset into FAT (0--2_0000h)
	add ax, ax
	adc dx, dx

	 push ax
	xchg ax, dx
	xor dx, dx		; dx:ax = high word
	div word [bp + bsBPB + bpbBytesPerSector]
	xchg si, ax		; si = high word / divisor
	 pop ax			; dx = remainder, ax = low word
	div word [bp + bsBPB + bpbBytesPerSector]
	xchg dx, si		; dx:ax = result, si = remainder
				; dx:ax = sector offset into FAT (0--200_0000h)
				; si = byte offset into FAT sector (0--8190)
	cmp dx, word [bp + lsvFATSector + 2]
	jne @F		; read sector
	cmp ax, word [bp + lsvFATSector]
	je @FF		; sector is already buffered
@@:
	mov word [bp + lsvFATSector + 2], dx
	mov word [bp + lsvFATSector + 0], ax

	add ax, [bp + bsBPB + bpbReservedSectors]
	adc dx, 0
	mov bx, es
	call read_sector
@@:
	es lodsw
	xchg ax, dx
	es lodsw
	xchg ax, dx		; dx:ax = FAT32 entry

	cmp byte [bp + ldFATType], 16	; is it FAT32 ?
	jne @F			; yes -->
.gotvalue_zero_dx:
	xor dx, dx		; no, clear high word
@@:

		; INP:	dx:ax = cluster value, 2-based
		; OUT:	dx:ax -= 2 (makes it 0-based)
		;	NC iff invalid cluster
check_clust:
	and dh, 0Fh
	sub ax, 2
	sbb dx, 0

	cmp byte [bp + ldFATType], 16
	ja .fat32
	je .fat16

.fat12:
	cmp ax, 0FF7h - 2
	; jmp short .common
	retn

.fat32:
	cmp dx, 0FFFh
	jb @F		; CY here means valid ...-

.fat16:
	cmp ax, 0FFF7h - 2
@@:			;  -... or if NC first, CY here also
.common:
	; cmc		; NC if valid
	; CY if valid now !
	retn


ms6_continue1:
	mov es, cx			; cx = 0

	mov word [es:di], si
	mov word [es:di + 2], ds	; restore old int 1Eh address

	mov ss, cx			; = 0
	mov sp, 7C00h + lsvCommandLine

	push word [es:500h + 20]
	push word [es:500h + 26]
	pop word [bp + lsvFirstCluster + 0]
	pop word [bp + lsvFirstCluster + 2]

	sub bx, word [bp + bsBPB + bpbHiddenSectors + 0]
	sbb ax, word [bp + bsBPB + bpbHiddenSectors + 2]
	mov word [bp + lsvDataStart + 0], bx
	mov word [bp + lsvDataStart + 2], ax
	jmp ms7_entry.ms6_common	; passing cx = 0


%assign num 1020-($-$$)
%warning num bytes in front of ldos_entry
	_fill 1020,38,start
	dw "lD"		; always this signature (word [1020] == 446Ch)
	dw _INILOAD_SIGNATURE
			; two printable non-blank ASCII characters
			; (ie both bytes in the range 21h..7Eh)
			;  Rx = RxDOS kernel
			;  FD = FreeDOS kernel
			;  DR = EDR-DOS kernel
			;  MS = MS-DOS kernel
			;  TP = TestPL
			;  TW = Test writer
			;  (lD)eb = lDebug
			;  (lD)Db = lDDebug
			;  (lD)bC = lCDebug
			;  (lD)OS = lDOS kernel (lMS-DOS since 2025 February)
			;  XX = unset
%if ($ - $$) != 1024
 %error Invalid signature
%endif
ldos_entry:
	cli
	cld

		; ip = 400h
		; cs = arbitrary; typically 60h, 70h, or 200h
		; dwo [ss:bp - 4] = first data sector (without hidden sectors)
		; wo [ss:bp - 6] = load_seg, => after last loaded data
		; wo [ss:bp - 8] = fat_seg, 0 if invalid
		;  initialised to 0 by MS-DOS 6, 7, FreeDOS entrypoints
		;  fat_sector is not used for FAT12 !
		; wo [ss:bp - 12] = fat_sector, -1 if none (FAT16)
		; dwo [ss:bp - 12] = fat_sector, -1 if none (FAT32)
		;  initialised to -1 by MS-DOS 6, 7, FreeDOS entrypoints
		; wo [ss:bp - 16] = first_cluster (FAT16, FAT12)
		; dwo [ss:bp - 16] = first_cluster (FAT32)
		;  initialised to 0 by FreeDOS entrypoint
		;
		; Extension 1:
		; lsvExtra (word [ss:bp - 18]) may be set,
		;  not sure about interface yet. allows
		;  to not initialise data start, or to specify
		;  a partition number instead of offset
		;
		; Extension 2:
		; word [ss:bp - 20] = signature "CL" if valid
		; bp >= 20 + 256 if valid
		; 256bytes [ss:bp - 20 - 256] = ASCIZ command line string

	xor ax, ax
	push ax			; push into lsvExtra if sp -> LSV
%if _LSVEXTRA
	mov word [bp + lsvExtra], ax
		; byte [ss:bp - 18] = partition number
		; byte [ss:bp - 17] = flags for initialisation
%endif
	push ax			; push into lsvCommandLine if sp -> LSV

.ms7_common:
	mov ax, cs
	mov cx, word [bp + lsvLoadSeg]
	sub cx, ax
	jb error_notfullyloaded
	cmp cx, (end -$$+0) >> 4
	jae @F
error_notfullyloaded:
	call error
	db "Initial loader not fully loaded."
@@:

	mov bx, (payload.actual_end -$$+0 +15) >> 4
	cmp cx, bx
	jbe @F
	add bx, ax
	mov word [bp + lsvLoadSeg], bx
@@:

init_memory:
; Get conventional memory size and store it
		int 12h		; ax = amount KiB of Low Memory Area
		mov cl, 6
		shl ax, cl	; times 1024 divided by 16 (that is, times 64),
				;  ax => end of LMA
%if _RPL
	xor si, si
	xchg dx, ax		; dx => end of LMA
	mov ds, si		; => IVT
	lds si, [4 * 2Fh]	; -> int 2Fh handler
	add si, 3		; -> 3 bytes past int 2Fh handler
	lodsb			; don't use lodsw !
				;  could access the word at offset FFFFh
				;  which causes a fault in 386+ Real 86 Mode.
	cmp al, 'R'		; check "RPL" signature
	jne .no_rpl
	lodsb
	cmp al, 'P'
	jne .no_rpl
	lodsb
	cmp al, 'L'
	jne .no_rpl		; mismatch -->
	mov ax, 4A06h
	int 2Fh			; call RPL to adjust memory size
.no_rpl:
	xchg ax, dx
%endif
	push ax
	; sub ax, 32 >> 4	; make space for two MCBs: top MCB, RPL MCB
	dec ax
	dec ax
	mov cx, ax
	sub ax, (8192 + 16) >> 4
	dec cx		; => last paragraph of higher buffer (16-byte trailer)
	mov dx, ax	; => first paragraph of higher buffer
	mov bx, cx
	and dh, 0F0h	; 64 KiB chunk of first paragraph of higher buffer
	and bh, 0F0h	; 64 KiB chunk of last paragraph of higher buffer
	cmp bh, dh	; in same chunk?
	mov bx, ax
	je .gotsectorseg	; yes, use higher buffer as sector buffer ->
			; bx = use higher buffer as FAT buffer
	inc bx		; => 8 KiB buffer (no 16-byte trailer)
	sub ax, (8192 + 32) >> 4
			; 32 = leave space for higher buffer MCB + header
			; +16 from the above calcs for 16-byte trailer
	mov dx, ax	; use lower buffer as sector buffer
	jmp short .gotsegs

.gotsectorseg:
			; ax = use higher buffer as sector buffer
	sub bx, (8192 + 32) >> 4	; use lower buffer as FAT buffer
			; 32 = leave space for higher buffer MCB + header
	mov dx, bx
		; ax = sector seg
		; bx = FAT seg
		; dx = the lower of the two
.gotsegs:
	sub dx, (+_STACKSIZE -LOADCMDLINE + 512 + (ebpbNew - bpbNew) + 32 + 15) >> 4
			; +_STACKSIZE = stack space
			; -LOADCMDLINE = load cmd line + data + lsv space
			; 512 = boot sector (allows finding filename)
			; (ebpbNew - bpbNew) = additional space for BPBN moving
			; 32 = leave space for lower buffer MCB + header
		; dx = stack seg

	dec dx		; leave space for stack + BPB buffer MCB
	cmp dx, word [bp + lsvLoadSeg]
	jnb @F
.error_outofmemory:
	jmp error_outofmemory
@@:

	push ax
	mov si, ss
	mov ax, bp
	mov cl, 3
	add ax, 512 + 15
	jnc @F		; if no carry --> (NC)
			; CY
	mov ax, 0	; preserve CY ! do not use xor
@@:
	rcr ax, 1	; bit 16 in is CF
	shr ax, cl
	add si, ax
	cmp si, dx
	ja .error_outofmemory

		; note that the next conditional doesn't jump for lsvFATSeg = 0
	mov cx, word [bp + lsvFATSeg]
	add cx, (8192) >> 4
	cmp cx, dx
	ja .error_outofmemory
	pop ax

	inc dx		; => stack + BPB buffer
	 push ss
	 pop ds
	mov es, dx
	pop dx		; top of memory (=> start of RPL, EBDA, video memory)
	push es		; top of memory below buffers
	push ax		; => sector seg

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
	mov cx, (- lsvExtra + 512)
	rep movsb	; copy lsv (including lsvExtra) and BPB
			; byte move to avoid possibly crossing FFFFh boundary
	xor ax, ax
	mov cl, ((ebpbNew - bpbNew + 15) & ~15) >> 1
	rep stosw	; initialise area behind sector (left so for FAT32)
	pop ax
	pop cx
	mov ss, cx
	mov sp, _STACKSIZE
			; -> above end of stack space
	mov bp, _STACKSIZE - LOADCMDLINE
			; -> BPB, above end of lsv
	dec cx		; => space for stack + BPB buffer MCB
	sti

		; ax => sector buffer
		; bx => FAT buffer
		; cx => above end of memory available for load
		; dx => above end of memory used by us
	mov word [bp + ldMemoryTop], dx
	mov word [bp + ldLoadTop], cx
	mov word [bp + ldSectorSeg], ax

	mov ds, word [bp + lsvFATSeg]
	xor si, si	; ds:si -> FAT buffer
	mov es, bx
	xor di, di	; es:di -> where to move
	mov cx, 8192 >> 1
	rep movsw
	mov word [bp + lsvFATSeg], bx

	push ds		; to check for word [lsvFATSeg] == zero later on

	push ss
	pop es
	push ss
	pop ds

	mov bx, [bp + bsBPB + bpbSectorsPerFAT]
	test bx, bx
	jz .is_fat32

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
	; FSVersion, RootCluster, FSINFOSector, BackupSector, Reserved:
	;  uninitialised here (initialised by loaded_all later)
.is_fat32:
%if 1 || _QUERY_GEOMETRY || !_LBA_SKIP_CHECK
	call query_geometry
		; The ebpbNew BPBN needs to be initialised
		;  to use this function. It must be called
		;  before using read_sector (used by the FAT12
		;  FAT loader, or by finish_load later).
%endif

%if _LSVEXTRA || _MULTISECTOR || _ADDPROGRESS
	mov cx, cs
	mov ax, word [bp + lsvLoadSeg]
	sub ax, cx
%endif
%if _MULTISECTOR || _ADDPROGRESS
	cmp ax, (end2 + 15 - $$ + 0) >> 4
	jae init_memory_multi
multi_continue_1:
%endif

%if _LSVEXTRA
	test byte [bp + lsvExtra.flags], -1
	jz @F

	cmp ax, (end_of_handle_lsv_extra_flags + 15 -$$+0) >> 4
	jb error_notfullyloaded

	call handle_lsv_extra_flags
@@:
%endif

; adjusted sectors per cluster (store in a word,
;  and decode EDR-DOS's special value 0 meaning 256)
	mov al, [bp + bsBPB + bpbSectorsPerCluster]
	dec ax
	mov ah, 0
	inc ax
	mov [bp + ldClusterSize], ax

; 16-byte paragraphs per sector
	mov ax, [bp + bsBPB + bpbBytesPerSector]
	mov cl, 4
	shr ax, cl
	mov [bp + ldParaPerSector], ax

; total sectors
		; After the prior shr instruction, ax is < 8000h,
		;  so the following cwd always zeros dx.
	cwd
	mov ax, [bp + bsBPB + bpbTotalSectors]
	test ax, ax
	jnz @F
	mov dx, [bp + bsBPB + bpbTotalSectorsLarge + 2]
	mov ax, [bp + bsBPB + bpbTotalSectorsLarge]

		; fall through and let it overwrite the field with the
		; already current contents. saves a jump.
@@:
	mov [bp + bsBPB + bpbTotalSectorsLarge + 2], dx
	mov [bp + bsBPB + bpbTotalSectorsLarge], ax

	; dx:ax = total sectors

	pop cx			; => original lsvFATSeg
	cmp word [bp + bsBPB + bpbSectorsPerFAT], 0
	mov byte [bp + ldFATType], 32
	je .got_fat_type

	; dx:ax = total amount of sectors
	sub ax, word [bp + lsvDataStart]
	sbb dx, word [bp + lsvDataStart + 2]

	; dx:ax = total amount of data sectors
	xchg bx, ax		; bx = low word, clobber ax
	xchg ax, dx		; ax = high word, clobber dx
	xor dx, dx		; dx:ax = high word
	div word [bp + ldClusterSize]
	xchg bx, ax
	div word [bp + ldClusterSize]
	; bx:ax = quotient, dx = remainder
	; bx:ax = number of clusters
	test bx, bx
	jz @F
.badclusters:
	jmp error_badclusters

@@:
	cmp ax, 0FFF7h - 2
	ja .badclusters
	shr byte [bp + ldFATType], 1	; = 16
	cmp ax, 0FF7h - 2
	ja .got_fat_type

	mov byte [bp + ldFATType], 12
	test cx, cx
	jnz .got_fat12

; lsvFATSeg was zero! This means the FAT isn't loaded yet.

; Load the entire FAT into memory. This is easily feasible for FAT12,
;  as the FAT can only contain at most 4096 entries.
; (The exact condition should be "at most 4087 entries", or with a
;  specific FF7h semantic, "at most 4088 entries"; the more reliable
;  and portable alternative would be "at most 4080 entries".)
; Thus, no more than 6 KiB need to be read, even though the FAT size
;  as indicated by word[sectors_per_fat] could be much higher. The
;  first loop condition below is to correctly handle the latter case.
; (Sector size is assumed to be a power of two between 32 and 8192
;  bytes, inclusive. An 8 KiB buffer is necessary if the sector size
;  is 4 or 8 KiB, because reading the FAT can or will write to 8 KiB
;  of memory instead of only the relevant 6 KiB. This is always true
;  if the sector size is 8 KiB, and with 4 KiB sector size it is true
;  iff word[sectors_per_fat] is higher than one.)

			; If we're here, then ax <= 0FF5h (ja jumped if not),
			;  so this cwd always zeros dx.
		cwd			; dx = 0, prepare for dx:ax = FAT sector
	mov ax, cs
	add ax, (payload.actual_end -$$+0 +15) >> 4
	jc @F
	cmp word [bp + lsvLoadSeg], ax
	jae .got_fat12_zero
@@:
		mov di, 6 << 10		; maximum size of FAT12 to load
		mov cx, [bp + bsBPB + bpbSectorsPerFAT]
					; maximum size of this FS's FAT
		mov ax, [bp + bsBPB + bpbReservedSectors]
					; dx:ax = first FAT sector
		mov bx, [bp + lsvFATSeg]
%if _MULTISECTOR
multi_patch_2: equ $
	test ax, load_fat12_multi - @F
@@:
multi_continue_2: equ $
%endif
@@:
		call read_sector	; read next FAT sector
		sub di, [bp + bsBPB + bpbBytesPerSector]
					; di = bytes still left to read
		jbe @F			; if none -->
					; (jbe means jump if CF || ZF)
		loop @B			; if any FAT sector still remains -->
@@:					; one of the limits reached; FAT read

multi_continue_3: equ $
.got_fat12:
.got_fat_type:
	mov cx, word [bp + lsvFATSeg]

.got_fat12_zero:
	jmp finish_continue


%assign num 1024+512-($-$$)
%warning num bytes in front of end
	_fill 1024+512,38,start
end:

load_next_sect:
	cmp bx, [bp + ldLoadUntilSeg]
	jae loaded_all.2stack_j_NC

.multi_late_patch:	; patched to skipped_all.multipatch
	call read_sector
skipped_all_continue:
%if _MULTISECTOR || _ADDPROGRESS
	jmp loaded_32_byte
 %endif
skipped_all_continue_after_loaded_32_byte:
	loop load_next_sect
	jmp loadorskip_next_cluster

 %if _MULTISECTOR || _ADDPROGRESS
check_end3_loaded:
	push ax
	mov ax, cs
	neg ax		; minus cs
	add ax, bx	; loaded segment minus cs = how many paragraphs loaded
	cmp ax, paras(end3 + 15 -$$+0)
			; enough for end3 ?
	pop ax
	retn


loaded_32_byte:
	call check_end3_loaded
	jb skipped_all_continue_after_loaded_32_byte
			; not yet -->
%if ($ - end) > 32
 %error load_next part exceeds end+32
%endif
%assign num 32 - ($ - end)
	stc		; CY, fall through to loaded_all.2stack_or_multi_late
 %else
%if ($ - end) > 32
 %error load_next part exceeds end+32
%endif
%assign num 32 - ($ - end)
 %endif
%warning num bytes in front of end+32


		; if we fall through, end3 is fully loaded.
		; if we jump to here, then the whole file has
		;  been loaded, so this jump doesn't have to
		;  stay in the 32 bytes after the end label.
loaded_all.2stack_j_NC:
	jmp loaded_all.2stack_or_multi_late


ms7_entry.continue:
	cli
	cld
	pop bx
	pop ds
	pop word [bx]
	pop word [bx + 2]

	lea bx, [bp + lsvCommandLine]
	cmp sp, bx
	jbe @F
	mov sp, bx
@@:
	mov word [bp + lsvFirstCluster + 0], di
	mov word [bp + lsvFirstCluster + 2], si

	mov ax, word [bp + bsBPB + bpbHiddenSectors + 0]
	mov dx, word [bp + bsBPB + bpbHiddenSectors + 2]
	sub word [bp + lsvDataStart + 0], ax
	sbb word [bp + lsvDataStart + 2], dx

	mov ax, cs
	add ax, (4 * 512) >> 4	; MS7 entry has 4 sectors loaded
	xor cx, cx		; cx = 0
	jmp ms7_entry.continue2_set_extra_and_empty_cmdline


%if _MULTISECTOR || _ADDPROGRESS
		; INP:	ax = amount paragraphs already loaded
		; CHG:	bx, cx, dx, si, di, es
		; OUT:	patches applied
		;	branch to multi_continue_1
init_memory_multi:
%if _LBA && (!_LBA_MULTI) && (!_ADDPROGRESS)
 %if !_LBA_SKIP_CHECK
	test byte [bp + ldHasLBA], 1
	jnz .skip
 %else
  %error Multi-sector loader must use proper LBA check currently
 %endif
%endif

	push ax
	push ds

%if _CHS

%if _LBA && _LBA_MULTI || _ADDPROGRESS
	cmp ax, (end3 + 15 - $$ + 0) >> 4

	push cs
	pop ds
	mov al, 0E9h		; jmp near

	jae init_memory_multi_lba
.addprogressonly:
 %if !_LBA_SKIP_CHECK
	test byte [bp + ldHasLBA], 1
	jnz .ret
 %else
  %error Multi-sector loader must use proper LBA check currently
 %endif
.nolba:
%else
	push cs
	pop ds
	mov al, 0E9h		; jmp near
%endif
%if _MULTISECTOR
	mov byte [skipped_all.multipatch], al
	mov byte [multi_patch_2], al
%endif

%else		; _CHS

 %ifn _LBA && _LBA_MULTI
  %error Multi loader combination not permitted
 %endif
	cmp ax, (end3 + 15 - $$ + 0) >> 4
	jb .ret
	push cs
	pop ds
	mov al, 0E9h		; jmp near
	jmp init_memory_multi_lba
%endif		; _CHS

%if _MULTISECTOR && _CHS
	dec ax			; = 0E8h, call near
	mov byte [error.multi_patch], al

	xor ax, ax
	mov es, ax		; => IVT
	mov bx, 1Eh * 4		; es:bx -> int 1Eh in IVT
	lds si, [es:bx]		; -> DPT source
	mov word [cs:dpt_restore_ofs], si
	mov word [cs:dpt_restore_seg], ds
	mov di, 522h		; standard target for DPT
	mov word [es:bx], di
	mov word [es:bx + 2], es; -> our DPT
	mov cx, 16
	rep movsb		; copy it over
	mov byte [es:di - 16 + 4], 36
				; force sectors
%endif

.ret:
	pop ds
	pop ax
.skip:
.patch_late_multi:
	jmp multi_continue_1


%if _MULTISECTOR
		; INP:	bx => where to load FAT12
		;	dx:ax = first FAT sector
		;	cx = how many sectors at most
		;	di = amount bytes in 6 KiB
		; OUT:	branch to multi_continue_2
		;	 or branch to multi_continue_3
load_fat12_multi:
	; push di
	xor si, si
@@:
	inc si				; count sectors needed
	sub di, [bp + bsBPB + bpbBytesPerSector]
	ja @B				; if still di > bps, loop
	cmp cx, si
	jb @F
	mov cx, si			; cx = min(cx, si)
@@:
	call multi_sector_read		; bx => cx sectors from dx:ax
	; pop di
	jmp multi_continue_3

		; INP:	bx => where to load next sector
		;	dx:ax = next sector to load
		;	cx = how many sectors left in cluster, >= 1
		;	ldLoadUntilSeg => past end to load
		;	ldParaPerSector
		;	dword [ss:sp] = current cluster (0-based)
		; OUT:	branch to skipped_all.single_sector
		;	 or branch to loaded_all with stack cleaned
skipped_all_multi:
 %if _ADDPROGRESS
	mov byte [cs:multi_sector_read.patch_late_progress_init], 73h	; jae
		; REM:	Enables the late progress init branch within
		;	 multi_sector_read. Note that this code assumes
		;	 that bx => past the last loaded file part.
		;	For this reason, the branch must be enabled
		;	 only here, not earlier. The FAT12 load, if it
		;	 happens, also uses multi_sector_read and its
		;	 buffer is somewhere else / higher so during
		;	 the FAT12 load the late progress init branch
		;	 must be disabled still.
		;	The FAT16 and FAT32 load are not relevant to
		;	 this because they always directly call the
		;	 (single-sector) read_sector, so we know that
		;	 all calls to multi_sector_read after here are
		;	 loading actual file data.
 %endif
	push word [bp + ldmSector + 2]	; push into ldmCluster + 2
	push word [bp + ldmSector]	; push into ldmCluster

	mov word [bp + ldmSector + 2], dx
	mov word [bp + ldmSector], ax	; update sector

	xor di, di
	push bx
@@:
	inc di
	add bx, [bp + ldParaPerSector]
	cmp bx, [bp + ldLoadUntilSeg]
	jb @B				; di = how many sectors needed
	pop bx				; back to bx => segment
.loop:
	cmp cx, di
	jae .last

	pop ax
	pop dx				; current cluster (0-based)
	push dx
	push ax
	 push cx
	 push bx
	call clust_next			; dx:ax = next cluster (0-based)
	 pop bx
	 pop cx
	jnc .eoc
	add word [bp + ldmCluster], 1
	adc word [bp + ldmCluster + 2], 0
	cmp dx, word [bp + ldmCluster + 2]
	jne .newclust
	cmp ax, word [bp + ldmCluster]
	jne .newclust
	add cx, [bp + ldClusterSize]	; cx = how many at least consecutive
.next:
	jmp .loop

.newclust:
	add sp, 4			; discard ldmCluster
	push dx
	push ax				; push into ldmCluster
	mov dx, word [bp + ldmSector + 2]
	mov ax, word [bp + ldmSector]
	sub di, cx
	call multi_sector_read		; read consecutive data
	pop ax
	pop dx
	push dx
	push ax				; get ldmCluster
	 push bx
	call clust_to_first_sector	; dx:ax = first sector, cx = spc
	 pop bx
	mov word [bp + ldmSector], ax	; store for next first sector
	mov word [bp + ldmSector + 2], dx
	jmp .next

.last:
	mov cx, di			; how many sectors last chunk
	pop ax
	pop ax				; discard stack (ldmCluster)
	pop ax
	pop dx				; ldmSector
	call multi_sector_read		; si needn't be preserved, no longer used
	call restore_dpt
	clropt [bp + ldHasLBA], 2	; reset single-sector flag
	jmp loaded_all

.eoc:
	mov [bp + ldLoadingSeg], bx
	jmp end_of_chain		; to error_badchain or error_shortfile


restore_dpt:
%if _CHS
	xor bx, bx
	mov ds, bx
	mov bl, 1Eh * 4		; ds:bx -> int 1Eh vector
	mov word [bx], 0
dpt_restore_ofs equ $ - 2
	mov word [bx + 2], 0
dpt_restore_seg equ $ - 2
%endif
@@:				; used by multi_sector_read
	retn


		; INP:	dx:ax = start sector
		;	cx = how many sectors to load
		;	bx => segment to load to
		; OUT:	bx => after last data loaded
		; CHG:	es, si, dx, ax, cx
multi_sector_read:
.:
	jcxz @B
	push dx
	push ax				; stack = start sector
	xor si, si
	 push si			; 0 to do after
	 push cx			; all to do now

	mov es, bx			; => buffer
	mov si, bx			; => buffer
	and bx, 0F000h			; 64 KiB area of buffer
@@:
	add si, word [bp + ldParaPerSector]
					; => behind next sector buffer
	push si
	dec si				; => at last paragraph in this buffer
	and si, 0F000h			; 64 KiB area of last paragraph
	cmp bx, si			; same ?
	pop si
	loope @B			; loop if same --> and not last
	 pop si				; si = amount wanted --> (how much first)
	je .nolimit64			; if all same --> proceed with full
	inc cx				; cx = how many need to be deferred
	 pop bx				; discard the zero
	sub si, cx			; si = amount we can do maximum
	jnz .decrease64			; any ? then do them -->
.singlesector:
	mov bx, es			; restore => data
	call read_sector
	dec cx
		; cx = how many left
		; dx:ax = next sector
		; bx => next buffer
	pop si
	pop si				; discard sector number
.j:
%if _ADDPROGRESS
	call check_end3_loaded
.patch_late_progress_init:
dist equ late_progress_init_j - @F
	test al, dist
@@:
 %assign num dist
 %if num > 127
  %error Distance too long! num
 %endif
 %warning Distance is num
%endif
	jmp .				; loop back with updated sector/buffer


%if _CHS
.fallback:
%if 1
	cmp al, 1			; tried to load a single sector ?
	je .error			; yes, this is an error -->
%else
	testopt [bp + ldHasLBA], 2	; already in single-sector mode ?
	jnz .error			; yes, this is an error -->
%endif
	setopt [bp + ldHasLBA], 2	; set flag to force single-sector operation
	jmp .again
%endif

.error:
	jmp error_diskaccess


.decrease64:
	 push cx			; how many next
.nolimit64:	; si = how much first

%if _CHS
%if _LBA && _LBA_MULTI
.lbapatch:				; writes a near jump in 3 bytes
%endif
%else
	jmp multi_sector_read_lba
%endif

%if _CHS
; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[bp + bsBPB + bpbHiddenSectors + 0]
		adc dx,[bp + bsBPB + bpbHiddenSectors + 2]
	jc .error
%if _CHS_RETRY
	mov byte [cs:read_sector.dx_ax_cx_lba_to_chs_patch_E8], 0C3h
					; = 0E8h if to continue
					; = 0C3h if to return
%else
	mov byte [cs:read_sector.dx_ax_cx_lba_to_chs_patch_B8], 0C3h
					; = 0B8h if to continue
					; = 0C3h if to return
%endif
		; = 0B8h if to continue
		; = 0C3h if to return
	xchg cx, ax			; dx:cx = sector LBA number
	xchg dx, ax			; ax:cx = sector LBA number
	xor dx, dx			; dx:ax:cx
	call read_sector.dx_ax_cx_lba_to_chs
%if _CHS_RETRY
	mov byte [cs:read_sector.dx_ax_cx_lba_to_chs_patch_E8], 0E8h
					; = 0E8h if to continue
					; = 0C3h if to return
%else
	mov byte [cs:read_sector.dx_ax_cx_lba_to_chs_patch_B8], 0B8h
					; = 0B8h if to continue
					; = 0C3h if to return
%endif
; @boeckmann code follows
	mov ax, cx			; ax & 63 = S coordinate to read
	and ax, 63			; isolate S coordinate
	dec ax				; make it 0-based
	sub ax, word [bp + bsBPB + bpbCHSSectors]
					; S coordinate - amount of S
	neg ax				; amount of S - S coordinate
					;  = how many S in this C:H left
	push si
	cmp ax, si
	jb .limittrack
	xchg ax, si			; ax = remaining to read, si clobbered
.limittrack:
; end of @boeckmann code

.again:
	testopt [bp + ldHasLBA], 2
	jz @F
	mov al, 1			; force single-sector operation
@@:

%if _ADDPROGRESS
.patch_progress:
	test ax, read_progress_multi_chs - @F
@@:
%endif

	mov si, 4
.retry:
	mov ah, 02h			; function = read CHS sectors
	push ax
	int 13h
	pop ax				; preserve al = count
	jnc .got
	dec si				; count down retry count
	jz .fallback
	push ax
	xor ax, ax
	int 13h				; reset disk
	pop ax
	jmp .retry			; and retry -->
%endif

.got:
	pop si				; si = how many wanted this step
	cbw				; S must be <= 63 so al is too, ah = 0
					; from LBA al is <= 127, so ah = 0
	sub si, ax			; si = how many left over
	xchg cx, ax			; cx = how many have been read this step
	pop bx
	add bx, si			; bx = how many still to do
	pop ax
	pop dx				; dx:ax = start sector number
	add ax, cx
	adc dx, 0			; dx:ax = next start sector
	jc .error
	 push bx
	mov bx, es			; => input buffer
@@:
	add bx, word [bp + ldParaPerSector]
	loop @B				; => next buffer
	 pop cx				; cx = how many to do
	jmp .j				; loop back with updated sector/buffer
%endif
%endif


%assign num 2046-($-$$)
%if num >= 3
%assign num num - 3
 %warning %[num]+3 bytes in front of end2
late_progress_init_j:
	jmp late_progress_init
%else
late_progress_init_j: equ late_progress_init
 %warning num bytes in front of end2
%endif
	_fill 2046,38,start
	dw "MS"			; signature of MS-DOS 7 load
	align 16, db 38
end2:

%ifn _MULTISECTOR || _ADDPROGRESS
loaded_all.2stack_or_multi_late: equ loaded_all.2stack
%else

%if _MULTISECTOR
%if _ADDPROGRESS
late_progress_init:
	mov byte [cs:multi_sector_read.patch_late_progress_init], __TEST_IMM8
	mov byte [cs:read_sector.patch_progress], 0E8h
 %if _CHS
	mov byte [cs:multi_sector_read.patch_progress], 0E8h
 %endif
 	jmp multi_sector_read.
%endif
%endif

loaded_all.2stack_or_multi_late:
	jnc loaded_all.2stack

		; At least 1536 bytes were loaded initially,
		;  two sectors were read, and sector size
		;  is >= 512 bytes. Therefore, this code is
		;  safely usable if it stays below end2 + 512.
multi_late:
	mov byte [cs:init_memory_multi.patch_late_multi], 0C3h
				; retn
 %if _MULTISECTOR
	mov byte [cs:load_next_sect.multi_late_patch], 0E9h
				; jmp near
	mov word [cs:load_next_sect.multi_late_patch + 1], \
	 skipped_all.multipatch - (load_next_sect.multi_late_patch + 3)
				; continue with skipped_all_multi
		; This patch will work as intended even if
		;  init_memory_multi is to decide to not
		;  install its own patches at all. In this case
		;  skipped_all.multipatch isn't patched but
		;  rather runs a call read_sector then branches
		;  to skipped_all_continue again.
 %endif
	push di
	push si
	push ax
	push bx
	push cx
	push dx
	xchg ax, bx		; clobbers bx
	mov bx, cs
	sub ax, bx		; = amount paragraphs loaded
	call init_memory_multi	; set patches
	pop dx
	pop cx
	pop bx
	pop ax
	pop si
	pop di
	jmp skipped_all_continue_after_loaded_32_byte
				; back to the loop, will branch to multi
				;  loader on next read_sector intention.

%if ($ - $$) > 2048 + 512
 %error Late multi entrypoint not within end2+512
%endif
%endif

%if _MULTISECTOR && _LBA && _LBA_MULTI || _ADDPROGRESS
		; INP:	al = 0E9h
		;	ss:sp -> ds, ax
		;	cs = ds
		; CHG:	bx, cx, dx, si, di, es
		; OUT:	patches applied
		;	branch to multi_continue_1 / init_memory_multi.ret
		;	 or branch to init_memory_multi.nolba
init_memory_multi_lba:
%if _ADDPROGRESS
	mov byte [read_sector.patch_progress], 0E8h
 %if _CHS && _MULTISECTOR
	mov byte [multi_sector_read.patch_progress], 0E8h
 %endif
%endif

%if _MULTISECTOR && _LBA && _LBA_MULTI

%if _CHS
 %if !_LBA_SKIP_CHECK
	test byte [bp + ldHasLBA], 1
	jz init_memory_multi.nolba
 %else
  %error Multi-sector loader must use proper LBA check currently
 %endif
%endif
	mov byte [skipped_all.multipatch], al
	mov byte [multi_patch_2], al
%if _CHS
	mov byte [restore_dpt], 0C3h	; make this a no-op
	mov byte [multi_sector_read.lbapatch], al
					; jmp near
	mov word [multi_sector_read.lbapatch + 1], \
		multi_sector_read_lba - (multi_sector_read.lbapatch + 3)
%endif
	jmp init_memory_multi.ret
%else
	jmp init_memory_multi.addprogressonly
%endif

%if _MULTISECTOR && _LBA && _LBA_MULTI
		; INP:	dx:ax = start sector within partition
		;	es => buffer
		;	si = how many sectors at most in this step, >= 1
		;	stack -> how many sectors left for later (word),
		;	 start sector (dword),
		;	 near return address (word)
multi_sector_read_lba:
	mov bx, es
	push si
	cmp si, 127
	jbe @F
	mov si, 127
; LBA limit appears to be 127 sectors per call.
; refer to https://retrocomputing.stackexchange.com/questions/32124/whats-the-maximum-amount-of-sectors-an-lba-rom-bios-sector-read-call-can-access/
@@:

	push di
	mov di, si

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[bp + bsBPB + bpbHiddenSectors + 0]
		adc dx,[bp + bsBPB + bpbHiddenSectors + 2]

 %if (!_LBA_33_BIT) && _LBA_CHECK_NO_33
	jc .error
 %endif
 %if _LBA_33_BIT
	sbb si, si	; -1 if was CY, 0 else
	neg si		; 1 if was CY, 0 else
 %endif
	xor cx, cx	; cx = 0 (needed if jumping to .no_lba_checked)
	push cx
 %if _LBA_33_BIT
	push si		; bit 32 = 1 if operating in 33-bit space
 %else
	push cx		; second highest word = 0
 %endif
	push dx
	push ax		; qword sector number (lpSector)
	push bx
	push cx		; bx:0 -> buffer (lpBuffer)
	push di		; word number of sectors to read (lpCount)
	mov cl, 10h
	push cx		; word size of disk address packet (lpSize)
	mov si, sp	; ds:si -> disk address packet (on stack)

	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]

.lbaagain:
	testopt [bp + ldHasLBA], 2
	jz @F
	mov di, 1			; force single-sector operation
@@:

%if _ADDPROGRESS
	call read_progress_multi_lba
%endif

	mov cx, 4
	db __TEST_IMM16			; skip int
.lbaretry:
	int 13h
	mov word [si + lpCount], di	; reset for subsequent attempts
	mov ah, 42h			; 13.42 extensions read
	int 13h
	jnc .lbagot
	xor ax, ax			; reset disk
	loop .lbaretry			; count down retry count
.lbafallback:
 %if 1
	cmp di, 1			; tried to load a single sector ?
	je .error			; yes, this is an error -->
 %else
	testopt [bp + ldHasLBA], 2	; already in single-sector mode ?
	jnz .error			; yes, this is an error -->
 %endif
	setopt [bp + ldHasLBA], 2	; set flag to force single-sector operation
	jmp .lbaagain

.lbagot:
	xchg ax, di			; al = how many read
	add sp, word [si + lpSize]
	pop di				; restore di
	jmp multi_sector_read.got

.error:
	jmp multi_sector_read.error
%endif
%endif


%if _ADDPROGRESS
read_progress_multi_lba:
	push ax
	mov al, '&'
	jmp @F

read_progress_multi_chs:
	push ax
	mov al, '.'
	jmp @F

read_progress_single:
	push ax
	mov al, '+'
@@:
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
	int 10h
	pop bp
	pop bx
	pop ax
	retn
%endif


%if _MULTISECTOR || _ADDPROGRESS
%assign num 4096-($-$$)
%warning num bytes in front of end3
%if num < 0
 %warning LBA multi-sector loader is overflowing end3
%endif
end3:
%endif


		; This handling is in the second header part,
		;  behind the needed part to finish loading.
		;  It is only used when the file is completely loaded.
loaded_all.2stack:
	pop ax
	pop ax
loaded_all:
	mov ax, word [bp + bsBPB + bpbSectorsPerFAT]
	test ax, ax
	jz .fat32

	xor ax, ax
	push ss
	pop es
	lea di, [bp + bsBPB + ebpbFSFlags]
	mov cx, (EBPB_size - ebpbFSFlags) / 2
	rep stosw
		; initialise ebpbFSFlags (reinit), ebpbFSVersion,
		;  ebpbRootCluster, ebpbFSINFOSector, ebpbBackupSector,
		;  ebpbReserved

.fat32:

%if _QUERY_PATCH
	mov ax, word [cs:..@query_patch_site]
%else
	mov ax, _QUERY_DEFAULT
%endif
	mov word [bp + ldQueryPatchValue], ax

%if _CHECKSUM
        push cs
        pop ds

 %if _QUERY_PATCH
	mov word [..@query_patch_site], _QUERY_DEFAULT
 %endif

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

        test bx, bx
        jnz error_header_checksum_failed

        testopt [..@checksumtype], 8000h
        jnz @F

        call checksum_crc16_6_paragraphs_start_cs
        int3

        push cs
        pop ds

        cmp ax, word [..@checksumfield]
	jne error_data_checksum_failed
..@data_checksum_ignore_failure_debugger:
@@:
%endif

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


%if _CHECKSUM
error_header_checksum_failed:
	call error
	db "Header checksum failed."

error_data_checksum_failed:
	stc
	int3
	jnc ..@data_checksum_ignore_failure_debugger
	call error
	db "Data checksum failed."
%endif


freedos_or_msdos1_com_entry:
	cld
	call @F
@@:
	pop cx
	cmp cx, @B
	jne msdos1_com_entry

freedos_entry:
		; This is the FreeDOS compatible entry point.
		;  Supports FAT32 too.
		; cs:ip = 60h:0 (or 70h:0 for EDR-DOS entry)
		; whole load file loaded
		; first cluster of load file: not given!
		; first data sector: not given!
		; int 1Eh not modified, original address: not given!
		; bl = load unit (or dl for EDR-DOS entry) (not used by us)
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
	jnz .error		; maybe not -->
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


d3	call d3_display_two_characters
d3	test ax, "F0"

	xor cx, cx
	mov word [bp + lsvFirstCluster + 0], cx
	mov word [bp + lsvFirstCluster + 2], cx

%if _LSVEXTRA
	mov word [bp + lsvExtra], lsvefNoDataStart << 8
%else
	call calculate_data_start
%endif
.multiboot_entry:
	mov ax, cs
	add ax, (payload.actual_end -$$+0 +15) >> 4
				; Multiboot1/2 and FreeDOS have whole image
	xor cx, cx		; cx = 0
	jmp ms7_entry.continue2


.error:
	call error
	db "Invalid base pointer in FreeDOS entrypoint."


%if _LSVEXTRA
handle_lsv_extra_flags:
	test byte [bp + lsvExtra.flags], lsvefPartitionNumber
	jz @F
	call parse_partition_number
@@:
	test byte [bp + lsvExtra.flags], lsvefNoDataStart
	jz @F
	call calculate_data_start
@@:
	retn


parse_partition_number:
	xor ax, ax
	mov word [bp + bsBPB + bpbHiddenSectors], ax
	mov word [bp + bsBPB + bpbHiddenSectors + 2], ax
	cmp byte [bp + bsBPB + ebpbNew + bpbnBootUnit], -1
	jne @F
	mov byte [bp + bsBPB + ebpbNew + bpbnBootUnit], 80h
	mov word [bp + bsBPB + bpbCHSSectors], ax
	mov word [bp + bsBPB + bpbCHSHeads], ax
	call query_geometry
@@:

 %if !_LBA_SKIP_CHECK
	test byte [bp + ldHasLBA], 1
	jnz @F
 %endif

	mov ax, word [bp + bsBPB + bpbCHSSectors]
	mov dx, word [bp + bsBPB + bpbCHSHeads]

		; following is from lDebug 0c0930773929 boot.asm
	overridedef DEBUG5, 0
%define load_unit (bp + bsBPB + ebpbNew + bpbnBootUnit)
%define load_sectorsize (bp + bsBPB + bpbBytesPerSector)
%define load_sectorsizepara (bp + ldParaPerSector)

	test ax, ax
	jz .invalid_sectors
	cmp ax, 63
	ja .invalid_sectors
	test dx, dx
	jz .invalid_heads
	cmp dx, 100h
	ja .invalid_heads
@@:

	mov ax, word [bp + ldSectorSeg]	; ax => sector seg
	dec ax				; ax => sector seg - 16
	mov es, ax
	xor ax, ax
	mov bx, 16

d5	call d5dumpregs
d5	call d5message
d5	asciz 13,10,"In query_geometry 0",13,10

	mov di, bx
	mov cx, (8192 + 2) >> 1
					; es:bx -> auxbuff, es:di = same
	rep stosw			; fill buffer, di -> behind (auxbuff+8192+2)
	mov ax, 0201h			; read sector, 1 sector
	inc cx				; sector 1 (1-based!), cylinder 0 (0-based)
	mov dh, 0			; head 0 (0-based)
	mov dl, [load_unit]
	stc
	call .int13_retry
	jc .access_error

	std				; _AMD_ERRATUM_109_WORKAROUND does not apply
	mov word [es:bx - 2], 5E5Eh	; may overwrite last 2 bytes at line_out_end
	scasw				; -> auxbuff+8192 (at last word to sca)
d5	call d5dumpregs
d5	call d5message
d5	asciz 13,10,"In query_geometry 1",13,10
	mov cx, (8192 + 2) >> 1
	xor ax, ax
	repe scasw
	add di, 4			; di -> first differing byte (from top)
	cld
	push di

	mov di, bx
	mov cx, (8192 + 2) >> 1
	dec ax				; = FFFFh
	rep stosw

	mov ax, 0201h
	inc cx
	mov dh, 0
	mov dl, [load_unit]
	stc
	call .int13_retry
	jc .access_error

	std				; _AMD_ERRATUM_109_WORKAROUND does not apply
	scasw				; di -> auxbuff+8192 (last word to sca)
d5	call d5dumpregs
d5	call d5message
d5	asciz 13,10,"In query_geometry 2",13,10
	pop dx
	mov ax, -1
	mov cx, (8192 + 2) >> 1
	repe scasw
%if 0
AAAB
   ^
	sca B, match
  ^
	sca B, mismatch
 ^
	stop
%endif
	add di, 4			; di -> first differing byte (from top)
	cld

%if 0
0000000000000
AAAAAAAA00000
	^
FFFFFFFFFFFFF
AAAAAAAA00FFF
	  ^
%endif
	cmp dx, di			; choose the higher one
	jae @F
	mov dx, di
@@:
	sub dx, bx			; dx = sector size

d5	call d5dumpregs
d5	call d5message
d5	asciz 13,10,"In query_geometry 3",13,10

	cmp dx, 8192 + 2
	jae .sector_too_large
	mov ax, 32
	cmp dx, ax
	jb .sector_too_small
@@:
	cmp dx, ax
	je .got_match
	cmp ax, 8192
	jae .sector_not_power
	shl ax, 1
	jmp @B

.got_match:
	mov word [load_sectorsize], ax
	mov cl, 4
	shr ax, cl
	mov word [load_sectorsizepara], ax

	resetdef


	push cs
	pop ds
	push cs
	pop es

	mov cx, .per_partition
	call scan_partitions

	mov di, partition_offset
	mov dx, word [di + 2]
	mov ax, word [di]

	cmp ax, -1
	jne @F
	cmp dx, -1
	jne @F

	push ss
	pop es
	mov di, bp
	xor ax, ax
	mov cx, 512 / 2 + (((ebpbNew - bpbNew + 15) & ~15) >> 1)
	push word [bp + bsBPB + ebpbNew + bpbnBootUnit]
	push word [bp + bsBPB + bpbCHSSectors]
	push word [bp + bsBPB + bpbCHSHeads]
	rep stosw
	pop word [bp + bsBPB + bpbCHSHeads]
	pop word [bp + bsBPB + bpbCHSSectors]
	pop bx
	mov byte [bp + bsBPB + ebpbNew + bpbnBootUnit], bl
	mov word [bp + bsBPB + bpbHiddenSectors], dx
	mov word [bp + bsBPB + bpbHiddenSectors + 2], dx

	jmp .invalid_return


@@:
	push dx
	push ax
	mov bx, [bp + ldSectorSeg]
	call read_ae_512_bytes
	push es
	pop ds
	xor si, si
	push ss
	pop es
	mov di, bp
	mov cx, 512 / 2

	pop ax
	pop dx

	push word [bp + bsBPB + ebpbNew + bpbnBootUnit]
	push word [bp + bsBPB + bpbCHSSectors]
	push word [bp + bsBPB + bpbCHSHeads]


	rep movsw

	push ax
	xor ax, ax
	mov cx, ((ebpbNew - bpbNew + 15) & ~15) >> 1
	rep stosw	; initialise area behind sector (left so for FAT32)
	pop ax


	pop word [bp + bsBPB + bpbCHSHeads]
	pop word [bp + bsBPB + bpbCHSSectors]
	mov word [bp + bsBPB + bpbHiddenSectors], ax
	mov word [bp + bsBPB + bpbHiddenSectors + 2], dx


	push ss
	pop ds
	push ss
	pop es

	mov bx, [bp + bsBPB + bpbSectorsPerFAT]
	test bx, bx
	jz .not_fat32

	lea si, [bp + 510]			; -> last source word
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
	; FSVersion, RootCluster, FSINFOSector, BackupSector, Reserved:
	;  uninitialised here (initialised by loaded_all later)
.not_fat32:

	pop bx
	mov byte [bp + bsBPB + ebpbNew + bpbnBootUnit], bl

	mov ah, lsvefNoDataStart
	mov al, byte [cs:partition_type]
	cmp al, ptFAT12
	je @F
	cmp al, ptFAT16_16BIT_CHS
	je @F
	cmp al, ptFAT16_CHS
	je @F
	cmp al, ptFAT32_CHS
	je @F
	cmp al, ptFAT32
	je @F
	cmp al, ptFAT16
	je @F

.invalid_return:
	xor ax, ax
	mov word [bp + lsvDataStart], ax
	mov word [bp + lsvDataStart + 2], ax
@@:
	mov byte [bp + lsvExtra.flags], ah

%if _CHECKSUM
	push cs
	pop es
	mov di, scanparttab_variables_start
	mov cx, scanparttab_variables_length_w
	xor ax, ax
	rep stosw	; clear variables for eventual checksum
	dec ax
	mov di, partition_offset
	stosw
	stosw		; reset this variable too
%endif

	push ss
	pop es
	push ss
	pop ds
	retn


.per_partition:
	push cx
	push si
	push di
	push bx

	mov ax, [es:si + piStart]
	mov dx, [es:si + piStart + 2]
	add ax, [ss:bx + di - 8]
	adc dx, [ss:bx + di - 8 + 2]	; = partition start

	mov cx, -1
	mov di, partition_offset
	cmp word [di], cx		; first one encountered ?
	jne @F
	cmp word [di + 2], cx
	jne @F				; no -->
	mov cl, byte [es:si + piType]
	mov byte [di - partition_offset + partition_type], cl
					; save type
	mov word [di], ax
	mov word [di + 2], dx		; yes, save offset
@@:

	mov cl, byte [load_current_partition]
					; which one ?
	cmp cl, byte [bp + lsvExtra.partition]
	jne @F				; not the sought one

	mov cl, byte [es:si + piType]
	mov byte [di - partition_offset + partition_type], cl
					; save type
	mov word [di], ax
	mov word [di + 2], dx		; save offset

	pop bx				; bx = base
	mov sp, bx			; reset sp
	pop ax				; pop dummy bp
	retn				; return to caller

@@:					; not yet found, continue
	pop bx
	pop di
	pop si
	pop cx
	retn


.int13_retry:
	pushf
	push ax
	int 13h		; first try
	jnc @F		; NC, success on first attempt -->

; reset drive
	xor ax, ax
	int 13h
	jc @F		; CY, reset failed, error in ah -->

; try read again
	pop ax		; restore function number
	popf
	int 13h		; retry, CF error status, ah error number
	retn

@@:			; NC or CY, stack has function number
	inc sp
	inc sp
	inc sp
	inc sp		; discard two words on stack, preserve CF
	retn


.access_error:
	jmp error_diskaccess

.sector_too_large:
.sector_too_small:
.sector_not_power:
	call error
	db "Invalid sector size."

.invalid_sectors:
.invalid_heads:
	call error
	db "Invalid geometry."

scan_logical.got_partition_cycle:
	call error
	db "Partition cycle detected."

scan_logical.error_too_many_partitions:
	call error
	db "Too many partitions detected."

read_partition_table.signature_fail:
	call error
	db "Invalid partition table detected."


		; INP:	dx:ax = first sector
		;	bx:0 -> buffer
		; OUT:	dx:ax = sector number after last read
		;	es = input bx
		;	bx:0 -> buffer after last written
		; CHG:	-
read_ae_512_bytes:
	push ds
	push cx
	push bx
	 push ss
	 pop ds
	mov cx, 512
.loop:
	call read_sector
	sub cx, word [bp + bsBPB + bpbBytesPerSector]
	ja .loop
	pop es
	pop cx
	pop ds
	retn


%assign _PARTITION_TABLE_IN_CS 1
%assign _BOOTCMD_FAIL_ERROR 0
%define _SCANPTAB_PREFIX
%define _SCANPTAB_DEBUG4_PREFIX
	overridedef DEBUG4, 0
%include "scanptab.asm"
	resetdef


	align 16
scanparttab_variables_start:
partition_table:
	times 16 * 4 db 0
.end:

partition_offset:
	dd -1

load_partition_cycle:
	dw 0
load_current_partition:
	db 0
partition_type:
	db 0

	align 2
scanparttab_variables_length_w: equ ($ - scanparttab_variables_start) / 2
%endif


		; INP:	ss:bp -> BPB
		;	ss:bp - LOADSTACKVARS -> lsv
		; OUT:	lsvDataStart set
		; CHG:	ax, bx, cx, dx, si, di
calculate_data_start:
	xor cx, cx			; ! ch = 0

		; Although this currently is unused, we calculate the
		;  first data sector (including root directory size)
		;  here to complete the LOADSTACKVARS.

; 32-byte FAT directory entries per sector
	mov ax, [bp + bsBPB + bpbBytesPerSector]
	mov cl, 5			; ! ch = 0
	shr ax, cl

; number of sectors used for root directory (store in CX)
		; After the prior shr instruction, ax is always < 8000h,
		;  so this cwd instruction always zeros dx.
	cwd
	mov si, [bp + bsBPB + bpbNumRootDirEnts]	; (0 iff FAT32)
	mov bx, ax
	dec ax				; rounding up
	js .error_badchain		; if >= 8000h (ie, 0FFFFh while bx = 0)
	add ax, si			; from BPB
	adc dx, dx			; account for overflow (dx was zero)
	div bx				; get number of root sectors
	xchg ax, cx			; cx = number of root secs, ! ah = 0

	push cx				; number of root secs
; first sector of root directory
	mov al, [bp + bsBPB + bpbNumFATs]
					; ! ah = 0, hence ax = number of FATs
	mov cx, word [bp + bsBPB + bpbSectorsPerFAT]
	xor di, di			; di:cx = sectors per FAT
					;  iff FAT12, FAT16
	test cx, cx			; is FAT32 ?
	jnz @F				; no -->
	mov cx, word [bp + bsBPB + ebpbSectorsPerFATLarge]
	mov di, word [bp + bsBPB + ebpbSectorsPerFATLarge + 2]	; for FAT32
@@:
	push ax
	mul cx
		; ax = low word SpF*nF
		; dx = high word
	xchg bx, ax
	xchg cx, dx
		; cx:bx = first mul
	pop ax
	mul di
		; ax = high word adjust
		; dx = third word
	test dx, dx
	jnz .error_badchain
	xchg dx, ax
		; dx = high word adjust
	add dx, cx
		; dx:bx = result
	xchg ax, bx
		; dx:ax = result
	jc .error_badchain

	add ax, [bp + bsBPB + bpbReservedSectors]
	adc dx, byte 0
	jc .error_badchain

	pop cx				; number of root sectors
	xor di, di

; first sector of disk data area:
	add cx, ax
	adc di, dx
	mov [bp + lsvDataStart], cx
	mov [bp + lsvDataStart + 2], di

	retn

.error_badchain:
	jmp error_badchain


end_of_handle_lsv_extra_flags:


%if _CHECKSUM
CHECKSUM_SIZE_P equ (payload.actual_end - $$ + 0) / 16

	overridedef STANDALONE, 0
 %include "inicheck.asm"
	resetdef

        align 16
checksumheader:
        istruc CHECKSUMHEADER
at cshSignature,                dw "CS"
at cshLengthBytesStructure,     dw CHECKSUMHEADER_size
at cshOffsetStructure,          dw paras(checksumheader - $$ + 0)
at cshChecksumStructure,        dw \
        10000h-(("CS" + CHECKSUMHEADER_size \
                 + paras(checksumheader - $$ + 0) \
                 + 8106h + CHECKSUM_SIZE_P \
                 + 0 + 0) & 0FFFFh)
at cshTypeChecksum
..@checksumtype:                dw 8106h
at cshAmountParagraphsData,     dw CHECKSUM_SIZE_P
at cshChecksumData
..@checksumfield:               dw 0
at cshReserved,                 dw 0
        iend
%endif

%if _MULTIBOOT1 || _MULTIBOOT2
 %include "multboot.asm"
%endif


%if _DEBUG3
		; INP:	word [cs:ip + 1] = two characters to display
		;		(second one may be NUL to skip)
		; OUT:	-
		; CHG:	-
d3_display_two_characters:
	lframe near
	lenter
	push ax
	push bx
	mov bx, word [bp + ?frame_ip]
	mov ax, [cs:bx + 1]

	push ax
	call d3_disp_al
	pop ax

	xchg al, ah
	test al, al
	jz @F

	call d3_disp_al
@@:

	pop bx
	pop ax
	lleave
	lret

		; INP:	al = to display
		; CHG:	ax, bx
d3_disp_al:
	push bp
	mov ah, 0Eh
	mov bx, 7
	int 10h
	pop bp
	retn
%endif


msdos1_com_entry:
	mov dx, .msg + 100h
	mov ah, 09h
	int 21h
	int 20h

.msg:
	ascic "86-DOS version 1 not supported, aborting.",13,10


	align 16, db 38
payload:
	incbin _PAYLOAD_FILE
	align 16, db 38
.actual_end:
%if _IMAGE_EXE
	align 512, db 38	; until end of page
.trail:
%ifnidn _EXE_TRAIL_INCBIN, ""
	incbin _EXE_TRAIL_INCBIN
%endif
	_fill 512, 38, .trail	; a full additional page,
				; this is for the bogus exeExtraBytes
		; Note that the pages start counting within the EXE header!
		; Thus alignment to the file-level page boundary is correct.
%endif
.end:

%assign num payload - $$
%warning num bytes before iniload payload


%if _SECOND_PAYLOAD_EXE
	align 16, db 38
second_payload:
	incbin _SECOND_PAYLOAD_FILE
	align 16, db 38
.actual_end:
	align 512, db 38
.trail:
%ifnidn _EXE_TRAIL_INCBIN, ""
	incbin _EXE_TRAIL_INCBIN
%endif
	_fill 512, 38, .trail
.end:
%endif

%if ($ - start) < 4096
	_fill 4096, 38, start	; fill to new minimum limit
%endif

%if _PADDING
 %if ($ - $$) > _PADDING
  %warning No padding needed
 %else
	times _PADDING - ($ - $$) db 0
 %endif
%endif

end_of_file:
%if _EDRDOS
 %if (70h + paras(end_of_file - $$)) < 800h
  %error Too small payload to detect EDR-DOS entrypoint
 %endif
%endif
