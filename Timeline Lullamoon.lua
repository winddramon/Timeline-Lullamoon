--[[
           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                   Version 2, December 2004

Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>

Everyone is permitted to copy and distribute verbatim or modified
copies of this license document, and changing it is allowed as long
as the name is changed.

           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

 0. You just DO WHAT THE FUCK YOU WANT TO.

--]]

--[[
	
	Author: Yoshiko_G
	Special Thanks to: TNBi, DracoRunan
--]]

script_name = "TimeLine Lullamoon"
script_description = "1.以卡拉OK标签自动隔断宽字符  2.将隔行歌词首尾对齐，并自动修正冲突的时间间隔，从而把单行卡拉OK转化成双行  3.在特效字段生成用空格隔断的音节文本，也可以将音节文本反贴回歌词字幕"
script_author = "Yoshiko_G"
script_version = "0.49"

tr = aegisub.gettext

include("unicode.lua")

UI_conf = {
	--[[
	main_dialogs = {
		info = {
			class = "label",
			x = 0, y = 0, width = 1, height = 1,
			label = "请选择功能：\nWide-Character：以宽字符（如汉字）为单位分出歌词音节；\nDouble-line：单行卡拉OK转化成双行。\nSyllaTexts：生成音节文本或根据音节文本修改字幕" 
		}
	},
	main_buttons = {'Wide-Character','Double-line','SyllaTexts','Exit'},
	main_commands = {
		function(subs,sel,config) kara_parse_wchar(subs, sel) end,
		function(subs,sel,config) main("kara_parse_double", subs, sel) end,
		function(subs,sel,config) main("kara_swift", subs, sel) end,
		function(subs,sel,config) end,
	},
	--]]
	
	double_dialogs = {
		info = {
			class = "label",
			x = 0, y = 0, width = 3, height = 1,
			label = "" 
		},
		{
			class = "label",
			x = 0, y = 1, width = 1, height = 1,
			label = "预显:"
		},
		{
			class = "intedit", name = "timeadv",
			x = 1, y = 1, width = 1, height = 1,
			hint = "每句歌词预先显示的时间，单位为毫秒",
			value = 1000, min = 1, max = 20000
		},
		{
			class = "label",
			x = 2, y = 1, width = 1, height = 1,
			label = "ms"
		},
		{
			class = "label",
			x = 0, y = 2, width = 1, height = 1,
			label = "延后:"
		},
		{
			class = "intedit", name = "timepass",
			x = 1, y = 2, width = 1, height = 1,
			hint = "每句歌词延后显示的最长时间，单位为毫秒",
			value = 1000, min = 1, max = 20000
		},
		{
			class = "label",
			x = 2, y = 2, width = 1, height = 1,
			label = "ms"
		},
		{
			class = "checkbox", name = "fn1",
			x = 0, y = 3, width = 1, height = 1,
			value = true
		},
		{
			class = "label",
			x = 1, y = 3, width = 1, height = 1,
			label = "自动修正时间轴冲突" 
		}
		
	},
	double_buttons = {'Parse!','Cancel'},	
	double_commands = {
		function(subs,sel,config) kara_parse_double(subs, sel, config) end,
		function(subs,sel,config) end
	},
	
	swift_dialogs = {
		info = {
			class = "label",
			x = 0, y = 0, width = 1, height = 1,
			label = "请选择功能：\nCreate：根据实际字幕内容在特效字段生成按音节分割的文本；\nParse：根据特效字段的音节分割文本修改字幕内容。\nClean：清除特效字段。" 
		}
	},
	swift_buttons = {'Create','Parse','Clean','Cancel'},
	swift_commands = {
		function(subs,sel,config) kara_swift(subs, sel, 0) end,
		function(subs,sel,config) kara_swift(subs, sel, 1) end,
		function(subs,sel,config) kara_swift(subs, sel, 2) end,
		function(subs,sel,config) end
	},
	
	wchar_dialogs = {
		info = {
			class = "label",
			x = 0, y = 0, width = 1, height = 1,
			label = "标签类型" ,
		},
		{
			class = "dropdown", name = "tag",
			x = 1, y = 0, width = 1, height = 1,
			items = {"\\kf", "\\k", "\\ko"} ,
			value = "\\kf",
		}
	},
	wchar_buttons = {"OK", "Cancel"},
	wchar_commands = {
		function(subs,sel,config) kara_parse_wchar(subs, sel, config) end,
		function(subs,sel,config) end,
	},
	
	strip_dialogs = {
		info = {
			class = "label",
			x = 0, y = 0, width = 1, height = 1,
			label = "" ,
		},
		{
			class = "checkbox", name = "allstrip",
			x = 0, y = 1, width = 1, height = 1,
			value = false
		},
		{
			class = "label",
			x = 1, y = 1, width = 1, height = 1,
			label = "清除所有卡拉OK音节符" ,
		},
	},
	strip_buttons = {"OK", "Cancel"},
	strip_commands = {
		function(subs,sel,config) kara_strip_tags(subs, sel, config) end,
		function(subs,sel,config) end,
	},
}

