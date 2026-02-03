// insert data in a page prefix compressed sstable
//
// On 6502 we cannot expand and use more data,
// thus need to search the prefix compressed format.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// (- 6121 5212) 909 bytes saved - no printf/etc
//
#define PRINT

#ifdef PRINT
  #include <stdio.h>
//  #include <ctype.h>
#endif // PRINT

typedef uint16_t word;

// almost a str2pascal?
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
typedef pstr handle;

// to be used by all
static char key[256]= {0};

void clearkey() {
  memset(key, 0, sizeof(key));
}

//   maybe use pascal strings? lol
handle oshandle(char* k, char* c, word ts) {
  char * p= key;
  
  if (strlen(k)+strlen(c)+2 > 255) return NULL;

  clearkey();

  // copy key, zero terminate
  while(*k) *p++= *k++;
  ++p;

  // copy column, zero terminate
  while(*c) *p++= *c++;
  ++p;
  
  // store timestamp searchable
  *p++= ts >> 8;
  *p++= ts & 0xff;

  return memdup(key, p-key);
}

typedef char PageRef[4];

#define PAGE_ENTRIES 20

typedef struct Page {
  PageRef next, up; // 8 B
  char ofree; // 1
  char n; // 1
  //char reserved[6];
  char data[256-8-2-PAGE_ENTRIES]; // start at 10 ??? or 16
  // offsets of ordered prefixed compressed entries
  // bigger grows down
  char offsets[PAGE_ENTRIES];
} Page;

#define PAGE_OFREE_OFFSET offsetof(Page, data)
#define PAGE_DATA_LEN (256-offsetof(Page, data)-PAGE_OFREE_OFFSET)

Page page = {"NEXT", "UBER",
  PAGE_OFREE_OFFSET+26+13+14, 1,
  // (- 256 8 2 20) = 226
  {
    0, 15, '/','r','o','w','/','k','e','y',0,
           'c','o','l',0,
           0xff,0xfd,
    1, 0x06,'f','o','o','b','a','r',0, 
    // 26 bytes

    13, 2, 0xff, 0xfe, // only change ts
    1, 0x06,'F','o','o','b','a','r',0, // one letter
    // 13 bytes

    10, 5, 'p','p',0,
           0xff,0xfd,
    1, 0x05,'C','+','+','-','-',0, 
    // 14 bytes

  },
  { 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0,
    0,
    0, // +14
    PAGE_OFREE_OFFSET+26+13,
    PAGE_OFREE_OFFSET+26,
    PAGE_OFREE_OFFSET
    }
};
  
void applykey(char* k, char* p) {
}

#ifndef PRINT
void printpage(Page* p) {}
#else

void printchar(char c) {
//  if (isprint(c)) putchar(c); // cc65 is wrong...
  if (c>=' ' && c<127) putchar(c);
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

  printf("-- Page: next=%.4s up=%.4s free=%d n=%d\n",
         page->next, page->up, page->ofree, page->n);

  clearkey();
  while(*o) printentry(key, p+*o--);
}
#endif // PRINT


void pagesplit(Page *p, char i, char o, handle h) {
  // TODO: does this return new page?
  // who inserts the item? (and where?)

  // How to make it split where lots of inserts
  // are happening?
  // The idea is to make hotspot (append location)
  // be really efficient, preferring it to be at end?
  // (actually, insering "before first" in new page
  //  may be more  efficient? - no need search much!)
  // if stuff after is substantia, maybe move that to
  // a third page?
}

Page* ospage(handle h) {
  // TODO:
  return &page;
}

// Is "next key" greater than the Handle key?
// (don't apply as we can't use it for prefix calc)
char keygt(char* o, handle h) {
  // TODO: be clever!
  return 1;
}

char pageindex(Page *page, char* key, handle h) {
  char * p= (void*)page;
  char i= 0, o;

  // TODO: right?
  clearkey();

  while((o= p[--i])) {
    // once we get a pagekey >= that's the insert point
    if (keygt(p+o, h)) break;
    applykey(key, p+o);
  }

  return i;
}

char hprefixlen(handle h, char* key, char* o) {
  // TODO: implement
  assert(0);
  return 0;
}


// TODO: error code/
void osput(handle h, char t, char* d, word len) {
  // TODO: find right page using index
  Page * page= ospage(h);
  char i= pageindex(page, key, h), j;
  char o= page->ofree, w= o;
  char * p= (void*)page;

  // prefix compress
  char byteslen= h[0];
  char prelen= hprefixlen(h, key, p+p[i]);

  // fits?
  // (we don't know compression size yet...)
  // TODO: 
  if (len+6+byteslen > PAGE_DATA_LEN)
    pagesplit(page, i, o, h);

  // write entry
  p[w++]= prelen;
  p[w++]= byteslen;
  p[w++]= t;
  p[w++]= len >> 8;
  p[w++]= len & 0xff;
  while(len--) p[w++]= *d++;
  p[w++]= 0;
      
  page->ofree= w;

  // patch it in at i
  for(j=256-PAGE_ENTRIES; j>i; --j) p[j]= p[j-1];
  p[i]= o;

  // TODO:
  //writepage...
}

// TODO: osappend? lol

// TODO: error code/
word osget(handle h, word offset, char* buff, word len) {
  return 0;
}

int main() {
  char* h= oshandle("/foo", "", 4711);

  assert(sizeof(Page)==256);

//  osput(h, 1, "FOO", 3);

  free(h);
  printpage((void*)&page);
  return 0;
}
