
/* Public Domain */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

int main(int argc, char **argv) {
  FILE* ff;
  const unsigned int buffersize = 8192;
  const char* modenames[] = { "Application", "Device driver", "Bootloaded" };
  const char* progressnames[] = { "None", "Dots", "Percentage",
	"Bar", "Bar with percentage" };
  unsigned int ii, offset = 0, mode = 0, progress, size,
	choices, query = 1, found = 0, at;
  unsigned long int want = 0, wantreplace = 0, wantminus = 0, wantplus = 0;
  uint8_t buffer[buffersize];
  if (argc < 3) {
    fprintf(stderr,"Usage: patchpro ldebug.com [APP|DEVICE|BOOT] [number]\n");
    return 255;
  }
  ff = fopen(argv[1], "r+b");
  if (! ff) {
    fprintf(stderr,"Error: Failed to open file: %s\n", argv[1]);
    return 2;
  }
  if (! strcmp(argv[2], "APP")
    || ! strcmp(argv[2], "app")
    || ! strcmp(argv[2], "APPLICATION")
    || ! strcmp(argv[2], "application")
    ) {
    offset = 16; mode = 0;
  } else if (! strcmp(argv[2], "DEVICE")
    || ! strcmp(argv[2], "device")
    || ! strcmp(argv[2], "DEV")
    || ! strcmp(argv[2], "dev")
    ) {
    offset = 17; mode = 1;
  } else if (! strcmp(argv[2], "BOOT") || ! strcmp(argv[2], "boot") ) {
    offset = 18; mode = 2;
  }
  if (0 == offset) {
    fprintf(stderr,"Error: Invalid progress mode: %s\n", argv[2]);
    return 3;
  }
  if (argc == 4) {
    char *pp = argv[3];
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
    if (ii && (pp[ii - 1] == 'H' || pp[ii - 1] == 'h') ) {
      base = 16;
    } else if (ii >= 2 && pp[0] == '0' && (pp[1] == 'B' || pp[1] == 'b') ) {
      pp += 2;
      base = 2;
    } else if (ii >= 2 && pp[0] == '0' && (pp[1] == 'X' || pp[1] == 'x') ) {
      pp += 2;
      base = 16;
    } else if (ii && (pp[ii - 1] == 'B' || pp[ii - 1] == 'b') ) {
      base = 2;
    }
    vv = strtoul(pp, NULL, base);
    query = 0;
    if ((0 == vv && pp[0] != '0')
      || vv < 0 || vv > 255) {
      fprintf(stderr,"Error: Invalid progress choice: %s\n", argv[3]);
      return 4;
    }
    switch (replace_plus_minus) {
    case 0:
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
  if (size < 32) {
    fprintf(stderr,"Error: lCFG block not found\n");
    return 5;
  }
  choices = (size / 16) - 1;
  for (ii = 0; ii <= choices; ++ ii) {
    at = ii * 16;
    if (buffer[at] == 0xEB && ! memcmp(&buffer[at + 2], "lCFG", 4)) {
      found = 1;
      break;
    }
  }
  if (! found) {
    fprintf(stderr,"Error: lCFG block not found\n");
    return 6;
  }
  if (buffer[at + 6] != '0' || buffer[at + 7] != '0') {
    fprintf(stderr,"Error: Unknown version lCFG block found\n");
    return 7;
  }
  if (0 == (buffer[at + 8 + 2] &  (1 << (offset - 16)) )) {
    fprintf(stderr,"Error: lCFG block found doesn't contain this progress mode\n");
    return 8;
  }
  if (! query) {
    if (wantreplace) {
      buffer[at + offset] = want;
    }
    buffer[at + offset] |= wantplus;
    buffer[at + offset] &= ~wantminus;
    fseek(ff, 0, SEEK_SET);
    if (size != fwrite(buffer, 1, size, ff)) {
      fprintf(stderr,"Error: Failed to write file\n");
      return 9;
    }
    printf("Progress choice updated\n");
  }
  {
    const char *pp;
    const char *flag16 = "";
    int value;
    value = progress = buffer[at + offset];
    if (mode != 2 && (progress & 16) ) {
      progress &= ~16;
      flag16 = ", force to file too";
    }
    if (progress < (sizeof(progressnames) / sizeof(progressnames[0]))) {
      pp = progressnames[progress];
    } else {
      pp = "Unknown choice";
    }
    printf("%s progress choice is %u (%s%s)\n",
	modenames[mode], value, pp, flag16);
  }
  return 0;
}
