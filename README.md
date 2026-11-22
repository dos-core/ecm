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

This is periodically re-sync'd from upstream Mercurial repositories via local sync.py which fetches remotes and converted via hg-git along with git subtree merge to maintain original commits but combine into single git repository.  This is a mirror only! Do not edit the subdirectories here.  Any PR to this repository will be closed, please reach out to upstream developer with patches.
