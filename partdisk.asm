
%if 0

Create a partitioned disk image file
 2025, by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif

%if 0

_PAYLOAD must be defined to a list of keywords and parameters.
The keywords and parameters are separated by commas.

Keywords are accepted only as (non-string) tokens. The available
keywords are:

::primary	Followed by active byte, size, type, image file
Creates a primary partition in current slot.

::extended	Followed by size, type
Creates an extended partition in current slot.

::logical	Followed by size, type, image file
Creates a logical partition in current slot.

::up		No parameters follow.
Finishes writing the current extended partition.

::slot		Followed by slot number (0 to 4)
Sets up a specific slot for next partition. It must be unused.
The default at the beginning and after any partition has been
created is slot 0, which scans for the first unused entry in
the current partition table.


=== Examples

# Create small file system images with labels in EBPB new,
# labels in the root directory, and two files each identifying
# the partition:

for label in hdd5 hdd6 hdc5 hdc6 hdc7 hdb1 hdb4 hdb5 hdb6 \
  hda1_ccc hda2_ddd hda5_fff hda4_eee hda6_ggg hda7_hhh
do
  echo "$label" > "$label.id"
  nasm -I ../lmacros/ bootimg.asm \
    -D_PAYLOADFILE=::empty,::label,"'${label^^}'","$label.id",::rename,"$label.id",part.id \
    -D_SPC=1 -D_BPE=16 -D_SPI=38000 -D_SPF=148 -D_ALIGNDATA \
    -D_NUMROOT=512 -D_CHS_HEADS=255 -D_CHS_SECTORS=63 \
    -D_UNIT=80h -D_MEDIAID=0F8h -D_DEFAULT_LABEL="'${label^^}'" \
    -o "$label.prt" -D_FULL=0
done

# Create an image with multiple primary and nested logical partitions:

nasm -I ../lmacros/ partdisk.asm -o partdisk.img \
  -D_PAYLOAD=::primary,80h,20M,fat16_chs,hda1_ccc.prt,\
::primary,0,20M,fat16_chs,hda2_ddd.prt,\
::extended,41M,extended_chs,::logical,20M,fat16_chs,hda5_fff.prt,\
::extended,max,extended_chs,::logical,20M,fat16_chs,hda6_ggg.prt,\
::up,::up,::primary,0,20M,fat16_chs,hda4_eee.prt \
  -D_MBR_DOSEMU_IMAGE_HEADER

# Create an image with two extended partition chains, one
# of type 5 and one of type 15:

nasm -I ../lmacros/ partdisk.asm -o partdis2.img \
  -D_PAYLOAD=::slot,4,::primary,80h,20M,fat16_chs,hdb4.prt,\
::primary,0,20M,fat16_chs,hdb1.prt,\
::slot,3,::extended,21M,extended_chs,::logical,20M,fat16_chs,hdb5.prt,\
::up,::extended,21M,extended,::logical,20M,fat16_chs,hdb6.prt,::up \
  -D_MBR_DOSEMU_IMAGE_HEADER

# Create an image with multiple type 5 extended partition chains
# and multiple logical partitions in the same EPBR:

nasm -I ../lmacros/ partdisk.asm -o partdis3.img \
  -D_PAYLOAD=::extended,41M,extended_chs,\
::logical,20M,fat16_chs,hdc5.prt,\
::logical,20M,fat16_chs,hdc6.prt,::up,\
::extended,21M,extended_chs,::logical,20M,fat16_chs,hdc7.prt,::up \
  -D_MBR_DOSEMU_IMAGE_HEADER

# Create an image with a nested extended partition hidden behind
# an empty extended partition in the same EPBR:

nasm -I ../lmacros/ partdisk.asm -o partdis4.img \
  -D_PAYLOAD=::extended,41M,extended_chs,\
::logical,20M,fat16_chs,hdd5.prt,\
::extended,1Ki,extended_chs,::up,\
::extended,max,extended_chs,::logical,20M,fat16_chs,hdd6.prt,::up,::up \
  -D_MBR_DOSEMU_IMAGE_HEADER

%endif


