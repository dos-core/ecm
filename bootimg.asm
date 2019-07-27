%if 0

Create a boot image file (default: 1440 KiB diskette) in NASM
 2019, by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

	defaulting

	numdef SPI, 2880
	numdef BPS, 512
	numdef SPC, 1
	numdef SPF, 9
	numdef BPE, 12
	numdef NUMFATS, 2
	numdef NUMROOT, 224
	numdef NUMRESERVED, 1
	numdef MEDIAID, 0F0h
	numdef EOF, 15

	numdef UNIT, 0
	numdef CHS_SECTORS, 18
	numdef CHS_HEADS, 2
	numdef HIDDEN, 0

	strdef BOOTFILE, "boot12.bin"
	strdef SINGLEPAYLOADFILE, ""

	strdef OEM_NAME,	"    lDOS"
	strdef OEM_NAME_FILL,	'_'
	strdef DEFAULT_LABEL,	"NO NAME"


%ifidn _SINGLEPAYLOADFILE, ""
 %ifndef _MULTIPAYLOADFILE
  %error No payload files specified!
 %endif
%endif


%if _BPE == 12
%elif _BPE == 16
%elif _BPE == 32
%else
 %error Invalid BPE (_BPE)
%endif

%if _BPE != 32
 %assign ROOTSECTORS (_NUMROOT * 32 + _BPS - 1) / _BPS
%else
 %assign ROOTSECTORS 0
%endif
%assign FATSECTORS _NUMFATS * _SPF
%assign DATASECTORS (_SPI - _NUMRESERVED - FATSECTORS - ROOTSECTORS)
%assign DATACLUSTERS (DATASECTORS / _SPC)
%assign NUMENTRIES _SPF * _BPS * 8 / _BPE
%if NUMENTRIES < (DATACLUSTERS + 2)
 %error Too few FAT sectors specified
%endif
%if NUMENTRIES > 0FF0h
 %if _BPE == 12
  %error FAT would be detected as FAT16
 %endif
%endif
%if NUMENTRIES < 1000h
 %if _BPE == 16
  %error FAT would be detected as FAT12
 %endif
%endif


%if _EOF < 8 || _EOF > 15
 %error Invalid EOF value (_EOF)
%endif

%if _BPE != 32
 %assign MAXENTRY (1 << _BPE) - 1
%else
 %assign MAXENTRY (1 << 28) - 1
%endif
%assign EOFSTARTENTRY MAXENTRY - 7
%assign EOFENDENTRY MAXENTRY
%assign BADENTRY MAXENTRY - 8
%assign EOFENTRY MAXENTRY - 15 + _EOF


	struc DIRENTRY
deName:		resb 8
deExt:		resb 3
deAttrib:	resb 1
		resb 8
deClusterHigh:	resw 1
deTime:		resw 1
deDate:		resw 1
deClusterLow:	resw 1
deSize:		resd 1
	endstruc

ATTR_READONLY	equ 1
ATTR_HIDDEN	equ 2
ATTR_SYSTEM	equ 4
ATTR_VOLLABEL	equ 8
ATTR_DIRECTORY	equ 10h
ATTR_ARCHIVE	equ 20h


	addsection boot, start=0 vstart=7C00h
boot_start:
%ifnidn _BOOTFILE, ""
	incbin _BOOTFILE
%else
	jmp strict short boot_after_bpb
	nop

oem_id:			; offset 03h (03) - not used by this code
	fill 8,_OEM_NAME_FILL,db _OEM_NAME
bytes_per_sector:	; offset 0Bh (11)
	dw _BPS
sectors_per_cluster:	; offset 0Dh (13)
	db _SPC
num_reserved_sectors:	; offset 0Eh (14)
	dw _NUMRESERVED
num_fats:		; offset 10h (16)
	db _NUMFATS
num_root_dir_ents:	; offset 11h (17)
%if _BPE != 32
	dw _NUMROOT
