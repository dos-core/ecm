
%if 0

typesuch.asm - Type search strings for instsect
 2024 by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%unmacro searchflag 3
%unmacro search_wildcard 1-2 0
%unmacro type_search_string 2
%unmacro dumpsearches 1-*


%define SEARCHES dw ""
%define STRINGS db ""
%define METASEARCHES dw ""
%define METASTRINGS dw ""
%define SEARCHFLAGS dw ""


	%macro search_wildcard 1-2 0
%assign %%wc $ + %2 - %1
%if %%wc == 0
 %error Wildcard at beginning of search string is not allowed
%endif
%xdefine WILDCARDS WILDCARDS, dw %%wc
	%endmacro

	%macro type_search_string 2
%define WILDCARDS dw ""

 %define %%identifier %[PREFIX]label_%1_type
 %define %%identifierminusall label_%1_type

%define %%extra 0

%%start:
%[%%identifier %+ _search_string]:

%if %2 == 0
	jmp 200h:400h
%define %%messagestring "lDOS (new)"
%elif %2 == 1
	jmp 70h:400h
%define %%messagestring "lDOS (old)"
%elif %2 == 2
	jmp 70h:200h
%define %%messagestring "MS-DOS v7"
%elif %2 == 3
	jmp 70h:0
%define %%messagestring "MS-DOS v6 / IBM-DOS / lDOS (EDR-DOS)"
%elif %2 == 4
	jmp 1FE0h:0
search_wildcard %%start, -4
search_wildcard %%start, -3
	dw 0
	dw 60h
%define %%messagestring "FreeDOS (FreeDOS)"
%elif %2 == 5
	jmp 1FE0h:0
search_wildcard %%start, -4
search_wildcard %%start, -3
	dw 0
	dw 70h
%define %%messagestring "FreeDOS (Enhanced DR-DOS)"
%elif %2 == 6
	jmp 1FE0h:0
search_wildcard %%start, -4
search_wildcard %%start, -3
	dw 0
%define %%messagestring "FreeDOS (other)"
%elif %2 == 7
	jmp 60h:0
%define %%messagestring "lDOS (FreeDOS)"
%else
 %error Unexpected parameter
%endif
%%end:


%xdefine STRINGS STRINGS, %%message:, {asciz %%messagestring}
%xdefine SEARCHES SEARCHES, %%identifier:, dw %%start, dw %%end - %%start, \
	 dw %%message, dw %%extra, WILDCARDS, dw 0
%xdefine METASEARCHES METASEARCHES, dw %%metaname, dw variant
%defstr %%name %%identifierminusall
%xdefine METASTRINGS METASTRINGS, %%metaname:, {asciz %%name}
%[%%identifier %+ _length]: equ %%end - %%start

	%endmacro


%assign variant 0
%rep 8
 %assign identifier variant
	type_search_string identifier, variant
 %assign variant variant + 1
%endrep


	%macro dumpsearches 1-*
%rep %0
 %1
 %rotate 1
%endrep
	%endmacro

dumpsearches STRINGS

	align 2, db 0
%[PREFIX]type_search_metadata:
dumpsearches SEARCHES
	dw 0,0