function main(mode, subs, sel)
	if mode == "kara_parse_double" then
		showdialog(subs, sel, 'double_dialogs', 'double_buttons', 'double_commands')
	elseif mode == "kara_swift" then
		showdialog(subs, sel, 'swift_dialogs', 'swift_buttons', 'swift_commands')
	end
end


function showdialog(subs, sel, dconf, bconf, cconf, info)
	local button
	local Ud = clone(UI_conf[dconf])
	local Ub = clone(UI_conf[bconf])
	local Uc = clone(UI_conf[cconf])
	if(info) then 
		Ud['info']['label'] = info
		info = ''
	end
	button, config = aegisub.dialog.display(Ud,Ub)
	for i, c in pairs(Uc) do
		if button == Ub[i] then
			c(subs,sel,config)
			break
		end
	end
end

--[[
function entry(subs, sel)
	showdialog(subs, sel, 'main_dialogs', 'main_buttons', 'main_commands', '')
end
--]]

function kara_parse_double(subs, sel, config)		
	local flag = {
		[1] = 0,
		[2] = 0,
		[3] = 0,
	}
	local timeadv = config.timeadv
	local timepass = config.timepass
	local s = {}
	local durations = {}--前移时间
	
	for i = 1, #sel do
		-- 第一步 时间间隔全部前移指定时间
		s[i] = subs[sel[i]]
		s[i].start_time = s[i].start_time - timeadv
		--s[i].name = string.format("%s,%s",s[i].start_time,s[i].end_time)
		durations[i] = timeadv	
		flag[1] = flag[1] + 1
	end
	
	for i = 1, #sel do		
		-- 第二步 此行结束时间延长到隔行的开始时间
		
		if i <= #sel-2 then
			drt = s[i+2].start_time - s[i].end_time
			if config.fn1 and drt < 0 then--同一位置的前后句时间冲突时
				durations[i+2] = durations[i+2] + drt
				s[i+2].start_time = s[i].end_time
				flag[3] = flag[3] + 1
			else
				if drt > timepass then
					s[i].end_time = s[i].end_time + timepass
				else
					s[i].end_time = s[i+2].start_time
				end				
				flag[2] = flag[2] + 1
			end			
		else
			s[i].end_time = s[i].end_time + timepass
			flag[2] = flag[2] + 1
		end		
	end
		
	for i = 1, #sel do
		-- 第三步 写入各行歌词的前移特效
		s[i].text = string.format("{\\k%d}%s", math.floor(durations[i]/10), s[i].text)
		subs[sel[i]] = s[i]
	end
	
	if flag then
		aegisub.debug.out(0, "命令成功完成。\n前移了%s行。\n通常延长了%s行。\n延长并修正了%s行。", flag[1], flag[2], flag[3])
		
		aegisub.set_undo_point(script_name)
	else
		aegisub.debug.out(0, "没有进行修改")
	end
end

