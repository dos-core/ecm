
%if 0

Loader adjustment to load next kernel (do nothing)
 by C. Masloch, 2023

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

	strdef PAYLOAD_FILE,	"lDOSLOAD.BIN"


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
	push cs			; => our image
	push ax
	push bx			; -> start of RELOCATE
	retf

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
	pop ax			; => image start
	mov es, ax
	mov ds, ax
	push ax
	push bx			; -> image start
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
	retf			; execute payload (at +0:0)