%include "lmacros3.mac"

	defaulting
	sectalign off

	numdef BPS, 512		; bytes per sector
	numdef CHS_SECTORS, 63	; CHS geometry field for sectors
	numdef CHS_HEADS, 16	; CHS geometry field for heads
		; qemu doesn't support more than 16 heads well.

	gendef PAYLOAD, ""
	gendef MAP, ""

	strdef MBRPATCHFILE, ""
	strdef MBRCODEFILE, ""
	numdef MBR_DOSEMU_IMAGE_HEADER,	0

	numdef ZEROBYTES_RESB,		1
	numdef ZEROBYTES_MAX,		4000_0000h
		; Using the resb trick to zero takes about 1/40th
		;  the time of using times (for a 512 MiB image).
%if _ZEROBYTES_RESB
	%imacro zerobytes 1.nolist
%if %1 < 0
 %error Negative count given to zerobytes
%else
[warning -zeroing]
[warning -other]
 %rep (%1) / (_ZEROBYTES_MAX)
	resb (_ZEROBYTES_MAX)
 %endrep
	resb (%1) % (_ZEROBYTES_MAX)
[warning *other]
[warning *zeroing]
%endif
	%endmacro
%else
	%imacro zerobytes 1.nolist
%if %1 < 0
 %error Negative count given to zerobytes
%else
 %rep (%1) / (_ZEROBYTES_MAX)
	times (_ZEROBYTES_MAX) db 0
 %endrep
	times (%1) % (_ZEROBYTES_MAX) db 0
%endif
	%endmacro
%endif


	numdef FILLBYTES_MAX,		4000_0000h
	%imacro fillbytes 2.nolist
%ifn %2
	zerobytes %1
%else
 %rep (%1) / (_FILLBYTES_MAX)
	times (_FILLBYTES_MAX) db %2
 %endrep
	times (%1) % (_FILLBYTES_MAX) db %2
%endif
	%endmacro


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

%imacro typedef 2.nolist
 %xdefine _%1 %2
 %ifidni _%1,	fat12
  %assign _%1	ptFAT12
 %elifidni _%1,	fat16_16bit_chs
  %assign _%1	ptFAT16_16BIT_CHS
 %elifidni _%1,	fat16_chs
  %assign _%1	ptFAT16_CHS
 %elifidni _%1,	fat32_chs
  %assign _%1	ptFAT32_CHS
 %elifidni _%1,	fat32
  %assign _%1	ptFAT32
 %elifidni _%1,	fat16
  %assign _%1	ptFAT16
 %endif
 %assign _%1 _%1
 %ifnnum _%1
  %error Invalid data partition type specified
 %endif
 %if _%1 == 0 || _%1 > 255 || _%1 == 5 || _%1 == 15 || _%1 == 85h
  %error Invalid data partition type specified
 %endif
%endmacro

%imacro exttypedef 2.nolist
 %xdefine _%1 %2
 %ifidni _%1,	extended_chs
  %assign _%1	ptExtendedCHS
 %elifidni _%1,	extended
  %assign _%1	ptExtended
 %elifidni _%1,	extended_linux
  %assign _%1	ptExtendedLinux
 %endif
 %assign _%1 _%1
 %ifnnum _%1
  %error Invalid extended partition type specified
 %endif
 %ifn _%1 == 5 || _%1 == 15 || _%1 == 85h
  %error Invalid extended partition type specified
 %endif
%endmacro

%ifnidn _MAP, ""
 [map all _MAP]
%endif

%ifidn _PAYLOAD, ""
 %fatal No payload specified!
%endif


	struc PARTINFO_CHS_TUPLE
pictHead:		resb 1
pictSectorLow6:
pictCylinderHigh2:	resb 1
pictCylinderLow8:	resb 1
	endstruc

	%macro chs_tuple 1.nolist
%assign %%sector (%1) % _CHS_SECTORS
%assign %%i (%1) / _CHS_SECTORS
%assign %%head %%i % _CHS_HEADS
%assign %%cylinder %%i / _CHS_HEADS
%if %%cylinder >= 1024
 %assign %%cylinder 1023
%endif
		istruc PARTINFO_CHS_TUPLE
at pictHead,		db %%head
at pictSectorLow6
at pictCylinderHigh2,	db (%%sector + 1) | ((%%cylinder >> (8 - 6)) & 0C0h)
at pictCylinderLow8,	db (%%cylinder & 0FFh)
		iend
	%endmacro

	struc PARTINFO
