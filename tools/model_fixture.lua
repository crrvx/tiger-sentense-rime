-- A small valid paged KN fixture with independent float32-rounded tables.
-- No text corpus or production-model quality claim is associated with it.
local function make(path, extra_tokens)
    assert(string.pack and string.unpack, "binary fixtures require Lua 5.3+")
    local stride, shift = 16, 2097152
    local function f32(v)return (string.unpack("<f",string.pack("<f",v)))end
    local tokens={0,2,3,65,127,128,2047,2048,0x4e00,0x4e59,0x4eba,0x4f60,0x5929,
        0x597d,0x6211,0x662f,0x7532,0x7684,0x8bdd,0x9fff,0x10000,0x1f600,0x20000,0x10ffff}
    -- Optional larger fixture exercises the second-level sparse index and its
    -- page boundaries; the default fixture remains byte-for-byte unchanged.
    for i=1,(extra_tokens or 0) do tokens[#tokens+1]=0x30000+i end
    if extra_tokens then table.sort(tokens) end
    local uni,bi,tri={}, {}, {}
    local uni_bytes={}
    for i,ch in ipairs(tokens)do
        uni[ch]=f32(i==1 and 1e-7 or i/#tokens/30)
        uni_bytes[#uni_bytes+1]=string.pack("<i4f",ch,uni[ch])
    end
    local function successors(seed)
        local values={}
        for i,ch in ipairs(tokens)do
            if (i+seed)%3==0 then values[ch]=f32((i+seed)%7==0 and 0 or ((i+seed)%11)/37) end
        end
        return values
    end
    for i,ch in ipairs(tokens)do
        if i%5~=0 then bi[ch]={lambda=f32((i%4)/4),values=successors(i)} end
        for j,second in ipairs(tokens)do
            if (i+j)%3==0 then tri[ch*shift+second]={lambda=f32((i+j)%5/5),values=successors(i+j)} end
        end
    end
    local function keys(values)
        local result={};for key in pairs(values)do result[#result+1]=key end;table.sort(result);return result
    end
    local function section(values,offset)
        local chunks,index={},{}
        local order=keys(values)
        local size=0
        for i,key in ipairs(order)do
            if (i-1)%stride==0 then index[#index+1]=string.pack("<I8I8",key,offset+size) end
            local row=values[key];local following=keys(row.values)
            local chunk={string.pack("<I8fI4",key,row.lambda,#following)}
            for _,target in ipairs(following)do chunk[#chunk+1]=string.pack("<I4f",target,row.values[target]) end
            chunk=table.concat(chunk);chunks[#chunks+1]=chunk;size=size+#chunk
        end
        return table.concat(chunks),table.concat(index),#order,#index
    end
    local unigrams=table.concat(uni_bytes)
    local bi_start=104+#unigrams
    local bb,bx,bc,bxc=section(bi,bi_start)
    local bx_start=bi_start+#bb
    local tri_start=bx_start+#bx
    local tb,tx,tc,txc=section(tri,tri_start)
    local tx_start=tri_start+#tb
    local size=tx_start+#tx
    local header="TCSKNM02"..string.pack("<I4I4I8I4I4I4I4I8I4I4I8I8I8I4I4I8I8",
        1,104,size,stride,0,#tokens,0,104,bc,bxc,bi_start,bx_start,tc,txc,0,tri_start,tx_start)
    local file=assert(io.open(path,"wb"));assert(file:write(header,unigrams,bb,bx,tb,tx));file:close()
    local function scalar(text)if text=="" then return 0 end;return utf8.codepoint(text)end
    local function logp(prev2,prev1,target)
        local first,second,third=scalar(prev2),scalar(prev1),scalar(target)
        local unigram=uni[third] or uni[0]
        local b=bi[second]
        local bigram=(b and b.values[third] or 0) + (b and b.lambda or 1)*unigram
        local t=tri[first*shift+second]
        local probability=(t and t.values[third] or 0)+(t and t.lambda or 1)*bigram
        return math.log(math.max(probability,1e-300))
    end
    return {tokens=tokens,logp=logp,bytes=size,
        observed=function(prev,target)local row=bi[scalar(prev)];return row~=nil and row.values[scalar(target)]~=nil end}
end
return make
