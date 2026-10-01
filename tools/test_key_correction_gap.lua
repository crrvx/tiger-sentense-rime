-- Experiment-only score-gap contracts; mainline defaults are unchanged.
local pack=arg[1] or '.'
package.path=pack..'/lua/?.lua;'..package.path
local c=require('tiger_sentence_correction')
local checks=0
local function check(ok,msg)checks=checks+1;assert(ok,msg)end
c.profiles.gaptest={seeds=8,one=16,two=8,steps=4096,delta_one=2,delta_two=3}
c.configure('gaptest')
local exact={{text='正码',score=1000},{text='另一正码',score=-1000}}
local bucket={{text='单一',score=0,correction_count=1},{text='单二',score=-2,correction_count=1},
    {text='单三',score=-2.001,correction_count=1},{text='双一',score=-100,correction_count=2},
    {text='双二',score=-103,correction_count=2},{text='双三',score=-103.001,correction_count=2}}
local r=c.current(bucket,exact,10)
check(#r==6,'wrong independent budget cutoffs')
check(r[1].text=='单一' and r[2].text=='单二','single gap boundary')
check(r[3].text=='双一' and r[4].text=='双二','double group compared to wrong pool')
check(r[5]==exact[1] and r[6]==exact[2],'exact states changed')
check(#bucket==6 and #exact==2,'input buckets changed')
c.profiles.gaptest.delta_one=nil;c.profiles.gaptest.delta_two=nil
check(#c.current(bucket,exact,10)==8,'disabled gap changed count-only behavior')
check(#c.current({},exact,10)==2,'empty correction group lost exact states')
print(string.format('{"gap_unit_checks":%d}',checks))
