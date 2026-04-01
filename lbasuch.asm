
%if 0

lbasuch.asm - LBA search strings for instsect
 2024 by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%unmacro searchflag 3
%unmacro search_wildcard 1-2 0
%unmacro ldosboot_lba_search_string 12
%unmacro freedos_lba_search_string 4
%unmacro dumpsearches 1-*


%define SEARCHES dw ""
%assign SEARCHINDEX 0
%xdefine AUTOLIST dw ""
%xdefine AHDDLIST dw ""
%xdefine NONELIST dw ""
%define METASEARCHES dw ""
%define METASTRINGS dw ""
%define SEARCHFLAGS dw ""
%assign any_SET 0
%assign ldos_SET 0
%assign freedos_SET 0

	%macro searchflag 3
%ifn %1_SET
 %assign %1_SET 1
 %if any_SET
  %xdefine SEARCHFLAGS SEARCHFLAGS, dw 0
 %else
  %assign any_SET 1
 %endif
 %xdefine SEARCHFLAGS SEARCHFLAGS, %1_searchflags:
%endif

%xdefine SEARCHFLAGS SEARCHFLAGS, dw %3, dw %%name
%xdefine METASTRINGS METASTRINGS, %%name:, {asciz %2}
	%endmacro


	%macro search_wildcard 1-2 0
%assign %%wc $ + %2 - %1
%if %%wc == 0
 %error Wildcard at beginning of search string is not allowed
%endif
%xdefine WILDCARDS WILDCARDS, dw %%wc
	%endmacro

	%macro ldosboot_lba_search_string 12
%define WILDCARDS dw ""
%assign _FORCE_CHS %2
%assign _LBA_SKIP_CHECK %3
%assign _LBA_SKIP_CY %4
%assign _LBA_SKIP_LBA_RETRY %5
%assign _LBA_SKIP_ANY %6
%assign _RETRY_RESET %7
%assign _LBA_RETRY %8
%assign _LBA_WORKAROUND %9
%assign _LBA_HDD_ONLY %10
%assign _LBA_HDD_ONLY_DISABLED %11
%assign _CHS 1
%assign _LDOSBOOT32 %12


%if !ALL && \
 ! _LBA_SKIP_CHECK && \
 (_LBA_SKIP_CY || _LBA_SKIP_LBA_RETRY || _LBA_SKIP_ANY || _LDOSBOOT32)
%elif !ALL && \
 _LBA_SKIP_CHECK && \
 (_LBA_WORKAROUND)
%elif !ALL && \
 _LBA_SKIP_CHECK && \
 _LBA_SKIP_ANY && \
 (_LDOSBOOT32)
%elif !ALL && \
 _LBA_SKIP_CHECK && \
 ! _LDOSBOOT32 && \
 (_LBA_SKIP_ANY)
%elif !ALL && \
 ! _LBA_RETRY && \
 (_RETRY_RESET)
%elif !ALL && \
 (_LBA_SKIP_LBA_RETRY)
%elif (_FORCE_CHS && _LBA_HDD_ONLY && !_LBA_HDD_ONLY_DISABLED)
%elif (!_LBA_HDD_ONLY && _LBA_HDD_ONLY_DISABLED)
%else

%if _LBA_HDD_ONLY
 %xdefine %%autochoice %[PREFIX]label_%1_autodisabled
 %xdefine %%ahddchoice %[PREFIX]label_%1_ahdd
 %xdefine %%nonechoice %[PREFIX]label_%1_nonedisabled
%else
 %xdefine %%autochoice %[PREFIX]label_%1_auto
 %xdefine %%ahddchoice 0
 %xdefine %%nonechoice %[PREFIX]label_%1_none
%endif

%if _LBA_HDD_ONLY && _FORCE_CHS
 %define %%identifier %[PREFIX]label_%1_nonedisabled
 %define %%identifierminusall label_%1_nonedisabled
%elif _LBA_HDD_ONLY && _LBA_HDD_ONLY_DISABLED
 %define %%identifier %[PREFIX]label_%1_autodisabled
 %define %%identifierminusall label_%1_autodisabled
%elif _LBA_HDD_ONLY
 %define %%identifier %[PREFIX]label_%1_ahdd
 %define %%identifierminusall label_%1_ahdd