piBoot:		resb 1
piStartCHS:	resb 3		; PARTINFO_CHS_TUPLE
piType:		resb 1
piEndCHS:	resb 3		; PARTINFO_CHS_TUPLE
piStart:	resd 1
piLength:	resd 1
	endstruc

	struc DOSEMU_IMAGE_HEADER
; This structure is parsed when determining the geometry for
;  a hard disk image. It is documented in the dosemu2 sources at:
; https://github.com/dosemu2/dosemu2/blob/f41c0f267fec/src/include/disks.h#L132
dihSig:		resb 7		; "DOSEMU",0 or 0Eh,"DEXE"
dihCHSHeads:	resd 1		; (note the misalignment for these)
dihCHSSectors:	resd 1
dihCHSCylinders:resd 1
dihHeaderSize:	resd 1
dihDummy:	resb 1
dihDEXEFlags:	resd 1
	endstruc
dih_our_size:	equ 8192	; (16 * 512)


%define STARTSFOLLOWS start=0

 %if _MBR_DOSEMU_IMAGE_HEADER
	addsection dosemu_image_header, STARTSFOLLOWS
  %define STARTSFOLLOWS follows=dosemu_image_header
	istruc DOSEMU_IMAGE_HEADER
at dihSig,		asciz "DOSEMU"
at dihCHSHeads,		dd _CHS_HEADS
at dihCHSSectors,	dd _CHS_SECTORS
at dihCHSCylinders,	dd CYLINDERS
at dihHeaderSize,	dd dih_our_size
	iend
	times dih_our_size - ($ - $$) db 0
 %endif


	addsection mbr, STARTSFOLLOWS vstart=7C00h
 %define STARTSFOLLOWS follows=mbr

mbr_start:
 %ifnidn _MBRPATCHFILE, ""
	incbin _MBRPATCHFILE, 0, 512 - 2 - 4 * 16
 %elifnidn _MBRCODEFILE, ""
	incbin _MBRCODEFILE
 %else
	cli
	cld
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov sp, 7C00h
	sti
	mov si, mbr_message
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

mbr_message:
	db "Unable to boot, MBR loader not written.",13,10
	db 13,10
	db "Press any key to reboot.",13,10
	db 0
 %endif


	%imacro parttableentry 0-6
	istruc PARTINFO
 %if %0
%%startchs equ %2
%%endchs equ %4
at piBoot,	db %1
at piStartCHS
		chs_tuple %%startchs
at piType,	db %3
at piEndCHS
		chs_tuple %%endchs
at piStart,	dd %5
at piLength,	dd %6
 %endif
	iend
	%endmacro

%imacro sizedef 2.nolist
 %assign _%1 0
 %defstr %%string %2
 %strlen %%length %%string
 %substr %%three %%string %%length - 2, -1
 %substr %%two %%string %%length - 1, -1
 %substr %%one %%string %%length, -1
 %ifidni %%three, "KiB"
  %substr %%number %%string 1, -4
  %assign %%multiplier 1024
 %elifidni %%three, "MiB"
  %substr %%number %%string 1, -4
  %assign %%multiplier 1024 * 1024
 %elifidni %%three, "GiB"
  %substr %%number %%string 1, -4
  %assign %%multiplier 1024 * 1024 * 1024
 %elifidni %%two, "Ki"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1024
 %elifidni %%two, "Mi"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1024 * 1024
 %elifidni %%two, "Gi"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1024 * 1024 * 1024
 %elifidni %%two, "kB"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1000
 %elifidni %%two, "MB"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1000 * 1000
 %elifidni %%two, "GB"
  %substr %%number %%string 1, -3
  %assign %%multiplier 1000 * 1000 * 1000
 %elifidni %%one, "k"
  %substr %%number %%string 1, -2
  %assign %%multiplier 1000
 %elifidni %%one, "M"
  %substr %%number %%string 1, -2
  %assign %%multiplier 1000 * 1000
 %elifidni %%one, "G"
  %substr %%number %%string 1, -2
  %assign %%multiplier 1000 * 1000 * 1000
 %else
  %define %%number %%string
  %assign %%multiplier 1
 %endif
 %deftok %%token %%number
 %assign _%1 %%token * %%multiplier
%endmacro


