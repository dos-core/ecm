
/* Public Domain */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

int main(int argc, char **argv) {
  FILE* ff;
  const unsigned int buffersize = 8192;
  const char* unitnames[] = { "Diskette", "Hard disk" };
  const char* flagnames[] = { "Force CHS", "Force LBA",
	"No query geometry", NULL, NULL, NULL,
	"Do not re-check (TestWrit)", "Apply to LDP (lDebug)" };
  unsigned int ii, offset = 0, mode = 0, size,
	choices, query = 1, found = 0, at, limit = 1, current;
  unsigned long int want = 0, wantreplace = 0, wantminus = 0, wantplus = 0;
  uint8_t buffer[buffersize];
  uint8_t match[] = {
	0x8A,0x56,0x40,0xB8,0x00,0x00,0x84,0xD2,0x79,0x02,0x86,0xC4 };
  uint8_t wildcard[] = {
	0x00,0x00,0x00,0x00,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00 };
  const unsigned int patchoffset = 4;
  if (argc < 2) {
    printf("Usage: patchqry ldebug.com [DISKETTE|HARDDISK] [number]\n\n");
    printf("Supported query patch flags:\n");
    for (ii = 0; ii < 8; ++ ii) {
      if (flagnames[ii]) {
        printf(" %02Xh: %s\n", 1 << ii, flagnames[ii]);
      }
    }
    return 0;
  }
  ff = fopen(argv[1], "r+b");
  if (! ff) {
    fprintf(stderr,"Error: Failed to open file: %s\n", argv[1]);
    return 2;
  }
  if (argc < 3) {
    mode = 255;
  } else if (! strcmp(argv[2], "DISKETTE")
    || ! strcmp(argv[2], "diskette")
    || ! strcmp(argv[2], "FLOPPY")
    || ! strcmp(argv[2], "floppy")
    ) {
    offset = 0; mode = 0;
  } else if (! strcmp(argv[2], "HARDDISK")
    || ! strcmp(argv[2], "harddisk")
    || ! strcmp(argv[2], "HDD")
    || ! strcmp(argv[2], "hdd")
    || ! strcmp(argv[2], "FIXEDDISK")
    || ! strcmp(argv[2], "fixeddisk")
    ) {
    offset = 1; mode = 1;
  } else {
    fprintf(stderr,"Error: Invalid unit name: %s\n", argv[2]);
    return 3;
  }
  for (current = 3; current < argc; ++ current) {
    char *pp = argv[current];
    char *expectedend;
    char *parsedend;
    char replace_plus_minus = 0;
    unsigned int base = 10;
    unsigned long int vv = 0;
    if (pp[0] == '+') {
      ++ pp;
      replace_plus_minus = 1;
    } else if (pp[0] == '-') {
      ++ pp;
      replace_plus_minus = 2;
    } else {
      wantreplace = 1;
    }
    ii = strlen(pp);
    expectedend = &pp[ii];
    if (ii && (pp[ii - 1] == 'H' || pp[ii - 1] == 'h') ) {
      base = 16;
      -- expectedend;
    } else if (ii >= 2 && pp[0] == '0' && (pp[1] == 'B' || pp[1] == 'b') ) {
      pp += 2;
      base = 2;
    } else if (ii >= 2 && pp[0] == '0' && (pp[1] == 'X' || pp[1] == 'x') ) {
      pp += 2;
      base = 16;
    } else if (ii && (pp[ii - 1] == 'B' || pp[ii - 1] == 'b') ) {
      base = 2;
      -- expectedend;
    }
    vv = strtoul(pp, &parsedend, base);
    query = 0;
    if ((0 == vv && pp[0] != '0')
      || vv < 0 || vv > 255
      || expectedend != parsedend) {
      fprintf(stderr,"Error: Invalid query patch choice: %s\n", argv[current]);
      return 4;
    }
    switch (replace_plus_minus) {
    case 0:
      if (current != 3) {
        fprintf(stderr,"Error: Invalid query patch choice: %s\n", argv[current]);
        return 4;
      }
      want = vv;
      wantplus = 0;
      wantminus = 0;
      break;
    case 1:
      wantplus |= vv;
      wantminus &= ~vv;
      break;
    case 2:
      wantminus |= vv;
      wantplus &= ~vv;
      break;
    }
  }
  size = fread(buffer, 1, buffersize, ff);
  if (size < sizeof(match)) {
    fprintf(stderr,"Error: Query patch site not found\n");
    return 5;
  }
  choices = size - sizeof(match) + 1;
  for (ii = 0; ii <= choices; ++ ii) {
    unsigned int jj;
    at = ii;
    for (jj = 0; jj < sizeof(wildcard); ++ jj) {
      if (wildcard[jj]) {
        match[jj] = buffer[at + jj];
      }
    }
    if (! memcmp(&buffer[at], match, sizeof(match))) {
      found = 1;
      break;
    }
  }
  if (! found) {
    fprintf(stderr,"Error: Query patch site not found\n");
    return 6;
  }
  if (! query) {
    if (wantreplace) {
      buffer[at + patchoffset + offset] = want;
    }
    buffer[at + patchoffset + offset] |= wantplus;
    buffer[at + patchoffset + offset] &= ~wantminus;
    fseek(ff, 0, SEEK_SET);
    if (size != fwrite(buffer, 1, size, ff)) {
      fprintf(stderr,"Error: Failed to write file\n");
      return 9;
    }
    printf("Query patch updated\n");
  }
  if (mode == 255) {
    limit = 2;
    offset = 0;
  }
  for (; limit; -- limit, ++ offset) {
    const char *pp;
    const char *initial = "\n\t";
    const char *separator = "";
    const char *final = "";
    int value;
    value = buffer[at + patchoffset + offset];
    printf("%s query patch = %02Xh", unitnames[offset], value);
    for (ii = 0; ii < 8; ++ ii) {
      if ( 0 == (value & (1 << ii)) ) {
        continue;
      }
      if (flagnames[ii]) {
        pp = flagnames[ii];
      } else {
        pp = "Unknown";
      }
      printf("%s%s%02Xh: %s", initial, separator, 1 << ii, pp);
      initial = "";
      separator = "\n\t";
      final = "";
    }
    printf("%s\n", final);
  }
  return 0;
}
