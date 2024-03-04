
%if 0

Loader adjustment to checksum and load next kernel
 by E. C. Masloch, 2023

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

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


	defaulting

	strdef PAYLOAD_FILE,	"lDOSLOAD.BIN"

	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0
	numdef IMAGE_EXE,	0

	numdef IMAGE_EXE_CS,	-16	; relative-segment for CS
	numdef IMAGE_EXE_IP,	256 +64	; value for IP
		; The next two are only used if _IMAGE_EXE_AUTO_STACK is 0.
	numdef IMAGE_EXE_SS,	-16	; relative-segment for SS
	numdef IMAGE_EXE_SP,	0FFFEh	; value for SP (0 underflows)
	numdef IMAGE_EXE_AUTO_STACK,	0, 2048	; use stack behind image
		; _IMAGE_EXE_AUTO_STACK here differs from iniload's def of
		;  the same name. This one is only used as a flag; if non-zero,
		;  keep the stack given to us by iniload; if zero, set up the
		;  stack specified by _IMAGE_EXE_SS and _IMAGE_EXE_SP.
	numdef DEVICE,			0
	gendef DEVICE_NAME,		""
	numdef DEVICE_ATTRIBUTE,	8000h
	numdef DEVICE_ZERO_ENTRYPOINT,	0

	strdef INILOAD_CFG, ""
%ifnidn _INILOAD_CFG, ""
 %include _INILOAD_CFG
%endif

%if _DEVICE
 %ifidn _DEVICE_NAME, ""
  %error Device name must be set
 %endif
%endif

%include "inicheck.mac"


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

%if _DEVICE || _IMAGE_EXE
init0_start:
%if _DEVICE
		; The device header is of a fixed format.
		;  For our purposes, the 4-byte code for
		;  each the strategy entry and the
		;  interrupt entry is part of this format.
		; (DOS may read the attributes or entrypoint
		;  offsets before calling either, so in the inicomp
		;  stage we need to recreate in the entrypoints part
		;  exactly what the application has here.)
device_header:
.next:
 %if _DEVICE_ZERO_ENTRYPOINT
	fill 2, -1, jmp strict short j_zero_entrypoint
	dw -1
 %else
	dd -1				; link to next device
 %endif
.attributes:
	dw _DEVICE_ATTRIBUTE		; attributes
.strategy:
	dw .strategy_entry		; -> strategy entry
.interrupt:
	dw .interrupt_entry		; -> interrupt entry
.name:
	fill 8, 32, db _DEVICE_NAME	; character device name,
					;  or block device number of units
					;  + optional name
.strategy_entry:
	fill 4, 90h, jmp device_entrypoint
.interrupt_entry:
	fill 4, 90h, retf
%endif


	nop
	align 32, nop
init0_kernel_entry:
		; cs:ip = load seg : 32 here
%if ($ - $$) != 32
 %error Wrong kernel mode entrypoint
%endif
%if ! _IMAGE_EXE
j_zero_entrypoint:
%endif
	xor bx, bx		; 0 = kernel mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov si, cs
	jmp init0_common


%if _DEVICE
device_entrypoint:
	cmp byte [es:bx + 2], 0		; command code 0 (init) ?
	je device_entry_init

	mov word [es:bx + 3], 8103h	; error, done, code: unknown command
	retf
%endif


 %if _IMAGE_EXE
	align 64, nop
j_zero_entrypoint:
init0_exe_entry:
		; NOTE:	This part is called with ip = 256 + 64, cs = PSP.
%if ($ - $$) != 64
 %error Wrong EXE mode entrypoint
%endif
	mov bx, 1		; EXE mode
	push ax
	mov ax, cs
	add ax, (256 + (init0_end - init0_start)) >> 4	; => source
	mov si, cs
	add si, 256 >> 4	; => destination
 %endif

init0_common:
		; REM:	This part must be position-independent, as it is
		;	 called either with ip = init0_common (kernel mode
		;	 or device mode)
		;	 or ip = init0_common + 256 (application mode).
		; INP:	si => depack destination
		;	ax => source of payload + RELOCATE
		;	bx = mode (0 kernel, 1 application, 2 device)
	cld
	add ax, payload_size_p
	xor di, di
	push si			; => our image
	push ax
	push di			; -> start of RELOCATE
	retf


%if _DEVICE
device_entry_init:
	or word [cs:device_header.next], -1
	push cs
	push word [cs:device_header.strategy]
					; -> far return to payload's strategy
	push bp
	push ds
	push si
	push di
	push dx
	push cx
	push ax
	push bx
	push es

.have_some_memory:
	mov bx, 2		; device mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov si, cs		; => destination
	jmp init0_common
%endif

	align 16
init0_end:

%else
	mov ax, cs
	add ax, entry_size_p + payload_size_p
	xor bx, bx
	push cs			; => our image
	push ax
	push bx			; -> start of RELOCATE
	retf
%endif

	align 16
	endarea entry


	addsection PAYLOAD, follows=ENTRY