%imacro chooseslot 0.nolist
  %ifn slot
   %ifempty %$entry1
    %assign slot 1
   %elifempty %$entry2
    %assign slot 2
   %elifempty %$entry3
    %assign slot 3
   %elifempty %$entry4
    %assign slot 4
   %else
    %fatal No free partition table entry
   %endif
  %endif
  %if slot > 4 || slot == 0
   %fatal Invalid Slot number
  %endif
  %ifnempty %$entry%[slot]
   %fatal Specified partition table entry is already in use
  %endif
%endmacro


%macro fillslot 0.nolist
 %if slot == 1
  %xdefine %$entry1 ENTRY
 %elif slot == 2
  %xdefine %$entry2 ENTRY
 %elif slot == 3
  %xdefine %$entry3 ENTRY
 %elif slot == 4
  %xdefine %$entry4 ENTRY
 %else
  %fatal Internal error, wrong Slot
 %endif
%endmacro


%imacro choosesize 1-2.nolist 0
 %ifidni %1, MAX
  %if %2
   %assign _?SIZE %$END - %$START
  %else
   %fatal Maximum not available for MBR
  %endif
 %elifidni %1, MAXIMUM
  %if %2
   %assign _?SIZE %$END - %$START
  %else
   %fatal Maximum not available for MBR
  %endif
 %else
	sizedef ?SIZE, %1
  %assign _?SIZE (_?SIZE + _BPS - 1) / _BPS
  %assign _?SIZE (%$START + _?SIZE + _CHS_HEADS * _CHS_SECTORS - 1)
  %assign %%modulo _?SIZE % (_CHS_HEADS * _CHS_SECTORS)
  %if %%modulo
   %assign _?SIZE _?SIZE - %%modulo
  %endif
  %assign _?SIZE _?SIZE - %$START
 %endif
 %if %2
  %if _?SIZE > (%$END - %$START)
   %assign _?MAX %$END - %$START
   %fatal Given size _?SIZE exceeds extended partition end %$END, maximum _?MAX
  %endif
 %endif
%endmacro


%macro dumptable 2
usesection %1

parttableentry %$entry1
parttableentry %$entry2
parttableentry %$entry3
parttableentry %$entry4

%if (512 - 2) - ($ - $$)
 %fatal Wrong %2 layout
%endif
	dw 0AA55h

%ifidni %2, EPBR
 addsection GAP%[COUNT], STARTSFOLLOWS
 %xdefine STARTSFOLLOWS follows=GAP%[COUNT]
 %xdefine LIST LIST, GAP%[COUNT],,%$END - %$START
 %assign COUNT COUNT + 1
%endif
%endmacro


%macro multi 1-*
%push MBR

usesection mbr
	times (512 - 2 - 4 * 16) - ($ - $$) db 0
mbr_partition_table:

%define %$entry1
%define %$entry2
%define %$entry3
%define %$entry4
%assign %$START _CHS_SECTORS
%assign %$thisisextended 0
%assign %$outermostextended 0

%xdefine LIST mbr,,%$START
%assign COUNT 1

