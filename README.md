# DAFS65

(just started, nothing here, go elsewhere ;)

DAFS65 is a simple data(base) filesystem for 6502. It's prototyped for ORIC ATMOS to enable simple C-programs to have an resemblence of file access.

## Design goals

- bootable on most emulators/ORICs
- usable/testable in emulators for rapid prototyping
- available on as many ORICs as possible
- particularly usable on LOCI
- simplicity in interface
- simplicity in implementation
- assume "hosted" storage on flash-filesystem
- C-unix type API for file access
- path/filename like access
- implemented using a new keyvalue store aka bigtable/leveldb
- host buildable disks
- updatable disks
- data extractable

Specifically:

- <stdlib.h> - open/creat/write/read/lseek
- <stdio.h> implementation of:
  - fopen/fclose/flush/fread/fwrite
  - fgetc/fputc/fputs/fgets
- keyvalue store
  - simple "bigtable"/"leveldb"-style data storage
  - get/put/prefix/range access
- crash-proof (keep consistency)
- (transactions?)

## Non-goals!

- No traditional directory structure
- No dos/fat system
- Efficiency in updates on physical disk
- Not readable by SEDORIC or other operating systems!

## Why not other solutions

There are many variants of storage systems, each have it's own quirks or limitations.

This list isn't exhaustive or complete:

- TAP: tap-files are simple and great for sequentially accessed data; no random access
- MICRODISK: gave the so called DSK, seemingly well supported in emulators.
- SEDORIC: is a variant (?) of microdisk, seems to be using mfm format.
- JASMINE: niche, but not much avaible (French?)
- TWILITE-BOARD/ORIX(?): ORIX is a nice linux style system, but seems to be linked and require the elusive twilite-board, that is somewhat expensive and according to some unreliable.
- CUMULUS: sd-card: using DSK files (?)
- CUMANA REBORN: physical floppy interface 
- LOCI: loci is the newest hottest HARDWARE solution, but has no known emulator support as of today (DEC-2025). However, it has the ability to mount a TAP-file, or up to 4 DSK files, in addition it can with it's native interface provide access to its directories using open/close/read/write/lseek/readdir using filedescriptors ala UNIX!

- tap2dsk: takes a bunch of tap-files and makes a bootable(? SEDORIC) DSK!
- old2mfm: not sure, but SEDORIC requires MFM-style disks?
- FloppyBuilder: is a great tool to build a CD-ROM style DSK in propetrary format for demos/games. Uses simple hardcoded sector/ranges for the exten of files. Only support direct read of sector, or load/File

Regarding the floppy-builder it seems =Oric-Software/users/chema/Blakes7/Sources/floppycode/loader.asm= has the latest code to read and *write* a sector and load/run *one* "program" file at boot.

Operating systems:
- SEDORIC: the asm source code as been recreated without comments
- FT-DOS: also by ORIC corp
- JASMINE: possibly open-source (?)
- CP/M-65: open source implementation, uses DSK
- ORIX: unix style, open source, quite a lot of minimal standard utilties

For something to work on all platforms it seems reasonable to be based on DSK-format (possibly converted to m2m - not clear if this is required?). Bootable DSKs have provision for support by the most hardware and emulator solutions.

## Inspired by

It's based on ideas and some asm code of FloppyBuilder for booting a floppy from the OSDK (ORIC SDK C-compiler). We also, initially, use various OSDK disk and tape utilities.

## Utilities

- tap2dsk (from OSDK)
- old2mfm (from OSDK)
- mktap (jsk): mktap FIL startaddr > FIL.tap

# References

- How are DSK files stored - https://wiki.defence-force.org/doku.php?id=oric:hardware:dsk_disk_format#:~:text=all%20data%20of%20the%20first,with%20a%20256%2Dbyte%20header:
- cpm-86 oric DSK boot-code: jasmine+microdisk - https://github.com/davidgiven/cpm65/blob/master/src/arch/oric/oric.S




