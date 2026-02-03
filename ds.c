// insert data in a page prefix compressed sstable
//
// On 6502 we cannot expand and use more data,
// thus need to search the prefix compressed format.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>

typedef uint16_t word;

// could also be called str2pascal?
char* memdup(char* m, word len) {
  char* r;
  if (len>255) return NULL;
  r= malloc(len+2);
  if (!r) return NULL;
  r[0]= len;
  memcpy(r+1, m, len);
  r[len+1]= 0;
  return r;
}

// TODO: implement p"foo" notation in compiler?
typedef char* pstr;

//   maybe use pascal strings? lol
pstr oshandle(char* k, char* c, word ts) {
  char h[256]= {0}, * p= h;
  int len;
  
  if (strlen(k)+strlen(c)+2 > 255) return NULL;

  // copy key, zero terminate
  while(*k) *p++= *k++;
  ++p;

  // copy column, zero terminate
  while(*c) *p++= *c++;
  ++p;
  
  // store timestamp searchable
  *p++= ts >> 8;
  *p++= ts & 0xff;

  return memdup(h, p-h);
}

typedef char PageRef[4];

typedef struct Page {
  PageRef next, up; // 8 B
  char ofree; // 1
  char n; // 1
  //char reserved[6];
  char data[256-8-2-20]; // start at 10 ??? or 16
  // offsets of ordered prefixed compressed entries
  // bigger grows down
  char offsets[20];
} Page;

#define PAGE_OFREE_OFFSET offsetof(Page, data)
Page page = {"NEXT", "UBER",
  PAGE_OFREE_OFFSET+26, 1,
  // (- 256 8 2 20) = 226
  { 0, 15, '/','r','o','w','/','k','e','y',0,
           'c','o','l',0,
           0xff,0xff, // < 14
    1, // t
    0x06,'f','o','o','b','a','r',0,
  },
  { 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,
    PAGE_OFREE_OFFSET
    }
};
  
void printchar(char c) {
  if (isprint(c)) putchar(c);
  else if (!c) printf("\\0");
  else if (c=='"') printf("\\\"");
  else printf("\\x%02x", c);
}

void printkey(char* k) {
  char len= *k;
  while(len--) printchar(*++k);
}

void printentry(char* k, char* p) {
  char
    * start= p,
    prelen= *p,
    * w= k+prelen+1,
    bytelen= *++p,
    datalen= *++p,
    t,
    dlen;
  word ts;

  // update key from prelen pos with chars
  k[0]= prelen+bytelen;
  while(bytelen--) *w++= *p++;

  // ts is last 2 bytes (bigendian)
  ts= (w[-2] << 8) + w[-1];
  
  t= *p++;
  dlen= *p++;

  // print full prefix key
  printkey(k);

  printf(": T%5d %02x [%d]\"", ts, t, dlen);
  while(dlen--) printchar(*p++);
  printf("\"\n");
}

void printpage(Page *page) {
  char * p= (void*)page, * o= p+255;
  char k[256]= {0}; // key for iteration

  printf("-- Page: next=%.4s up=%.4s free=%d n=%d\n",
         page->next, page->up, page->ofree, page->n);
  while(*o) printentry(k, p+*o--);
}

void osput(char* h, char t, char* d, word len) {
  // TODO: find right page using index
  char * p= (void*)&page;
  
  // find right entry of combined key h
}

int main() {
  assert(sizeof(Page)==256);
  char* h= oshandle("/foo", "", 4711);
  osput(h, 1, "FOO", 3);
  free(h);
  printpage((void*)&page);
  return 0;
}