%define isprimary 0
%define islogical 0
%define isextended 0
%define isslot 0
%define slot 0
%rep %0
 %if isprimary == 1
  %ifnctx MBR
   %fatal Primary partition not supported outside MBR
  %endif
  %assign primaryactive %1
  %assign isprimary 2
 %elif isprimary == 2
  choosesize %1, 0
  %assign isprimary 3
 %elif isprimary == 3
	typedef ?TYPE, %1
  %assign isprimary 4
 %elif isprimary == 4
  %xdefine file %1
  chooseslot
  %xdefine ENTRY \
	primaryactive, %$START, _?TYPE, %$START + _?SIZE - 1, %$START, _?SIZE
	; piBoot, piStartCHS, piType, piEndCHS,		piStart, piLength
  fillslot
	addsection DATA%[COUNT], STARTSFOLLOWS
	%xdefine STARTSFOLLOWS follows=DATA%[COUNT]
  %xdefine LIST LIST, DATA%[COUNT],file,_?SIZE
  %assign COUNT COUNT + 1
  %assign %$START %$START + _?SIZE
  %assign isprimary 0
  %assign slot 0
 %elif islogical == 2
  %ifctx MBR
   %fatal Logical partition not supported in MBR
  %endif
  choosesize %1, 1
  %assign islogical 3
 %elif islogical == 3
	typedef ?TYPE, %1
  %assign islogical 4
 %elif islogical == 4
  %xdefine file %1
  chooseslot
  %xdefine ENTRY \
	0, %$START, _?TYPE, %$START + _?SIZE - 1, \
	%$START - %$innermostextended, _?SIZE
	; piBoot, piStartCHS, piType, piEndCHS,
	; piStart, piLength
  fillslot
	addsection DATA%[COUNT], STARTSFOLLOWS
	%xdefine STARTSFOLLOWS follows=DATA%[COUNT]
  %xdefine LIST LIST, DATA%[COUNT],file,_?SIZE
  %assign COUNT COUNT + 1
  %assign %$START %$START + _?SIZE
  %assign islogical 0
  %assign slot 0
 %elif isextended == 1
  choosesize %1, %$thisisextended
  %assign isextended 2
 %elif isextended == 2
	exttypedef ?TYPE, %1
  chooseslot

	addsection GAP%[COUNT], STARTSFOLLOWS
	%xdefine STARTSFOLLOWS follows=GAP%[COUNT]
  %assign %%modulo %$START % (_CHS_HEADS * _CHS_SECTORS)
  %if %%modulo
   %assign %%adjust (_CHS_HEADS * _CHS_SECTORS) - %%modulo
   %xdefine LIST LIST, GAP%[COUNT],,%%adjust
   %assign %$START %$START + %%adjust
  %endif

  %xdefine ENTRY \
	0, %$START, _?TYPE, %$START + _?SIZE - 1, \
	%$START - %$outermostextended, _?SIZE
	; piBoot, piStartCHS, piType, piEndCHS
	; piStart, piLength
  fillslot
	addsection TABLE%[COUNT], STARTSFOLLOWS
	%xdefine STARTSFOLLOWS follows=TABLE%[COUNT]
%push EPBR
	times (512 - 2 - 4 * 16) - ($ - $$) db 0

%define %$entry1
%define %$entry2
%define %$entry3
%define %$entry4
%assign %$START %$$START + _CHS_SECTORS
%assign %$END %$$START + _?SIZE
%assign %$thisisextended 1
%xdefine %$tablesection TABLE%[COUNT]
%if %$$thisisextended
 %assign %$outermostextended %$$outermostextended
%else
 %assign %$outermostextended %$$START
%endif
%assign %$innermostextended %$$START

  %xdefine LIST LIST, TABLE%[COUNT],,_CHS_SECTORS
  %assign COUNT COUNT + 1
  %assign %$$START %$$START + _?SIZE

  %assign isextended 0
  %assign slot 0
 %elif isslot == 1
  %assign slot %1
  %if slot > 4
   %fatal Too high Slot
  %endif
  %assign isslot 0
 %elifidni %1, ::primary
  %assign isprimary 1
 %elifidni %1, ::logical
  %assign islogical 2
 %elifidni %1, ::extended
  %assign isextended 1
 %elifidni %1, ::slot
  %assign isslot 1
 %elifidni %1, ::up
  %ifctx MBR
   %fatal Cannot up out of MBR
  %endif
  dumptable %$tablesection, EPBR
  %pop
 %else
  %fatal Unknown keyword
 %endif
 %rotate 1
%endrep
%if isprimary
 %error Too few parameters for primary partition
%endif
%if islogical
 %error Too few parameters for logical partition
%endif
%if isextended
 %error Too few parameters for extended partition
%endif
%if isslot
 %error Too few parameters for Slot
%endif
%endmacro

	multi _PAYLOAD

%rep 1024
 %ifctx MBR
  %exitrep
 %else
	dumptable %$tablesection, EPBR
  %pop
 %endif
%endrep
%ifnctx MBR
 %fatal Too many nested extended partitions
%endif
dumptable mbr, MBR


%macro list 3-*
 %if %0 % 3
  %fatal Internal error, unexpected list length
 %endif
 %rep %0 / 3
	usesection %1
  %ifnempty %2
   %ifstr %2
	incbin %2
   %else
    %defstr %%inc %2
	incbin %%inc
   %endif
  %endif
  %assign %%size ((%3) * _BPS) - ($ - $$)
	zerobytes %%size
  %rotate 3
 %endrep
%endmacro

	list LIST


CYLINDERS equ (%$START + _CHS_HEADS * _CHS_SECTORS - 1) \
	/ (_CHS_HEADS * _CHS_SECTORS)
