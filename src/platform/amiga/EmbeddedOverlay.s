| Port-owned resources, linked verbatim into the executable. Never original data.
	.section .rodata.embedded_overlay,"a"
	.balign 4
	.global g_embeddedOverlay
	.global g_embeddedOverlayEnd
g_embeddedOverlay:
	.incbin "../resources/overlay.rsrc"
g_embeddedOverlayEnd:
	.balign 4