%elif _FORCE_CHS
 %define %%identifier %[PREFIX]label_%1_none
 %define %%identifierminusall label_%1_none
%else
 %define %%identifier %[PREFIX]label_%1_auto
 %define %%identifierminusall label_%1_auto
%endif

%%start:
%[%%identifier %+ _search_string]:

 %if _LBA_SKIP_CHECK		; -14 bytes
	mov dl, [bp + 127]
search_wildcard %%start, -1
  %if _LBA_HDD_ONLY
   %if _LBA_HDD_ONLY_DISABLED || _FORCE_CHS
	test dl, dl
	test al, .no_lba - ($ + 2)
search_wildcard %%start, -1
   %else
	test dl, dl
	jns .no_lba
search_wildcard %%start, -1
   %endif
  %endif
 %else
  %if _LBA_WORKAROUND
	push ds
	mov bx, 40h
	mov ds, bx
; Setting ds = 40h for the function 41h detection is a workaround
;  for a bug in the Book8088's Xi8088 BIOS. Refer to
;  https://www.bttr-software.de/forum/forum_entry.php?id=21275
  %endif
	mov ah, 41h
	mov dl, [bp + 127]
search_wildcard %%start, -1
	mov bx, 55AAh
%if _LBA_HDD_ONLY
 %if _LBA_HDD_ONLY_DISABLED || _FORCE_CHS
	cmp dl, dl
	stc
	jne @F
 %else
	test dl, dl
	stc
	jns @F
 %endif
%else
	stc
%endif
%if _FORCE_CHS
	nop
	nop
%else
	int 13h		; 13.41.bx=55AA extensions installation check
%endif
@@:
  %if _LBA_WORKAROUND
	pop ds
  %endif
	jc .no_lba
search_wildcard %%start, -1
	cmp bx, 0AA55h
	jne .no_lba
search_wildcard %%start, -1
	shr cl, 1	; support bitmap bit 0
	jnc .no_lba
search_wildcard %%start, -1
 %endif

%if _LBA_RETRY
 %if _LBA_SKIP_CHECK && _LBA_SKIP_CY
	stc
 %endif
	mov ah, 42h
%if _FORCE_CHS
	nop
	stc
%else
	int 13h		; 13.42 extensions read
%endif
	jnc .lba_done
search_wildcard %%start, -1

 %if _RETRY_RESET
	xor ax, ax
	int 13h		; reset disk
 %endif

		; have to reset the LBAPACKET's lpCount, as the handler may
		;  set it to "the number of blocks successfully transferred".
		; (in any case, the high byte is still zero.)
	mov byte [si + 2], 1
%endif

 %if _LBA_SKIP_CHECK && _LBA_SKIP_CY
	stc
 %endif
%if _FORCE_CHS
	mov ah, 01h
	nop
	stc
%else
	mov ah, 42h
	int 13h
%endif
 %if _LBA_SKIP_CHECK && _CHS
 %if _LDOSBOOT32
  %if _LBA_SKIP_ANY
	jc .no_lba
search_wildcard %%start, -1
  %else
	jnc .lba_done
search_wildcard %%start, -1
	cmp ah, 1	; invalid function?
	je .no_lba	; try CHS instead -->
search_wildcard %%start, -1
  %endif
 %else
  %if _LBA_SKIP_ANY
	jc .no_lba
search_wildcard %%start, -1
  %else
	jc .lba_check_error_1
search_wildcard %%start, -1
  %endif
 %endif
 %else
.cy_err:
	jc .lba_error
search_wildcard %%start, -1
 %endif

.lba_error:
.lba_check_error_1:
.lba_done:
.no_lba:
%%end:

%if _FORCE_CHS
 %if _LBA_HDD_ONLY
  %define %%message lba_search_msg.forcechshdd
 %else
  %define %%message lba_search_msg.forcechs
 %endif
%else
 %if _LBA_HDD_ONLY
  %if _LBA_HDD_ONLY_DISABLED
   %if _LBA_SKIP_CHECK
    %define %%message lba_search_msg.autohdddisabledskip
   %else
    %define %%message lba_search_msg.autohdddisabled
   %endif
  %else
   %if _LBA_SKIP_CHECK
    %define %%message lba_search_msg.autohddskip
   %else
    %define %%message lba_search_msg.autohdd
   %endif
  %endif
 %else
  %if _LBA_SKIP_CHECK
   %define %%message lba_search_msg.autoskip
  %else
   %define %%message lba_search_msg.auto
  %endif
 %endif
