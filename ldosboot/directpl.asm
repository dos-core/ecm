
%if 0

Loader direct payload
 by E. C. Masloch, 2026

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%define MODULE directpl
%include "lmacros3.mac"
	sectalign off


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting

	strdef PAYLOAD_FILE,	"kernel.bin"
	numdef TEST_PROGRAM,	0

	strdef INILOAD_CFG, ""
%ifnidn _INILOAD_CFG, ""
 %include _INILOAD_CFG
%endif


	cpu 8086
	org 0

	addsection PAYLOAD
payload:
	incbin _PAYLOAD_FILE
	align 16, db 38