payload_start:

payload_first:			; first slice (including FD kernel CONFIG)
				; This goes at the start of our image.
	incbin _PAYLOAD_FILE, 0, 256
	align 16, db 38
	endarea payload_first

payload_third:			; third slice (does not need to be relocated)
	incbin _PAYLOAD_FILE, 256 + entry_size
	align 16, db 38
	endarea payload_third

payload_second:			; second slice
				; This goes between the first slice target and
				;  the position of the third slice.
	incbin _PAYLOAD_FILE, 256, entry_size
	align 16, db 38
	endarea payload_second


payload_size equ payload_first_size + payload_third_size + payload_second_size
	endarea payload, 1


	addsection RELOCATE, follows=PAYLOAD vstart=0
relocate:

		; Protocol for _DEVICE || _IMAGE_EXE entry:
		; INP:	ss:sp -> word => image start,
		;		word = old ax
		;	if kernel mode:
		;	 ss:bp -> LOADDATA and LOADSTACKVARS
		;	 ss:sp + 4 -> valid stack above [bp + ldLoadTop]
		;	any mode:
		;	 word [ss:sp + 2] = value for ax
		;	 bx = 2 if device mode, 1 if EXE mode, 0 if kernel mode
		;	 if EXE mode:
		;	  ss:sp + 4 -> valid stack above RELOCATE
		;	  bp = unset
		;	 if device mode:
		;	  ss:sp + 4 -> device entrypoint stack
		;	  holds: es, bx, ax, cx, dx, di, si, ds, bp,
		;		  far address of payload strategy entrypoint,
		;		  far return address to DOS
		;	  bp = unset
		; STT:	UP
		; CHG:	ax, bx, cx, dx, es, ds, si, di

		; Protocol otherwise:
		; INP:	ss:sp -> word => image start
		;	bx = 0
		;	ss:bp -> LOADDATA and LOADSTACKVARS
		;	ss:sp + 2 -> valid stack above [bp + ldLoadTop]
		; STT:	UP
		; CHG:	ax, bx, cx, dx, es, ds, si, di

	pop ax			; => image start

	push ax
	push bp
	push bx

	mov bp, ax

	mov si, checksumheader
	mov cx, CHECKSUMHEADER_size / 2
	xor bx, bx
@@:
	cmp si, ..@checksumfield_relocate_cs
	 cs lodsw
	jne @F
	 xor ax, ax
@@:
	add bx, ax
	loop @BB

	test bx, bx
	jnz error_header_checksum_failed

	testopt [cs:..@checksumtype_relocate_cs], 8000h
	jnz @F

	add bp, paras(entry_size + payload_third - payload_start)
	lea di, [bp + \
		(paras(payload_third_size + \
		payload_second_size + \
		checksumheader - relocate) & 0F000h)]
	call checksum_crc16_6_paragraphs_start_bp_skip_di
	int3

	cmp ax, word [cs:..@checksumfield_relocate_cs]
	jne error_data_checksum_failed
..@data_checksum_ignore_failure_debugger:
@@:

	pop bx
	pop bp
	pop ax

	mov es, ax
	mov ds, ax

	push ax
%if ! (_DEVICE || _IMAGE_EXE) && _EXEC_OFFSET == 0 && _EXEC_SEGMENT == 0
	push bx			; -> image start
%endif
	xor di, di		; -> image start
	mov si, entry_size	; -> first slice
	mov cx, payload_first_size_w
				; size of first slice
	rep movsw		; place first slice
	add ax, paras(entry_size + payload_second - payload_start)
	mov ds, ax		; => second slice
	xor si, si		; -> second slice
	mov cx, payload_second_size_w
				; size of second slice
	rep movsw		; place second slice
				; cx = 0
%if ! (_DEVICE || _IMAGE_EXE) && _EXEC_OFFSET == 0 && _EXEC_SEGMENT == 0
	retf			; execute payload (at +0:0)
%else

	pop si
	pop ax

%if _DEVICE
	test bl, 2
	jz .jmp_exe_or_kernel_mode

.jmp_device_mode:
	mov ds, si
	or word [device_header.next], -1
	pop es
	pop bx
	pop ax
	pop cx
	pop dx
	pop di
	pop si
	pop ds
	pop bp
	retf			; transfer to payload strategy entrypoint
				; still on stack: far return address to DOS

.jmp_exe_or_kernel_mode:
%endif

%if _IMAGE_EXE
	test bl, 1
	jz .jmp_kernel_mode

.jmp_exe_mode:
%if ! _IMAGE_EXE_AUTO_STACK
	mov cx, cs
	lea dx, [si + _IMAGE_EXE_SS]
	push dx			; stack = relocated ss value
	add dx, (_IMAGE_EXE_SP + 2 + 15) >> 4
	cmp cx, dx		; INIT1 code is above intended stack ?
	jae @F			; yes -->

