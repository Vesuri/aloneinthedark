# Eight-bit intro copy

The first original intro CopyBits displays the Infogrames logo. Misc2+$24D2
calls it with bytes `20502f102047486800022f0b486b0008426742a7a8ec`
at +$24BE. Arguments are a direct source PixMap, destination game-port bitmap,
(0,0)–(200,320) source and destination rectangles, srcCopy and nil mask.
The source is a locked 648×401 GWorld, stride 652. The destination uses the
640×480 logical screen with local bounds (-150,-160)–(330,480), a 320×200 port
and visibility rectangle, and the broad rectangular clip. The Mac returns D0=0,
pops 22 bytes and preserves D2–D7/A2–A6; D1/A0/A1 are scratch.

Source and destination tables have the same ctSeed even though their stored
RGB entries differ. As in Vette, that means preserve indices. `CopyBits8.h`
uses Vette's unscaled clipping equations with byte pixels, bounded buffer sizes
and explicit translated dirty bounds. The dispatcher accepts this owned locked
GWorld-to-visible-window form. Other modes, masks, scaling, source/destination
forms or unequal colour seeds remain loud stops pending measured contracts.

`mac_copybits8.lua` and the read-only `copybits8_call.gdb` capture the actual
call. `check_copybits8.py` independently computes every destination byte and
checks source/records unchanged, caller bytes/ABI, paired source pixels and
complete 64,000-byte client plus both CLUTs. The source has four padding bytes
per row outside its 648-pixel bounds: all 1,604 differ between Mac and native,
but neither platform changes them and they are not copied. All source pixels
inside the bounds match. The ninth AGA publication contains the exact logo.

Accepted runs are `tmp/m2-copybits8-reference.log` and
`tmp/m2-copybits8-native-final.log`, both terminal exit zero:

```
python3 tools/check_copybits8.py tmp/m2-copybits8-reference.log --status 0
python3 tools/check_copybits8.py tmp/m2-copybits8-native-final.log --status 0 --native
python3 tools/check_aga_capture.py startup tmp/m2-copybits8-native-final.log --status 0
```

The helper has 61 full-buffer clipping fixtures, including negative coordinates,
source-edge clipping and row padding, plus rejected scaling/capacity checks;
`make host-tests` runs them with address/undefined-behaviour sanitizers. The
helper also matches the complete original reference destination capture.

Startup next stops at native driver selector 22, Core+$1A74. Its service is in
progress (464 entered / 463 completed, active=1, trap $A0F8); this is an explicit
unsupported call, not balanced-service or successful-intro acceptance. Original
MDRV is absent. Logo matching here is evidence for M2.10, whose general frame
comparator, fixed-seed state keys and complete intro regression remain pending.
