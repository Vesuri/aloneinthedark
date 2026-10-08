#ifndef AITD_STACK_PROBE_H
#define AITD_STACK_PROBE_H
#ifdef AITD_STACK_PROBE
void aitdStackProbeBegin();
void aitdStackProbeMacBegin(uint8_t*,uint32_t);
void aitdStackProbeMacEnd(uint8_t*,uint32_t);
void aitdStackProbeEnd();
#else
inline void aitdStackProbeBegin() {}
inline void aitdStackProbeMacBegin(uint8_t*,uint32_t) {}
inline void aitdStackProbeMacEnd(uint8_t*,uint32_t) {}
inline void aitdStackProbeEnd() {}
#endif
#endif
