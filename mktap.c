// Gentap - generate .tap file for ORIC ATMOS

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>


#define SCREEN     0xbb80
#define SCREENSIZE 28*40

void mktap(char* name, unsigned int start, unsigned int end, FILE* in) {
  // write header

  // - sync (many only use 4!)
  for(int i=0; i<128; ++i) putchar(0x16);
  putchar(0x24);

  // - reserved (2)
  putchar(0);
  putchar(0);

  // - 0=BASIC, $80= machinecode
  putchar(0x80);

  // - 0=no autorun, $c7=autorun (basic/machiencode)
  putchar(0);

  // - EndAddress (hi,lo!)
  putchar(end >> 8);
  putchar((char)end);

  // - StartAddress (hi,lo!)
  putchar(start >> 8);
  putchar((char)start);

  // - "varies" unused
  putchar(0);

  // - Name (zero terminated)
  fputs(name, stdout);
  putchar(0);

  // write data
  
  int c;
  long n= 0;

  while((c=fgetc(in))!=EOF) {
    putchar(c);
    ++n;
  }

  if (n!=end-start+1) {
    fprintf(stderr, "%% File size wrong n!=end-start n=%ld start=%d end=%d\n", n, start, end);
  }
}


int main(int argc, char** argv) {
  if (argc!=3) {
    fprintf(stderr, "%% Usage: mktap FIL address > FIL.tap\n");
    exit(1);
  }

  char *name= argv[1];

  FILE* in= fopen(name, "r");
  if (!in) {
    perror("%% No such file\n");
    exit(1);
  }
  if (strlen(name)>16) {
    fprintf(stderr, "%% Filename too long (>16 chars)\n");
    exit(1);
  }
           
  fseek(in, 0, SEEK_END);
  long size = ftell(in);
  fseek(in, 0, SEEK_SET);
  
  // avoid first line!
  int start= atoi(argv[2]);
  int end  = start+size-1;
  
  if (end < start) {
    fprintf(stderr, "%% file address + size > 64k\n");
    exit(1);
  }

  if (end > 65536) {
    fprintf(stderr, "%% file address + size > 64k\n");
    exit(1);
  }

  mktap(name, start, end, in);

  fclose(in);
}
