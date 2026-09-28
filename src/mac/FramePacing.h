#pragma once
// Fixed-width types come from the platform header (stdint.h in host tests).

// One pacer per authored animation stream: one boundary per animation step,
// not per draw call.  Vette identified its streams by (segment, offset, trap)
// of the loop's Toolbox call; Alone in the Dark's streams are not mapped yet.
struct FramePacer {
    uint16_t field;
    bool started;
    bool needsWait(uint16_t now) const { return started && field == now; }
    void advance(uint16_t now) { field = now; started = true; }
};

