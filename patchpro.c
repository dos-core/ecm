
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
  unsigned int ii, offset = 0, mode = 0, progress, want = 0, size,
	choices, query = 1, found = 0, at;
  uint8_t buffer[buffersize];
  if (argc < 3) {
    fprintf(stderr,"Usage: patchpro ldebug.com [APP|DEVICE|BOOT] number\n");
    return 255;
  }
  ff = fopen(argv[1], "r+b");
  if (! ff) {
    fprintf(stderr,"Error: Failed to open file: %s\n", argv[1]);
    return 2;
  }
  if (! strcmp(argv[2], "APP") || ! strcmp(argv[2], "app") ) {
    offset = 16; mode = 0;
  } else if (! strcmp(argv[2], "DEVICE") || ! strcmp(argv[2], "device") ) {
    offset = 17; mode = 1;
  } else if (! strcmp(argv[2], "BOOT") || ! strcmp(argv[2], "boot") ) {
    offset = 18; mode = 2;
  }
  if (0 == offset) {
    fprintf(stderr,"Error: Invalid progress mode: %s\n", argv[2]);
    return 3;
  }
  if (argc == 4) {
    want = atoi(argv[3]);
    query = 0;
  }
  if (argc == 4 && 0 == want && argv[3][0] != '0') {
    fprintf(stderr,"Error: Invalid progress choice: %s\n", argv[3]);
    return 4;
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
  if (query) {
    const char *pp;
    progress = buffer[at + offset];
    if (progress < (sizeof(progressnames) / sizeof(progressnames[0]))) {
      pp = progressnames[progress];
    } else {
      pp = "Unknown choice";
    }
    printf("%s progress choice is %u (%s)\n", modenames[mode], progress, pp);
  }
}
