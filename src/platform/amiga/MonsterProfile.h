#ifndef AITD_MONSTER_PROFILE_H
#define AITD_MONSTER_PROFILE_H
#if defined(AITD_MONSTER_PROFILE) || defined(AITD_MONSTER_AUDIT)
struct MonsterProfileFrame {
    uint32_t scene, ticks, effects;
    uint16_t fields, song;
    int16_t carnby, monster, monster1c, monster20;
    uint16_t room, camera;
};
static_assert(sizeof(MonsterProfileFrame)==28,"monster trace wire format");
#ifdef AITD_MONSTER_AUDIT
const unsigned kMonsterFrameCapacity=16384;
#else
const unsigned kMonsterFrameCapacity=3001;
#endif
extern "C" {
extern volatile MonsterProfileFrame g_monsterFrames[kMonsterFrameCapacity];
extern volatile uint32_t g_monsterCount, g_monsterPhase;
void aitdMonsterFrame();
}
#endif
#ifdef AITD_MONSTER_AUDIT
extern "C" { extern volatile uint32_t g_monsterAudit[16]; }
void aitdMonsterAuditBegin();
bool aitdMonsterAuditSave(bool cleanupOK);
#endif
#endif