%else
	dw 0
%endif
total_sectors:		; offset 13h (19) - not used by this code
%if _SPI < 1_0000h
	dw _SPI		; (= 2880)
%else
	dw 0
%endif
media_id:		; offset 15h (21) - not used by this code
	db _MEDIAID
sectors_per_fat:	; offset 16h (22)
%if _BPE != 32
	dw _SPF
%else
	dw 0
%endif
sectors_per_track:	; offset 18h (24)
	dw _CHS_SECTORS
heads:			; offset 1Ah (26)
	dw _CHS_HEADS
hidden_sectors:		; offset 1Ch (28)
	dd _HIDDEN
total_sectors_large:	; offset 20h (32) - not used by this code
	dd _SPI

; Extended BPB		; offset 24h (36)

%if _BPE == 32
sectors_per_fat_large:	; offset 24h (36)
	dd _SPF
fsflags:		; offset 28h (40)
	dw 0
fsversion:		; offset 2Ah (42)
	dw 0
root_cluster:		; offset 2Ch (44)
	dd rootcluster
fsinfo_sector:		; offset 30h (48)
	dw 0
backup_sector:		; offset 32h (50)
	dw 0

	times 12 db 0	; offset 34h (52) reserved

; Extended BPB		; offset 40h (64)
%endif

boot_unit:		db _UNIT
			db 0
ext_bpb_signature:	db 29h
serial_number:		dd 0
volume_label:		fill 11,32,db _DEFAULT_LABEL
filesystem_identifier:
%if _BPE == 12
	fill 8,32,db "FAT12"
%elif _BPE == 16
	fill 8,32,db "FAT16"
%elif _BPE == 32
	fill 8,32,db "FAT32"
%else
 %error Invalid BPE
%endif


boot_after_bpb:
	cli
	cld
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov sp, 7C00h
	sti
	mov si, boot_message
@@:
	lodsb
	test al, al
	jz @F
	mov ah, 0Eh
	mov bh, [462h]
	mov bl, 7
	int 10h
	jmp @B

@@:
	xor ax, ax
	int 13h
	xor ax, ax
	int 16h
	int 19h

boot_message:
	db "Unable to boot, loader not written.",13,10
	db 13,10
	db "Press any key to reboot.",13,10
	db 0

	times 508 - ($ - $$) db 0
	dw 0
	dw 0AA55h
%endif
boot_end:

%if (boot_end - boot_start) != 512
 %error Boot file has wrong size
%endif
	align _BPS

	times (_NUMRESERVED * _BPS) - ($ - $$) db 0


	%macro addfatentry 1.nolist
%xdefine FATENTRIES FATENTRIES,(%1)
	%endmacro


	addsection fat, follows=boot align=_BPS

%assign FATENTRIES (_MEDIAID | (MAXENTRY - 15))
	addfatentry EOFENTRY

%if _BPE != 32
	addsection root, follows=fat align=_BPS
	addsection data, follows=root vstart=0 align=_BPS
%else
	addsection data, follows=fat vstart=0 align=_BPS
data_start:
	addsection root, follows=data align=_BPS
root_start:
	addsection empty, follows=root vstart=0 align=_BPS
%endif
	sectalign off


	%macro incfile 1.nolist
	usesection data
%%start:
incbin %1
%assign filesize ($ - %%start)
	align _BPS * _SPC
%assign clusters ($ - %%start) / (_BPS * _SPC)

%if clusters == 0
 %assign cluster 0
%else
	assigncluster FATENTRIES
 %assign ii 1
 %rep clusters - 1
	addfatentry cluster + ii
 %assign ii ii + 1
 %endrep
	addfatentry EOFENTRY
%endif

