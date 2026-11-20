# ECM companion repositories

Mirrors of C. Masloch's (ecm) Mercurial repositories that the lDOS,
ECM EDR-DOS and RxDOS builds use as sibling directories (LMACROS_DIR,
LDOSBOOT_DIR, ... in their cfg.sh), one subdirectory each:

- lmacros/  https://hg.pushbx.org/ecm/lmacros
- ldosboot/  https://hg.pushbx.org/ecm/ldosboot
- scanptab/  https://hg.pushbx.org/ecm/scanptab
- crc16-t/  https://hg.pushbx.org/ecm/crc16-t
- bootimg/  https://hg.pushbx.org/ecm/bootimg
- instsect/  https://hg.pushbx.org/ecm/instsect
- inicomp/  https://hg.pushbx.org/ecm/inicomp
- mktmpinc/  https://hg.pushbx.org/ecm/mktmpinc

Maintained by ../sync/sync.py (`python sync.py ecm`): each source is
converted with hg-git (sync/hg/ecm/<name>), fetched as remote <name>
(branches <name>/main, <name>/hg/<branch>; tags <name>/<tag>), and its
main branch merged into <name>/ with `git subtree merge`, so the
original commits keep their hashes.  Do not edit the subdirectories here.
