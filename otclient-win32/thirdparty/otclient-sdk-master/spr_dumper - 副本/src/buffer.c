#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <stdint.h>

#include "buffer.h"

typedef struct buffer
{
	uint32_t rpos, size;
	uint8_t *data;
} buffer_t;

static __inline uint16_t 
u16(unsigned char *addr)
{
	return addr[1] << 8 | addr[0];
}

static __inline uint32_t 
u32(unsigned char *addr)
{
	return u16(addr + 2) << 16 | u16(addr);
}

static bool 
stat_file(const char *f, int *size)
{
	struct stat st;
	if (stat(f, &st) != 0)
		return false;
	*size = st.st_size;
	return true;
}

uint32_t 
bget32(buffer_t *bp)
{
	uint32_t tmp = u32(&bp->data[bp->rpos]);
	bp->rpos += 4;
	return tmp;
}

uint16_t 
bget16(buffer_t *bp)
{
	uint16_t tmp = u16(&bp->data[bp->rpos]);
	bp->rpos += 2;
	return tmp;
}

uint8_t 
bgetc(buffer_t *bp)
{
	uint8_t tmp = bp->data[bp->rpos];
	++bp->rpos;
	return tmp;
}

int 
btell(const buffer_t *bp)
{
	return bp->rpos;
}

void 
bskip(buffer_t *buffer, int size)
{
	if (buffer->rpos + size > buffer->size)
		return;
	buffer->rpos += size;
}

void 
bseek(buffer_t *buffer, int pos)
{
	if (pos > (int)buffer->size)
		return;
	buffer->rpos = pos;
}

buffer_t* 
balloc(const char* f)
{
	FILE *fp;
	buffer_t *res;
	int fsize;

	if (!stat_file(f, &fsize)) {
		fprintf(stderr, "could not stat %s\n", f);
		return NULL;
	}

	fp = fopen(f, "rb");
	if (!fp) {
		fprintf(stderr, "could not open file %s for caching %s\n", f, strerror(errno));
		return NULL;
	}

	res = malloc(sizeof(*res));
	if (!res) {
		fprintf(stderr, "could not allocate buffer for %s with size %d\n", f, fsize);
		goto out;
	}

	res->data = calloc(1, fsize);
	if (!res->data) {
		fprintf(stderr, "could not allocate enough memory to hold the cached data\n");
		goto out;
	}

	res->size = fsize;
	res->rpos = 0;
	if (fread(res->data, 1, res->size, fp) != res->size) {
		fprintf(stderr, "could not cache file %s of size %d\n", f, res->size);
		bfree(res);
		goto out;
	}

out:
	fclose(fp);
	return res;
}

void 
bfree(buffer_t *b)
{
	free(b->data);
	free(b);
}

