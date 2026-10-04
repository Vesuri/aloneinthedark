# Documentation

Start with the [project README](../README.md). **M3.1–M3.3 are complete for
the verified routes; M3.4 is next.**
Use [open work](open-work.md) for current status and the
[development checks](development.md) for evidence.
Subsystem documents retain historical diagnostic checkpoints, explicitly
separated from their current status. The M1.7b2 system-window rendered fixture
remains deferred independently of M2.

- [Design](design.md): the port plan: architecture, owner decisions,
  verification, phases and workflow.
- [Development](development.md): build tools, local data, running and debugging.
- [AGA display](aga-display.md): eight-plane output, colour transfer and fixtures.
- [CopyBits](copybits.md): intro copies and partial-frame presentation.
- [File Manager](file-manager.md): measured file contracts and PAK-read acceptance.
- [Window geometry](window-geometry.md): hidden windows and viewport placement.
- [Amiga architecture](amiga-arch.md): runtime, display, input, audio and cleanup.
- [Original-data extraction](install-original-data.md): how the original
  release unpacks into the files the port reads.
- [Source inventory](source-inventory.md): original application/resource layout.
- [Static map](static-map.md): CODE segments, A5 world and CPU requirements.
- [Macintosh reference](mac-reference-loop.md): local oracle setup and capture.
- [Offscreen worlds](gworld.md): owned eight-bit worlds and measured inverse colour tables.
- [RGB drawing colours](color-drawing.md): offscreen RGB/index state and inverse-ring lookup.
- [Rectangle operations](rectangles.md): measured signed bounds, aliasing and original image preparation.
- [Graphics device](graphics-device.md): measured original selection and display records.
- [Screen choice](screen-choice.md): hidden fixed-size selection and original contracts.
- [SANE positioning](sane.md): integer-only arithmetic, original inputs and verification.
- [Menu records](menu-manager.md): original counts, labels and native mutations.
- [Game interfaces](game-interfaces.md): reached new-game/save/load UI, hidden chooser and dialog coverage.
- [Sound driver](sound-driver.md): original startup contract and native D8 seam.
- [Font Manager](font-manager.md): measured font lookup contract and reference probes.
- [Apple Events](apple-events.md): original registration and table-state contracts.
- [Colour table](color-table.md): Mac/native GetCTable bytes, ownership and seed contracts.
- [Palette](palette.md): Mac/native NewPalette records, copying and disposal contracts.
- [Window titles](window-title.md): hidden title ownership, measured advances and paired effects.
- [Open work](open-work.md): the ordered work queue.

The Vette! repository (`~/Documents/Vette/docs`) holds the complete versions of
material this port inherits: frame pacing, WHDLoad, installer design, Macintosh
display model and the regression approach.

- [Startup events](events.md): activation, update and idle-event contracts.
- [Cursor obscuring](cursor.md): logical visibility, hide state and movement restoration.