%endif

%xdefine AUTOLIST AUTOLIST, dw %%autochoice
%xdefine AHDDLIST AHDDLIST, dw %%ahddchoice
%xdefine NONELIST NONELIST, dw %%nonechoice
%xdefine SEARCHES SEARCHES, %%identifier:, dw %%start, dw %%end - %%start, \
	 dw %%message, dw SEARCHINDEX, WILDCARDS, dw 0
%xdefine METASEARCHES METASEARCHES, dw %%metaname, dw variant
%defstr %%name %%identifierminusall
%xdefine METASTRINGS METASTRINGS, %%metaname:, {asciz %%name}
%[%%identifier]_length: equ %%end - %%start
%assign %[%%identifier]_length_set 1
%ifnidni %%autochoice, 0
 %ifdef %[%%autochoice]_length_set
  %if %[%%identifier]_length != %[%%autochoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%ifnidni %%ahddchoice, 0
 %ifdef %[%%ahddchoice]_length_set
  %if %[%%identifier]_length != %[%%ahddchoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%ifnidni %%nonechoice, 0
 %ifdef %[%%nonechoice]_length_set
  %if %[%%identifier]_length != %[%%nonechoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%assign SEARCHINDEX SEARCHINDEX + 1

%endif
	%endmacro

	%macro freedos_lba_search_string 4
%define WILDCARDS dw ""
%assign _FORCE_CHS %2
%assign _OEM_BOOT %3
%assign _FORCE_CHS_DISKETTE %4

 %xdefine %%autochoice %[PREFIX]label_%1_autodisabled
 %xdefine %%ahddchoice %[PREFIX]label_%1_ahdd
 %xdefine %%nonechoice %[PREFIX]label_%1_none

%if _FORCE_CHS_DISKETTE
 %define %%identifier %[PREFIX]label_%1_ahdd
 %define %%identifierminusall label_%1_ahdd
%elif _FORCE_CHS
 %define %%identifier %[PREFIX]label_%1_none
 %define %%identifierminusall label_%1_none
%else
 %define %%identifier %[PREFIX]label_%1_autodisabled
 %define %%identifierminusall label_%1_autodisabled
%endif

%%start:
%[%%identifier %+ _search_string]:

	mov ah, 41h
	mov bx, 55AAh
	mov dl, [bp + 127]
search_wildcard %%start, -1

%if _FORCE_CHS
	xor dl, dl
	jz @F
%elif _FORCE_CHS_DISKETTE
	test dl, dl
	jz @F
%else
	test dl, dl
	nop
	nop
%endif
	int 13h
	jc @F
	shr cx, 1
	sbb bx, 0AA55h - 1
	jne @F

%if _OEM_BOOT
	lea si, [bp + 1023]
search_wildcard %%start, -2
search_wildcard %%start, -1
	mov word [bp + 1023], bx
search_wildcard %%start, -2
search_wildcard %%start, -1
	mov word [bp + 1023], bx
search_wildcard %%start, -2
search_wildcard %%start, -1
%else
	lea si, [bp - 128]
search_wildcard %%start, -1
	mov word [bp - 128], bx
search_wildcard %%start, -1
	mov word [bp - 128], bx
search_wildcard %%start, -1
%endif
	mov ah, 42h
	jmp strict short @F
search_wildcard %%start, -1
@@:
%%end:


%if _FORCE_CHS
 %define %%message lba_search_msg.forcechs
%else
 %if _FORCE_CHS_DISKETTE
  %define %%message lba_search_msg.autohdd
 %else
  %define %%message lba_search_msg.auto
 %endif
%endif

%xdefine AUTOLIST AUTOLIST, dw %%autochoice
%xdefine AHDDLIST AHDDLIST, dw %%ahddchoice
%xdefine NONELIST NONELIST, dw %%nonechoice
%xdefine SEARCHES SEARCHES, %%identifier:, dw %%start, dw %%end - %%start, \
	 dw %%message, dw SEARCHINDEX, WILDCARDS, dw 0
%xdefine METASEARCHES METASEARCHES, dw %%metaname
%xdefine METASEARCHES METASEARCHES, dw 32*1024 + !!%2 * 1 + !!%3 * 2 + !!%4 * 4
%defstr %%name %%identifierminusall
%xdefine METASTRINGS METASTRINGS, %%metaname:, {asciz %%name}
%[%%identifier]_length: equ %%end - %%start
%assign %[%%identifier]_length_set 1
%ifnidni %%autochoice, 0
 %ifdef %[%%autochoice]_length_set
  %if %[%%identifier]_length != %[%%autochoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%ifnidni %%ahddchoice, 0
 %ifdef %[%%ahddchoice]_length_set
  %if %[%%identifier]_length != %[%%ahddchoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%ifnidni %%nonechoice, 0
 %ifdef %[%%nonechoice]_length_set
  %if %[%%identifier]_length != %[%%nonechoice]_length
   %error Expected same length of replacement
  %endif
 %endif
%endif
%assign SEARCHINDEX SEARCHINDEX + 1
	%endmacro

searchflag freedos, "_FORCE_CHS", 1
searchflag freedos, "_OEM_BOOT", 2
searchflag freedos, "_FORCE_CHS_DISKETTE", 4


%[PREFIX]lba_search_msg:
.auto:		asciz "Auto LBA detection"
.autoskip:	asciz "Auto LBA detection (skip check)"
.forcechs:	asciz "Forced CHS access"
.autohdd:	asciz "Auto LBA detection (HDD only)"
.autohddskip:	asciz "Auto LBA detection (HDD only, skip check)"
.forcechshdd:	asciz "Forced CHS access (HDD only unused)"
.autohdddisabled:	asciz "Auto LBA detection (HDD only disabled)"
.autohdddisabledskip:	asciz "Auto LBA detection (HDD only disabled, skip check)"

%[PREFIX]lba_search_strings_lba:
	freedos_lba_search_string freedos, 0, 0, 0
	freedos_lba_search_string freedos_oem, 0, 1, 0
%assign variant 0
%rep 2048
 %if variant == 1024
%[PREFIX]lba_search_strings_chs:
	freedos_lba_search_string freedos, 1, 0, 0
	freedos_lba_search_string freedos_oem, 1, 1, 0
 %endif
 %assign identifier variant & ~(1024 | 128 | 256)
	ldosboot_lba_search_string \
	 identifier, \
	 variant & 1024, \
	 variant & 1, \
	 variant & 2, \
	 variant & 4, \
	 variant & 8, \
	 variant & 16, \
	 variant & 32, \
	 variant & 64, \
	 variant & 128, \
	 variant & 256, \
	 variant & 512
 %assign variant variant + 1
%endrep

searchflag ldos, "_FORCE_CHS", 1024
searchflag ldos, "_LBA_SKIP_CHECK", 1
searchflag ldos, "_LBA_SKIP_CY", 2
searchflag ldos, "_LBA_SKIP_LBA_RETRY", 4
searchflag ldos, "_LBA_SKIP_ANY", 8
searchflag ldos, "_RETRY_RESET", 16
searchflag ldos, "_LBA_RETRY", 32
searchflag ldos, "_LBA_WORKAROUND", 64
searchflag ldos, "_LBA_HDD_ONLY", 128
searchflag ldos, "_LBA_HDD_ONLY_DISABLED", 256
searchflag ldos, "_LDOSBOOT32", 512


%[PREFIX]lba_search_strings_hdd:
	freedos_lba_search_string freedos, 0, 0, 1
	freedos_lba_search_string freedos_oem, 0, 1, 1
%[PREFIX]lba_search_strings_end:


	%macro dumpsearches 1-*
%rep %0
 %1
 %rotate 1
%endrep
	%endmacro

	align 2, db 0
%[PREFIX]autochoices:
	dumpsearches AUTOLIST
%[PREFIX]ahddchoices:
	dumpsearches AHDDLIST
%[PREFIX]nonechoices:
	dumpsearches NONELIST

	align 2, db 0
%[PREFIX]lba_search_metadata:
	dumpsearches SEARCHES
	dw 0,0
