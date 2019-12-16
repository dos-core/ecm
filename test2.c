
/*

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

*/

#include "stdint.h"
#include "inttypes.h"
#include "stdio.h"
#include "string.h"


/* taken from https://stackoverflow.com/a/44947877/738287 */
uint16_t crc16_3(const uint8_t *ptr, uint32_t count)
{
   uint16_t crc;
   uint8_t i;
   crc = 0xFFFF;
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
   return (crc);
}

uint16_t crc16_4(const uint8_t *ptr, uint32_t count)
{
   uint16_t crc;
   uint8_t i, v, ch;
   crc = 0xFFFF;
   while (count)
   {
      ch = *ptr++;
      i = 8;
      v = 0x80;
      do
      {
         if (crc & 0x8000)
            crc = (crc << 1) ^ 0x1021;
         else
            crc = (crc << 1);
         if (ch & v)
            crc ^= 1;
         v >>= 1;
      } while(--i);
      --count;
   }
   for (i = 0; i < 16; ++i) {
      if (crc & 0x8000)
         crc = (crc << 1) ^ 0x1021;
      else
         crc = (crc << 1);
   }
   return (crc);
}

void test(const uint8_t * ptr, uint32_t count) {
	printf("CRC16_3 = %04"PRIX16", Length = %"PRIu32", Text = \"%s\"\n",
		crc16_3(ptr, count), count, ptr);
	printf("CRC16_4 = %04"PRIX16", Length = %"PRIu32", Text = \"%s\"\n",
		crc16_4(ptr, count), count, ptr);
}

void main(void) {
	uint8_t buffer[256 + 1];
	uint32_t ii;
	for (ii = 0; ii < 256; ++ii) {
		buffer[ii] = 'A';
	}
	buffer[ii] = 0;
	test("", strlen(""));
	test("A", strlen("A"));
	test("123456789", strlen("123456789"));
	test(buffer, 256);
	test("foobar", strlen("foobar"));
	test("A", strlen("A")+1);
	test("123456789", strlen("123456789")+1);
}

