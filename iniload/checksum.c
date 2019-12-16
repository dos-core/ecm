
/*

checksum - Add checksums to kernel loader
 2019 by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

*/

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#pragma pack(push, 1)
struct __attribute__((__packed__)) checksumheader {
	uint16_t signature;
	uint16_t length_bytes_structure;
	uint16_t checksum_structure;
	uint16_t type_checksum;
	uint16_t amount_paragraphs_data;
	uint16_t checksum_data;
};
#pragma pack(pop)

uint16_t getword(const uint16_t * pp) {
  return ((uint8_t*)pp)[0] + (((uint8_t*)pp)[1] << 8);
}

void setword(uint16_t * pp, const uint16_t vv) {
  ((uint8_t*)pp)[0] = vv & 0xFF;
  ((uint8_t*)pp)[1] = vv >> 8;
}

uint16_t get_checksum_structure(const struct checksumheader * csh) {
  uint16_t ii, cs = 0;
  for (ii = 0; ii < sizeof(*csh) / 2; ++ii) {
    if (ii * 2 != offsetof(struct checksumheader, checksum_structure)
	&& ii * 2 != offsetof(struct checksumheader, checksum_data) ) {
      cs += getword(&((uint16_t*)csh)[ii]);
      cs &= 0xFFFF;
    }
  }
  cs = 0x10000 - cs;
  return cs;
}

#define TYPE_CRC16_6 6

void crc16_5_init(uint16_t * p_crc) {
   *p_crc = 0x1D0F;
}

void crc16_5_step(uint16_t * p_crc, const uint8_t *ptr, uint32_t count)
{
   uint16_t crc = *p_crc;
   uint8_t i;
   while (count)
   {
      crc = crc ^ ( ((uint16_t) *ptr++) << 8);
      i = 8;
      do
      {
         if (crc & 0x8000)
            crc = crc << 1 ^ 0x1021;
         else
            crc = crc << 1;
      } while(--i);
      --count;
   }
   *p_crc = crc;
}

void crc16_5_exit(uint16_t * p_crc) {
   (void)p_crc;
}

int main(int argc, char **argv)
{
#define BUFFER_SIZE 8192
#define SIGNATURE_SIZE 2
  FILE* ff;
  uint8_t buffer[BUFFER_SIZE];
  const uint8_t signature[SIGNATURE_SIZE] = "CS";
  uint16_t size, cs, ww, type, crc;
  uint32_t offset, ii, filesize, jj;
  struct checksumheader csh;
  if (argc != 2) {
usage:
    fprintf(stderr, "Usage: checksum filename.com\n");
    return 255;
  }
  ff = fopen(argv[1], "r+b");
  if (!ff) {
    fprintf(stderr, "Failed to open file: %s\n", argv[1]);
    return 2;
  }
  for (;;) {
    fseek(ff, offset, SEEK_SET);
    size = fread(buffer, 1, BUFFER_SIZE, ff);
    if (size < sizeof(csh)) {
      fprintf(stderr, "Checksum header not found\n");
      return 3;
    }
    for (ii = 0; ii <= (size - sizeof(csh)); ii += 16) {
      if (!memcmp(buffer + ii, signature, SIGNATURE_SIZE)) {
	memcpy((uint8_t *)&csh, buffer + ii, sizeof(csh));
	if (getword(&csh.length_bytes_structure) != sizeof(csh))
	  continue;
	cs = get_checksum_structure(&csh);
	ww = getword(&csh.checksum_structure);
	if (ww != cs) {
	  fprintf(stderr, "Checksum header checksum mismatch,"
		" is=%04"PRIX16"h want=%04"PRIX16"h\n",
		ww, cs);
	  return 4;
	}
	type = getword(&csh.type_checksum) & 0x7FFF;
	if (type != TYPE_CRC16_6) {
	  fprintf(stderr, "Checksum header has unknown checksum type"
		" (%04"PRIX16"h)\n",
		type);
	  return 5;
	}
	goto foundheader;
      }
    }
    offset += BUFFER_SIZE;
  }

 foundheader:
  setword(&csh.type_checksum, type);
  cs = get_checksum_structure(&csh);
  setword(&csh.checksum_structure, cs);

  fseek(ff, 0, SEEK_END);
  filesize = ftell(ff);
  size = getword(&csh.amount_paragraphs_data);

  if ( ((uint32_t)size * 16) > filesize) {
    fprintf(stderr, "Checksum header has too large size,"
		" header=%04"PRIX16"h para"
		" file=%04"PRIX16"h para\n",
		size, (uint16_t)(filesize / 16) );
    return 6;
  }

  fseek(ff, offset + ii, SEEK_SET);
  ww = fwrite((uint8_t *)&csh, 1, sizeof(csh), ff);
  if (ww != sizeof(csh)) {
    fprintf(stderr, "Failed to intermediately write checksum header\n");
    return 6;
  }
  filesize = (uint32_t)size * 16;

  crc16_5_init(&crc);

  for (jj = 0; jj < filesize; jj += BUFFER_SIZE) {
    fseek(ff, jj, SEEK_SET);
    size = fread(buffer, 1, BUFFER_SIZE, ff);
    if (size < BUFFER_SIZE && jj + (uint32_t)size < filesize) {
      fprintf(stderr, "Failed to read %04"PRIu32" remaining bytes\n",
		filesize - (jj + (uint32_t)size) );
      return 8;
    }
    crc16_5_step(&crc, buffer, size);
  }

  crc16_5_exit(&crc);

  setword(&csh.checksum_data, crc);
  fseek(ff, offset + ii, SEEK_SET);
  ww = fwrite((uint8_t *)&csh, 1, sizeof(csh), ff);
  if (ww != sizeof(csh)) {
    fprintf(stderr, "Failed to finally write checksum header\n");
    return 9;
  }

  printf("Successfully set checksum\n");

  return 0;
}