%define string %1
%strlen length string
%assign ii 1
%rep length
 %substr cc string length - ii + 1
 %ifidn cc,"/"
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %ifidn cc,"\"
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %assign ii ii + 1
%endrep
%strlen length string
%assign ii 1
%define name ""
%define ext ""
%assign dotyet 0
%rep length
 %substr cc string ii
 %assign ii ii + 1
 %if cc >= 'a' && cc <= 'z'
  %substr cc "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (cc - 'a' + 1)
 %endif
 %ifn dotyet
  %ifidn cc,"."
   %assign dotyet 1
  %else
   %strlen ll name
   %if ll >= 8
    %error Too long name part in %1
    %exitrep
   %endif
   checkchar %1,cc
   %strcat name name,cc
  %endif
 %else
  %strlen ll ext
  %if ll >= 3
   %error Too long ext part in %1
   %exitrep
  %else
   checkchar %1,cc,"."
   %strcat ext ext,cc
  %endif
 %endif
%endrep
%ifidn name,""
 %error Invalid empty name part in %1
%endif

	usesection root
	istruc DIRENTRY
at deName,		fill 8,32,db name
at deExt,		fill 3,32,db ext
at deClusterHigh,	dw cluster >> 16
at deClusterLow,	dw cluster & 0FFFFh
at deSize,		dd filesize
	iend
	%endmacro

	%macro assigncluster 2-*.nolist
%assign cluster %0
	%endmacro

	%macro checkchar 2-3.nolist 0
%if %2 <= ' ' || %2 >= 128 || \
	%2 == '/' || %2 == '\' || \
	%2 == '"' || %2 == "'" || \
	%2 == %3
 %error Invalid character (%2) in name (%1)
%endif
	%endmacro


%ifnidn _SINGLEPAYLOADFILE, ""
	incfile _SINGLEPAYLOADFILE
%elifnidn _MULTIPAYLOADFILE, ""
	%macro multiincfile 1-*.nolist
%rep %0
	incfile %1
 %rotate 1
%endrep
	%endmacro
	multiincfile _MULTIPAYLOADFILE
%endif

%if _BPE != 32
	usesection root
	times ROOTSECTORS * _BPS - ($ - $$) db 0

	usesection data
	times DATASECTORS * _BPS - ($ - $$) db 0
%else
	usesection data
	align _BPS * _SPC
data_end:
%push
	usesection root
	times 32 db 0
		; Insure at least one entry. Makes things
		;  easier to handle for the loader too.
	align _BPS * _SPC
root_end:
%assign clusters ($ - root_start) / (_BPS * _SPC)

%if clusters == 0
 %error Internal error in root writer
%else
	assigncluster FATENTRIES
rootcluster equ cluster
 %assign ii 1
 %rep clusters - 1
	addfatentry cluster + ii
 %assign ii ii + 1
 %endrep
	addfatentry EOFENTRY
%endif

	usesection empty
	times DATASECTORS * _BPS \
		- (data_end - data_start) \
		- (root_end - root_start) \
		db 0
%endif

%if _BPE == 32
 %define dumpfatentries dd
%elif _BPE == 16
 %define dumpfatentries dw
%elif _BPE == 12
	%macro dumpfatentries 2-*.nolist
%if (%0 & 1) == 1
 %error Expected even number of entries
%endif
%rep %0 / 2
	db (%1) & 0FFh
	db ((%1) >> 8) \
		| (((%2) & 0Fh) << 4)
	db ((%2) >> 4)
 %rotate 2
%endrep
	%endmacro
%else
 %error Invalid bits per entry (_BPE)
%endif

	assigncluster FATENTRIES
%if _BPE == 12 && (cluster & 1) == 1
	addfatentry 0
%endif

	usesection fat
%assign ii 0
%rep _NUMFATS
fat%[ii]:
	dumpfatentries FATENTRIES
	times _SPF * _BPS - ($ - fat%[ii]) db 0
%assign ii ii+1
%endrep
%if FATSECTORS * _BPS - ($ - $$)
 %error Internal error in FAT filling
%endif