.exe_error:
	push cs
	pop ds
	mov dx, bx
	mov si, msg.stackerror
	call disp_error

	mov ax, 4C7Fh
	int 21h

@@:
	cli
	pop ss			; = relocated ss value
	mov sp, (_IMAGE_EXE_SP + 2) & 0FFFFh	; change stack
	sti

	xor cx, cx
%endif

	push cx			; put zero on top of stack

%if _IMAGE_EXE_IP < 256
	mov cl, _IMAGE_EXE_IP
%elif (_IMAGE_EXE_IP & 255) == 0
	mov ch, _IMAGE_EXE_IP >> 8
%else
	mov cx, _IMAGE_EXE_IP
%endif

%if _IMAGE_EXE_CS == -16
	add si, -16
	mov ds, si
	mov es, si
%else
	lea dx, [si - 10h]	; => PSP
	mov ds, dx
	mov es, dx		; ds = es => PSP
	add si, _IMAGE_EXE_CS	; = relocated cs value
%endif
	push si
	push cx
	retf			; jump to EXE mode of image

%endif
.jmp_kernel_mode:
%if _EXEC_SEGMENT
	add si, _EXEC_SEGMENT
%endif
	push si
%if _EXEC_OFFSET
	mov si, _EXEC_OFFSET
	push si
%else
	push cx
%endif
	retf

%endif


%if 1 || _IMAGE_EXE && ! _IMAGE_EXE_AUTO_STACK
disp_error.loop:
	push ax
	push bx
	push bp
	mov ah, 0Eh
	mov bx, 7
%if _IMAGE_EXE || _DEVICE
	push dx

	test dl, 1 | 2
	jz .display_kernel_mode

	xchg dx, ax				; dl = input al
	mov ah, 02h
	int 21h
	db __TEST_IMM16				; (skip int)

.display_kernel_mode:
%endif
	int 10h
%if _IMAGE_EXE
	pop dx
%endif
	pop bp
	pop bx
	pop ax
disp_error:
	lodsb
	test al, al
	jnz .loop
	retn
%endif

%if _IMAGE_EXE && ! _IMAGE_EXE_AUTO_STACK
msg:
.stackerror:
		db "Load error: Out of stack memory.",13,10,0
%endif

error_header_checksum_failed:
	call error
	db "Header checksum failed.", 0

error_data_checksum_failed:
	stc
	int3
	jnc ..@data_checksum_ignore_failure_debugger
	call error
	db "Data checksum failed.", 0

msg.error:	db "Load error: ", 0


error:
	push cs
	pop ds
	pop si			; -> specific error message
	pop dx
	push dx			; get mode in dx
	push si			; stack -> error message
	mov si, msg.error
	call disp_error		; display prefix
	pop si
	call disp_error		; display ours

	pop bx			; = mode
	pop bp
	pop ax

%if _DEVICE
	test bl, 2
	jz .exit_app_or_kernel

	pop si				; => device segment
	pop ax				; original ax

	pop es
	pop bx
	mov word [es:bx + 3], 8103h	; set error, done, invalid command
	mov byte [es:bx + 13], 0	; set number of units = 0
	mov word [es:bx + 14 + 2], si
	and word [es:bx + 14], 0	; -> after end of memory to allocate
	pop ax
	pop cx
	pop dx
	pop di
	pop si
	pop ds
	pop bp
	add sp, 4		; discard far return to payload's strategy
	retf			; return to DOS


.exit_app_or_kernel:
%endif

%if _IMAGE_EXE
	test bl, 1
	jz .exit_kernel_mode

	mov ax, 4C7Fh
	int 21h

.exit_kernel_mode:
%endif
	xor ax, ax
	int 16h
	int 19h


CHECKSUM_SIZE_P equ paras(payload_third_size + payload_second_size + relocate_size)

	overridedef BP_DI_INPUT, 1
	overridedef STANDALONE, 0
 %include "inicheck.asm"
	resetdef
	resetdef

	align 16
checksumheader:
	istruc CHECKSUMHEADER
at cshSignature,		dw "CS"
at cshLengthBytesStructure,	dw CHECKSUMHEADER_size
at cshOffsetStructure,		dw paras(checksumheader - $$ + 0 + \
					payload_third_size + \
					payload_second_size)
at cshChecksumStructure,	dw \
	10000h-(("CS" + CHECKSUMHEADER_size \
		+  paras(checksumheader - $$ + 0 + \
					payload_third_size + \
					payload_second_size) \
		 + 8106h + CHECKSUM_SIZE_P \
		 + 0 + 0) & 0FFFFh)
at cshTypeChecksum
..@checksumtype_relocate_cs:	dw 8106h
at cshAmountParagraphsData,	dw CHECKSUM_SIZE_P
at cshChecksumData
..@checksumfield equ ($ - relocate + \
		payload_third_size + \
		payload_second_size \
		) & 0FFFFh
..@checksumfield_relocate_cs:	dw 0
at cshReserved,			dw 0
	iend

	align 16
	endarea relocate