function kara_parse_wchar(subs, sel, config)--宽字符自动区隔音节
	local s = {}
	read_syllables(subs, sel)
	--write_syllables(subs, sel, tp)
	for i = 1, #TLL_syllables do
		local subp = TLL_syllables[i]
		if #subp["syllables"] == 1 and subp["syllables"][1].duration == 0 then--只有在没有音节存在时才执行
			local sw0 = ""
			local sw = {}
			local length = unicode.len(subp.text)
			local j = 1
			for chr in unicode.chars(subp.text) do--利用unicode长度与ascii长度不同来判断是否宽字符/单词，如果是则载入数组，达到区隔音节的目的
				if j >= length then
					table.insert(sw, sw0..chr)
				elseif chr == ' ' and string.len(sw0) > 0 then
					table.insert(sw, sw0..' ')
					sw0 = ''
				elseif unicode.len(chr) ~= string.len(chr) then
					if string.len(sw0) > 0 then
						table.insert(sw, sw0)
						sw0 = ''
					end
					table.insert(sw, chr)
				else
					sw0 = sw0..chr
				end
				j = j + 1
			end
			if #sw == 0 then
				table.insert(sw, sw0)
			end
			local interval = math.floor((subp.end_time - subp.start_time) / #sw)--计算平均间隔时间
			for k,subsw in pairs(sw) do			--写入全局函数
				TLL_syllables[i]["syllables"][k] = {
					duration = interval,
					tag = config.tag,
					text = subsw
				}
			end
		end
	end
	write_syllables(subs, sel)
end

function kara_strip_tags(subs, sel, config)--去除卡拉OK标签但是维持原本的start_time和end_time
	read_syllables(subs, sel)
	for i = 1, #TLL_syllables do
		local subp = TLL_syllables[i]
		local syls = subp["syllables"]
		if syls[#syls].duration > 20 and syls[#syls].text == '' then --先判断尾部，认为时间小于等于20ms的都是占位符不处理
			subp.end_time = subp.end_time - syls[#syls].duration
			table.remove(TLL_syllables[i]["syllables"],#syls)
		end
		if syls[1].duration > 0 and syls[1].text == '' then --再判断头部，避免误修改索引
			subp.start_time = subp.start_time + syls[1].duration
			table.remove(TLL_syllables[i]["syllables"],1)
		end
		if config.allstrip then --清除剩余所有卡拉OK标签但是不修改时间
			local syls_temp = ""
			for j=1, #syls do
				syls_temp = syls_temp..syls[j].text
			end
			TLL_syllables[i]["syllables"] = {
				{
					tag = "\\kf",
					duration = 0,
					text = syls_temp
				}				
			}
		end
	end
	write_syllables(subs, sel)
end

function kara_swift(subs, sel, tp)
	if tp == 0 then
		for i = 1, #sel do
			local sub = subs[sel[i]]--TODO:实际上是引用，这么写没意义
			local subp = subs[sel[i]]
			aegisub.parse_karaoke_data(subp)
			local effect = ''
			for j = 1, #subp do
				effect = effect..subp[j].text..' '
			end
			sub.effect = effect
			subs[sel[i]] = sub
		end
	elseif tp == 1 then
		for i = 1, #sel do
			local sub = subs[sel[i]]
			local subp = subs[sel[i]]
			local subtext = ''
			aegisub.parse_karaoke_data(subp)
			local effect = sub.effect
			if string.len(effect) > 0 then
				effect = LuaSplit(effect,' ')
				for j = 1, #subp do
					subtext = subtext..string.format("{%s%d}%s", subp[j].tag, subp[j].duration/10, effect[j])
					--subtext = subtext..'{'..string.char(92)..subp[j].tag..(subp[j].duration/10)..'}'..effect[j]
				end
			end
			sub.text = subtext
			subs[sel[i]] = sub
		end
	elseif tp == 2 then
		for i = 1, #sel do
			local sub = subs[sel[i]]
			sub.effect = ''
			subs[sel[i]] = sub
		end
	end
end


function read_syllables(subs, sel, tp)--读音节函数：从台词文本读取每行以及每个音节的数据，使用parse_karaoke_data()函数，生成的音节数组为全局数组TLL_syllables
	TLL_syllables = {}
	for i = 1, #sel do
		local subp = subs[sel[i]]
		if subp.text ~= '' and not subp.comment then--空行和注释行不会被读取 
			local sylp = subs[sel[i]]
			TLL_syllables[i] = {
				start_time = subp.start_time,
				end_time = subp.end_time,
				text = subp.text,
				syllables = {}
			}
			aegisub.parse_karaoke_data(sylp)
			for j = 1, #sylp do
				TLL_syllables[i]["syllables"][j] = sylp[j]
			end
		end		
	end
end

function write_syllables(subs, sel, tp)--写音节函数：把全局数组TLL_syllables的内容写回选择的行，同时也会更新TLL_syllables的text属性；tp默认为false，tp为1表示强制写入
	for i = 1, #TLL_syllables do
		local sylp = TLL_syllables[i]["syllables"]
		local sub = subs[sel[i]]
		local subp = ""
		if tp == 1 or not(#sylp == 1 and sylp[1].duration == 0) then
			for j = 1, #sylp do
				subp = subp..string.format("{%s%d}%s", sylp[j].tag, sylp[j].duration/10, sylp[j].text)
			end
		else --纯字符行去掉行首的空音节标记
			subp = sylp[1].text
		end
		TLL_syllables[i]["text"] = subp
		sub.start_time = TLL_syllables[i]["start_time"]
		sub.end_time = TLL_syllables[i]["end_time"]
		sub.text = TLL_syllables[i]["text"]
		subs[sel[i]] = sub
	end
end

function LuaSplit(str,split)  --底层函数：lua版的explode
    local lcSubStrTab = {}  
    while true do  
        local lcPos = string.find(str,split)  
        if not lcPos then  
            lcSubStrTab[#lcSubStrTab+1] =  str      
            break  
        end  
        local lcSubStr  = string.sub(str,1,lcPos-1)  
        lcSubStrTab[#lcSubStrTab+1] = lcSubStr  
        str = string.sub(str,lcPos+1,#str)  
    end  
    return lcSubStrTab  
end  

function clone(object) --底层函数：复制lua对象
  local lookup_table = {}
  local function _copy(object)
    if type(object) ~= "table" then 
      return object
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for key, value in pairs(object) do
      new_table[_copy(key)] = _copy(value)
    end
    return setmetatable(new_table, getmetatable(object))
  end
  return _copy(object)
end

function validation(subs, sel)
	return #sel > 0
end

function selection_validation(subs, sel)
	return #sel > 1
end

function test(subs, sel)
	read_syllables(subs, sel)
	write_syllables(subs, sel)
end

--批量载入宏		
TLL_macros = {
	{
		script_name = "TLL - 音节划分",
		script_description = "自动识别汉字等宽字符并以卡拉OK标签隔断",
		entry = function(subs, sel) showdialog(subs, sel, 'wchar_dialogs', 'wchar_buttons', 'wchar_commands') end,
		validation = false
	},
	{
		script_name = "TLL - 双行字幕",
		script_description = "创建双行卡拉OK字幕",
		entry = function(subs,sel,config) main("kara_parse_double", subs, sel) end,
		validation = selection_validation
	},
	{
		script_name = "TLL - 音节切换",
		script_description = "生成音节文本或根据音节文本修改字幕",
		entry = function(subs,sel,config) main("kara_swift", subs, sel) end,
		validation = false
	},
	{
		script_name = "TLL - 清理占位音节",
		script_description = "删除字幕前后的占位音节并保证时间点正确",
		entry = function(subs,sel,config) showdialog(subs, sel, 'strip_dialogs', 'strip_buttons', 'strip_commands') end,
		validation = false
	}
}
for i = 1, #TLL_macros do
	aegisub.register_macro(TLL_macros[i]["script_name"], TLL_macros[i]["script_description"], TLL_macros[i]["entry"], TLL_macros[i]["validation"])
end
--aegisub.register_macro(script_name.." "..script_version, script_description, entry, validation)
--aegisub.register_macro('1234', '123456', test)