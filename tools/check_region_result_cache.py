#!/usr/bin/env python3
"""Geometry-cache mutation, relocation, capacity and eviction checks under ASan/UBSan."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile

ROOT = Path(__file__).resolve().parents[1]
CODE = r'''
#include <cassert>
#include <cstdint>
#include <cstring>
#include <vector>
#include "src/mac/RegionResultCache.h"
#include "src/mac/PolygonRegion.h"
#include "src/mac/RegionExpand.h"
int main() {
 RegionResultCache::Cache cache;PolygonRegion::Scratch scratch;
 uint8_t polygon[30],region[4096],expanded[4096],out[4096];uint16_t n,m,got=0;
 auto word=[](uint8_t* p,uint16_t v){WindowGeometry::word(p,v);};
 const int16_t vertices[]={0,0,0,20,20,20,20,0,0,0};
 word(polygon,30);word(polygon+2,0);word(polygon+4,0);word(polygon+6,20);word(polygon+8,20);
 for(int i=0;i<10;++i)word(polygon+10+i*2,vertices[i]);
 assert(PolygonRegion::encode(polygon,30,region,sizeof region,n,scratch));
 assert(RegionExpand::one(region,n,expanded,sizeof expanded,m));
 cache.put(1,polygon,region,n);cache.put(2,region,expanded,m);
 assert(cache.get(1,polygon,30,out,sizeof out,got)&&got==n&&!memcmp(out,region,n));
 assert(cache.get(2,region,n,out,sizeof out,got)&&got==m&&!memcmp(out,expanded,m));
 // A moved handle has the same geometry; a reused address with changed bytes does not.
 std::vector<uint8_t> moved(polygon,polygon+30);
 assert(cache.get(1,moved.data(),moved.size(),out,sizeof out,got));
 for(unsigned i=0;i<30;++i) {
  moved[i]^=1;memset(out,0xa5,sizeof out);got=0;
  assert(!cache.get(1,moved.data(),moved.size(),out,sizeof out,got));
  assert(!got);for(auto byte:out)assert(byte==0xa5);moved[i]^=1;
 }
 for(unsigned i=0;i<n;++i) {
  region[i]^=1;assert(!cache.get(2,region,n,out,sizeof out,got));region[i]^=1;
 }
 assert(!cache.get(2,polygon,30,out,sizeof out,got));
 assert(!cache.get(1,polygon,29,out,sizeof out,got));
 assert(!cache.get(1,polygon,30,out,n-1,got));
 assert(!cache.get(1,nullptr,30,out,sizeof out,got));
 // Force both slot and arena wrap. Every surviving hit must be the complete
 // result associated with its exact key; old arena overlaps must be misses.
 std::vector<std::vector<uint8_t>> keys,values;
 for(unsigned i=0;i<100;++i) {
  keys.emplace_back(10+i%7*100,0);auto& key=keys.back();word(key.data(),key.size());word(key.data()+2,i);
  values.emplace_back(10+i%11*300,uint8_t(i));auto& value=values.back();
  cache.put(3,key.data(),value.data(),value.size());
  assert(cache.get(3,key.data(),key.size(),out,sizeof out,got));
  for(unsigned j=0;j<=i;++j)if(cache.get(3,keys[j].data(),keys[j].size(),out,sizeof out,got))
   assert(got==values[j].size()&&!memcmp(out,values[j].data(),got));
 }
 assert(!cache.get(1,polygon,30,out,sizeof out,got));
}
'''

with tempfile.TemporaryDirectory(prefix='aitd-region-cache-') as folder:
    source = Path(folder)/'check.cpp'
    binary = Path(folder)/'check'
    source.write_text(CODE)
    subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++11', '-Wall', '-Wextra',
                    '-fsanitize=address,undefined', '-iquote', str(ROOT), str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print('PASS region-result cache: exact output, every-byte mutations, moved/reused storage, truncation, capacity and eviction')
