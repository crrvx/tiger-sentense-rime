-- 反查注释必须逐字等于 codes.txt 中该单字的全部编码(源序=名次序)。
local repo=arg[1] or "."
package.path=repo.."/lua/?.lua;"..package.path
rime_api={get_user_data_dir=function()return repo end}
local sentence=dofile(os.getenv('TIGER_SENTENCE_MODULE') or (repo..'/lua/tiger_sentence.lua'))
local checks=0
local function check(ok,msg)checks=checks+1;assert(ok,msg)end
sentence.set_model_enabled(false)
sentence.ensure_lexicon(nil)

-- 独立解析 codes.txt(镜像 parse_codes_content 语义),建立单字期望映射。
local content=assert(io.open(repo.."/tiger_sentence.codes.txt","rb")):read("*a")
content=content:gsub("^".."\239\187\191",""):gsub("\r\n","\n")
local expected,order,seen={}, {},{}
for line in content:gmatch("[^\n]+") do
    if line:sub(1,1)~="#" and line:match("%S") then
        local word,code=line:match("^(%S+)%s+(%S+)")
        if word and code then
            code=code:lower()
            if code:match("^[a-z]+$") then
                local chars=0
                for _ in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars=chars+1 end
                local key=word.."\0"..code
                if chars==1 and not seen[key] then
                    seen[key]=true
                    local list=expected[word]
                    if not list then list={} expected[word]=list order[#order+1]=word end
                    list[#list+1]=code
                end
            end
        end
    end
end
check(#order>=1000,'unexpectedly few single-character entries: '..#order)

-- 全表逐字比对注释文本与顺序。
local multi
for _,word in ipairs(order) do
    local got=sentence.reverse_comment(word)
    check(got==" "..table.concat(expected[word]," / "),"reverse comment mismatch: "..word)
    if not multi and #expected[word]>1 then multi=word end
end
check(multi,'no multi-code character found for ordering coverage')
check(#expected[multi]>1,'multi-code character lost codes')

-- 未收录文本与多字词:无注释。
check(sentence.reverse_comment("Z")==nil,'non-entry text must have no comment')
local sample_word
for line in content:gmatch("[^\n]+") do
    local word,code=line:match("^(%S+)%s+(%S+)")
    if word and code and code:match("^[a-z]+$") then
        local chars=0
        for _ in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars=chars+1 end
        if chars>1 then sample_word=word break end
    end
end
check(sample_word,'no multi-character word found in codes table')
check(sentence.reverse_comment(sample_word)==nil,'word candidates must not be annotated')

print(string.format('OK reverse lookup comments: %d checks, %d single-character entries, multi-code sample: %s',
    checks, #order, multi))
