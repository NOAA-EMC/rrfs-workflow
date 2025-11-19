
local fn      = myFileName()
local module  = myModuleFullName()
local loc     = fn:find(module,1,true)-2
local mdir    = fn:sub(1,loc)
local pkg     = pathJoin(mdir, "/qrocoto")

--LmodMsgRaw("debug-fn:"..fn..'\n')
--LmodMsgRaw("debug-module:"..module..'\n')
--LmodMsgRaw("debug-loc:"..loc..'\n')
--LmodMsgRaw("debug-mdir:"..mdir..'\n')
--LmodMsgRaw("debug-pkg:"..pkg..'\n')

prepend_path("PATH",pkg)
