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
	Special Thanks to: TNBi, DracoRunan, ruzx007878
--]]

script_name = "TimeLine Lullamoon"
script_description = "1.以卡拉OK标签自动隔断宽字符  2.将隔行歌词首尾对齐，并自动修正冲突的时间间隔，从而把单行卡拉OK转化成双行  3.在特效字段生成用空格隔断的音节文本，也可以将音节文本反贴回歌词字幕"
script_author = "Yoshiko_G"
script_version = "0.49"

tr = aegisub.gettext

util = require'aegisub.util'

UI_conf = {
	--1,1,1,1,"intedit",value,min,max,"hint"
	--1,1,1,1,"label","text"
	--1,1,1,1,"checkbox",true
	--1,1,1,1,"dropdown","value",{items},"hint"
			
	double_dialogs = {
		info = { 0, 0, 3, 1, "label", label = "" },
		{ 0, 1, 1, 1, "label", label = "预显:" },
		{ 1, 1, 1, 1, "intedit", name = "timeadv", hint = "每句歌词预先显示的时间，单位为毫秒", value = 1000, min = 1, max = 20000 },
		{ 2, 1, 1, 1, "label", label = "ms" },
		{ 0, 2, 1, 1, "label", label = "延后:" },
		{ 1, 2, 1, 1, "intedit", name = "timepass", value = 1000, min = 1, max = 20000 },
		{ 2, 2, 1, 1, "label", label = "ms" },
		{ 0, 3, 2, 1, "checkbox", name = "fn1", value = true, label = "自动修正时间轴冲突" }
	},
	double_buttons = {'Parse!','Cancel'},	
	double_commands = {
		function(subs,sel,config) kara_parse_double(subs, sel, config) end,
		function(subs,sel,config) aegisub.cancel() end
	},
	
	swift_dialogs = {
		info = { 0, 0, 1, 1, "label", label = "请选择功能：\nCreate：根据实际字幕内容在特效字段生成按音节分割的文本；\nParse：根据特效字段的音节分割文本修改字幕内容。\nClean：清除特效字段。"  }
	},
	swift_buttons = {'Create','Parse','Clean','Cancel'},
	swift_commands = {
		function(subs,sel,config) kara_swift(subs, sel, 0) end,
		function(subs,sel,config) kara_swift(subs, sel, 1) end,
		function(subs,sel,config) kara_swift(subs, sel, 2) end,
		function(subs,sel,config) aegisub.cancel() end
	},
	
	wchar_dialogs = {
		info = { 0, 0, 1, 1, "label", label = "标签类型" },
		{ 1, 0, 1, 1, "dropdown", name = "tag", items = {"\\kf", "\\k", "\\ko"} , value = "\\kf" }
	},
	wchar_buttons = {"OK", "Cancel"},
	wchar_commands = {
		function(subs,sel,config) kara_parse_wchar(subs, sel, config) end,
		function(subs,sel,config) aegisub.cancel() end,
	},
	
	strip_dialogs = {
		info = { 0, 0, 1, 1, "label", label = "" , },
		{ 0, 1, 1, 1, "checkbox", name = "allstrip", value = false, label = "清除所有卡拉OK音节符"  },
	},
	strip_buttons = {"OK", "Cancel"},
	strip_commands = {
		function(subs,sel,config) kara_strip_tags(subs, sel, config) end,
		function(subs,sel,config) aegisub.cancel() end,
	},
	
	sylmov_dialogs = {
		info = { 0, 0, 5, 1, "label", label = "" },
		{ 0, 1, 1, 1, "dropdown", name = "tp", items = {"提前", "延后"}, value = "提前" },
		{ 1, 1, 1, 1, "intedit", name = "duration", hint = "", value = 0, min = 0, max = 20000 },
		{ 1, 1, 1, 1, "label", label = "ms" }
	},
	sylmov_buttons = {"OK", "Cancel"},
	sylmov_commands = {
		function(subs,sel,config) kara_sylmov(subs, sel, config) end,
		function(subs,sel,config) aegisub.cancel() end,
	},
	
	tlorg_ctrl_dialogs = {
		{ 0, 0, 1, 1, "label", label = "关键" },
		{ 1, 0, 1, 1, "label", label = "接续编号" },
		{ 2, 0, 1, 1, "label", label = "同步编号" },
		{ 3, 0, 1, 1, "label", label = "字幕样式" },
		{ 4, 0, 1, 1, "label", label = "字幕文本" },
	},
	tlorg_ctrl_buttons = {"Save", "Refresh",  "Preview", "Auto", "Cancel"},
	tlorg_ctrl_commands = function(subs,sel,button,config) return button, config end,
}

--[[
function main(mode, subs, sel)
	if mode == "kara_parse_double" then
		show_dialog(subs, sel, 'double_dialogs', 'double_buttons', 'double_commands')
	elseif mode == "kara_swift" then
		show_dialog(subs, sel, 'swift_dialogs', 'swift_buttons', 'swift_commands')
	end
end

function entry(subs, sel)
	show_dialog(subs, sel, 'main_dialogs', 'main_buttons', 'main_commands', '')
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
	local unicode = require 'aegisub.unicode'
	local s = {}
	local TLSubs = read_syllables(subs, sel)
	--write_syllables(subs, sel, tp)
	aegisub.progress.task("Processing...")
	aegisub.progress.set(0)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
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
				TLSubs[i]["syllables"][k] = {
					duration = interval,
					tag = config.tag,
					text = subsw
				}
			end
		end
		aegisub.progress.set(1 / #TLSubs)
	end
	write_syllables(subs, sel, TLSubs)
end

function kara_strip_tags(subs, sel, config)--去除卡拉OK标签但是维持原本的start_time和end_time
	local TLSubs = read_syllables(subs, sel)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		local syls = subp["syllables"]
		if syls[#syls].duration > 20 and syls[#syls].text == '' then --先判断尾部，认为时间小于等于20ms的都是占位符不处理
			subp.end_time = subp.end_time - syls[#syls].duration
			table.remove(TLSubs[i]["syllables"],#syls)
		end
		if syls[1].duration > 0 and syls[1].text == '' then --再判断头部，避免误修改索引
			subp.start_time = subp.start_time + syls[1].duration
			table.remove(TLSubs[i]["syllables"],1)
		end
		if config.allstrip then --清除剩余所有卡拉OK标签但是不修改时间
			local syls_temp = ""
			for j=1, #syls do
				syls_temp = syls_temp..syls[j].text
			end
			TLSubs[i]["syllables"] = {
				{
					tag = "\\kf",
					duration = 0,
					text = syls_temp
				}				
			}
		end
	end
	write_syllables(subs, sel, TLSubs)
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
--TODO: 行间关系：
--Head-关键句，认为关键句就是R有值的句子
--column-同步列C，同标记的后句的起止时间和音节都跟关键句对齐
--row-接续行R，同标记的接续行认为彼此有前后连续关系
--{"C" = 3, "R" = 5，"H" = 1}范例

--流程：执行—预读样式—预判样式与列的关系表—显示调整窗口—确定后写入effect
--TODO: 用repeat...until...实现编辑窗口
--TODO: 自动检测是否已经关系化，关系化合法性
function timeline_org_main(subs, sel)
	local TLSubs = read_syllables(subs, sel)
	local styles, headstyle = timeline_org_prepare(TLSubs)--得到style列表和预估的关键句样式
	local rmax, rnum = 9, 1
	local TLRels = timeline_create_rels(TLSubs, headstyle, styles)--生成关键句关系表
	timeline_parse_rows(TLSubs, TLRels, styles, headstyle, rnum)--生成行关系
	local cmax = timeline_parse_columns(TLSubs, TLRels, styles)--生成列关系
	local button, config = "", {}
	while(button and button ~= "Save" and button ~= "Cancel") do--用循环达到持续显示窗体效果
		
		button, config = timeline_org_ctrl_dialog(subs, sel, TLSubs, TLRels, styles, headstyle, rmax, rnum, cmax)
		if button == "Auto" then--根据自动设定重置行列
			headstyle = config.headstyle
			rnum = tonumber(config.rnum)
			TLRels = timeline_create_rels(TLSubs, headstyle, styles)--生成关键句关系表
			timeline_parse_rows(TLSubs, TLRels, styles, headstyle, rnum)--生成行关系
			cmax = timeline_parse_columns(TLSubs, TLRels, styles)--生成列关系
		end
		--button, config = rst[1], rst[2]
		--aegisub.debug.out(0, button)
	end
	--local config1 = timeline_org_1_dialog(subs, sel, styles, headstyle)--显示样式对话框
	--if (config1.head ~= headstyle) then headstyle = config1.head end--确定head与样式的关系
	--local rnum = config1.rnum--确定row分为几行
	if button == "Save" then
		timeline_org_update(TLSubs, TLRels)
		write_syllables(subs, sel, TLSubs)
	end	
end

function timeline_org_prepare(TLSubs)
	local styles = {}
	local headstyle = ""
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		s = subp.style
		if(not styles[s]) then
			styles[s] = 1
		end
		if headstyle == "" and #subp["syllables"] > 1 then headstyle = subp.style end--第一个音节数多于1的句为关键句
	end
	local styles = table_keys(styles)
	if headstyle == "" then headstyle = styles[1] end--前面没选出关键句的情况
	
	return styles, headstyle
end

function timeline_create_rels(TLSubs, headstyle, styles)--生成关键句关系表，认为R即代表关键句
	local TLRels = {}
	for i = 1, #TLSubs do
		local rel = {}
		if TLSubs[i]["style"] == headstyle then
			rel["R"] = 99
		end
		TLRels[i] = rel
	end
	return TLRels
end

function timeline_parse_rows(TLSubs, TLRels, styles, headstyle, rnum)
	local r = 1
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		if subp.style == headstyle then
			local rel = TLRels[i]
			rel["R"] = r
			if r >= rnum then
				r = 1
			else
				r = r + 1
			end
			TLRels[i] = rel	
		end		
	end
end

function timeline_parse_columns(TLSubs, TLRels, styles)--生成列关系，同时返回最大列数
	local style_proc = {}
	for _, v in pairs(styles) do
		style_proc[v] = 1
	end
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		local rel = TLRels[i]
		rel["C"] = style_proc[subp.style]
		style_proc[subp.style] = style_proc[subp.style] + 1
		TLRels[i] = rel
	end	
	local cmax = 1
	for _, v in pairs(style_proc) do
		if v > cmax then cmax = v end
	end
	return cmax
end

function timeline_org_ctrl_dialog(subs, sel, TLSubs, TLRels, styles, headstyle, rmax, rnum, cmax)
	local showlines = util.deep_copy(UI_conf["tlorg_ctrl_dialogs"])
	local lnum = 1
	aegisub.progress.task("Creating Dialog...Please Wait")
	aegisub.progress.set(0)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		local relp = TLRels[i]
		--local newline = util.deep_copy(UI_conf["tlorg_ctrl_dialog_edit_elements"])
		local hv, cv
		if TLRels[i]["R"] then 
			hv = true
			rv = TLRels[i]["R"]
		else
			hv = false
			rv = 0
		end
		local newline = {
			{ 0, i, 1, 1, "checkbox", name = "head_" .. i, value = hv },
			{ 1, i, 1, 1, "intedit", name = "row_" .. i,  value = rv, min = 0, max = rmax },
			{ 2, i, 1, 1, "intedit", name = "col_" .. i,  value = TLRels[i]["C"], min = 1, max = cmax },
			--{ 1, y, 1, 1, "dropdown", name = "row_" .. i, items = rlist, value = rv },
			--{ 2, y, 1, 1, "dropdown", name = "col_" .. i, items = clist, value = TLRels[i]["C"] },
			{ 3, i, 1, 1, "edit", name = "style_" .. i, text = subp.style },
			{ 4, i, 30, 1, "edit", name = "text_" .. i, text = subp.text }
		}	
		array_plus(showlines, newline)
		lnum = lnum + 1
		aegisub.progress.set(i / (#TLSubs + 2) * 100)
	end
	--aegisub.debug.out(0, table_serialize(showlines))
	local settingline = {
		{ 0, lnum, 1, 1, "label", label = "----" },
		{ 1, lnum, 1, 1, "label", label = "----------------" },
		{ 2, lnum, 1, 1, "label", label = "----------------" },
		{ 3, lnum, 1, 1, "label", label = "----------------" },
		{ 0, lnum + 1, 1, 1, "label", label = "接续数" },--需要修改y
		{ 1, lnum + 1, 1, 1, "dropdown", name = "rnum", items = table_make_array(rmax), value = rnum },--需要修改y、items、value
		{ 2, lnum + 1, 1, 1, "label", label = "关键样式" },--需要修改y
		{ 3, lnum + 1, 1, 1, "dropdown", name = "headstyle", items = styles, value = headstyle }--需要修改y、name、items、value
	}
	aegisub.progress.set(100)
	array_plus(showlines, settingline)
	return show_dialog(subs, sel, showlines, 'tlorg_ctrl_buttons', 'tlorg_ctrl_commands')
end

function timeline_org_update(TLSubs, TLRels)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		if TLRels[i] and TLRels[i] ~= {} then
			subp.effect =table_serialize(TLRels[i])
		end		 
	end
	return TLSubs
end

--2. 根据列调整参数修改并写入

--预读样式
function timeline_read_styles(subs, sel, TLSubs)
	
	return styles, headstyle
end

--将所有行的起始和结束时间写入effect列
--[[
function write_timeline_times(subs, sel)
	local TLSubs = read_syllables(subs, sel)
	for i = 1, #TLSubs do
		local subp = TLSubs[i] 
		local otimeline = {
			start_time = subp.start_time,
			end_time = subp.end_time
		}
		subp.effect = table_serialize(otimeline)
	end
	write_syllables(subs, sel, TLSubs)
end
--]]

--提前或延后起始和结束时间，不改变音节；
--drt负数为提前，正数为延后；
--tp1=nil或0为不移动，1为只移动起始，2为只移动结束，3为都移动；
--tp2=nil或0为不处理冲突，1为不改变前句时间，2为不改变后句时间
--tp3=nil或0为不修改音节，1为自动添加空音节占位符
function move_timelines(subs, sel, drt, tp1, tp2, tp3)
	local TLSubs = read_syllables(subs, sel)
	if tp1 or tp1 ~= 0 then
		for i = 1, #TLSubs do--第二轮循环，对时间进行修改
			local subp = TLSubs[i]
			if tp1 == 1 or tp1 == 3 then
				subp.start_time = subp.start_time + drt
			end
			if tp1 == 2 or tp1 == 3 then
				subp.end_time = subp.end_time + drt
			end
		end
	end
	if tp2 or tp2 ~= 0 then
		for i = 1, #TLSubs do--第三轮循环，处理冲突
			
		end
	end
	write_syllables(subs, sel, TLSubs)
end

--音节移动的壳函数
function kara_sylmov(subs, sel, config)
	local drt = 0
	if config.tp == "提前" then
		drt = - config.duration
	elseif config.tp == "延后" then
		drt = config.duration
	end
	move_syllables(subs, sel, drt)
end

--在起始和结束时间不变的前提下，提前或延后音节划分线；drt负数为提前，正数为延后
function move_syllables(subs, sel, drt, tp)
	local TLSubs = read_syllables(subs, sel)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		local syls = subp["syllables"]
		if #syls > 1 then
			local drt1 = drt
			if drt1 < 0 then
				for j = 1, #syls do--提前第一次循环
					local syldrt = syls[j].duration
					if syldrt + drt1 < 0 then--单音节不够提前的情况下该音节归零，继续提前后一个音节
						syls[j].duration = 0
						drt1 = drt1 + syldrt
					else--单音节足以提前的情况下只需要修改当前音节
						syls[j].duration = syls[j].duration + drt1
						drt1 = 0
						break
					end				
				end
				local subdrt = subp.end_time-subp.start_time
				local sum = 0
				for j = 1, #syls do--第二次循环，计算总音节时间，把差值加到最后一个音节
					sum = sum + syls[j].duration
				end
				syls[#syls].duration = syls[#syls].duration + subdrt - sum
			elseif drt1 > 0 then--延后第一次循环
				for j = #syls, 1, -1 do
					local syldrt = syls[j].duration
					if syldrt - drt1 < 0 then--单音节不够延后的情况下该音节归零，继续延后前一个音节
						syls[j].duration = 0
						drt1 = drt1 - syldrt
					else--单音节足以延后的情况下只需要修改当前音节
						syls[j].duration = syls[j].duration - drt1
						drt1 = 0
						break
					end		
				end
				local subdrt = subp.end_time-subp.start_time
				local sum = 0
				for j = 1, #syls do--第二次循环，计算总音节时间，把差值加到第一个音节
					sum = sum + syls[j].duration
				end
				syls[1].duration = syls[1].duration + subdrt - sum
			end	
		end		
	end
	write_syllables(subs, sel, TLSubs)
end

--读音节函数：从台词文本读取每行以及每个音节的数据，使用parse_karaoke_data()函数，返回音节数组
function read_syllables(subs, sel, tp)
	local sublist = {}
	aegisub.progress.task("Reading Lines...")
	aegisub.progress.set(0)
	for i = 1, #sel do
		local subp = subs[sel[i]]
		if subp.text ~= '' and not subp.comment then--空行和注释行不会被读取 
			local sylp = subs[sel[i]]
			sublist[i] = {
				start_time = subp.start_time,
				end_time = subp.end_time,
				text = subp.text,
				style = subp.style,
				effect = subp.effect,
				syllables = {}
			}
			if subp.effect then 
				sublist[i]["rel"] = table_unserialize(subp.effect)--顺便试图序列化行间关系，如果不存在则为nil
			else
				sublist[i]["rel"] = nil
			end
			aegisub.parse_karaoke_data(sylp)
			for j = 1, #sylp do
				sublist[i]["syllables"][j] = sylp[j]
			end
		end		
		aegisub.progress.set(i / #sel * 100)
	end
	return sublist
end

--写音节函数：把音节数据内容写回选择的行，同时也会更新text属性；tp默认为false，tp为1表示强制写入
function write_syllables(subs, sel, cont, tp)
	local sublist = cont
	aegisub.progress.task("Writing Lines...")
	aegisub.progress.set(0)
	for i = 1, #sublist do
		local sylp = sublist[i]["syllables"]
		local sub = subs[sel[i]]
		local subp = ""
		if tp == 1 or not(#sylp == 1 and sylp[1].duration == 0) then
			for j = 1, #sylp do
				subp = subp..string.format("{%s%d}%s", sylp[j].tag, sylp[j].duration/10, sylp[j].text)
			end
		else --纯字符行去掉行首的空音节标记
			subp = sylp[1].text
		end
		sublist[i]["text"] = subp
		sub.start_time = sublist[i]["start_time"]
		sub.end_time = sublist[i]["end_time"]
		sub.text = sublist[i]["text"]
		sub.style = sublist[i]["style"]
		sub.effect = sublist[i]["effect"]
		subs[sel[i]] = sub
		aegisub.progress.set(i / #sublist * 100)
	end
end

--显示对话框的通用函数
function show_dialog(subs, sel, dconf, bconf, cconf, info)
	local button, config, rst, rst2
	local Ud, Ub, Uc = dconf, bconf, cconf
	if type(Ud) == "string" then Ud = util.deep_copy(UI_conf[dconf]) end
	if type(Ub) == "string" then Ub = util.deep_copy(UI_conf[bconf]) end
	if type(Uc) == "string" then Uc = util.deep_copy(UI_conf[cconf]) end
	for k, v in pairs(Ud) do
		v.x = v[1]
		v.y = v[2]
		v.width = v[3]
		v.height = v[4]
		v.class = v[5]
	end
	if(info) then 
		Ud['info']['label'] = info
		info = ''
	end
	button, config = aegisub.dialog.display(Ud,Ub)
	if type(Uc) == "table" then
		for i, c in pairs(Uc) do
			if button == Ub[i] then
				rst = c(subs,sel,config)
				break
			end
		end
	elseif type(Uc) == "function" then
		rst, rst2 = Uc(subs,sel,button,config)
	end
	return rst, rst2
end

--底层函数：序列化，将表转化为字符串
function table_serialize(tbl)
	local str = '{'
	for k, v in pairs(tbl) do
		local split = ''
		if type(k) == 'number' then
			split = ''
		elseif type(k) == 'string' then
			split = '"'
		end
		str = str .. '[' .. split .. k ..split ..']='
		if type(v) == 'number' then
			str = str .. v .. ',' 
		elseif type(v) == 'string' then
			str = str .. '"' .. v .. '",' 
		elseif type(v) == 'table' then
			str = str .. table_serialize(v) .. ','--可能存在循环调用，不过一般遇不到吧
		else
			str = str .. 'nil,'
		end
	end
	str = string.sub(str,1,-2)  .. '}'
	return str
end

--底层函数：反序列化，将字符串转化为表
--偷懒直接执行，有安全风险，不过谁会对本地脚本过不去？
function table_unserialize(str)
	local tbl = nil
	if type(str) == "string" and str ~= "" then
		local str = 'local tbl=' .. str .. ' return tbl'
		rst = assert(loadstring(str))()
		if type(rst) == "table" then tbl = rst end
	end	
  return tbl
end

function table_make_array(n)
	local rst = {}
	for i = 1, n do
		table.insert(rst, i)
	end
	return rst
end

--底层函数：返回表的键名
function table_keys(tbl) 
	local ks = {}
	for k, _ in pairs(tbl) do
		table.insert(ks,k)
	end
	return ks
end

--底层函数：表浅查找
function table_search(tbl, val) 
	local pos = nil
	for k, v in pairs(tbl) do
		if v == val then
			pos = k
			break
		end
	end
	return pos
end

--底层函数：表合并
function table_merge(tbl1, tbl2)
	for k, v in pairs(tbl2) do
		if type(k) == "number" then
			table.insert(tbl1, v)
		elseif type(k) == "string" then
			tbl1[k] = v
		end
	end
	return tbl1
end

function array_plus(tbl1, tbl2)
	for k, v in ipairs(tbl2) do
		table.insert(tbl1, v)
	end
	return tbl1
end

--底层函数：lua版的explode
function LuaSplit(str,split)  
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
 
--[[
--底层函数：类似php的判否函数
function !(v)
	return not v or v == 0 or v == "" or v == {}
end
--]]

function selection_validation(subs, sel)
	return #sel > 1
end

function test(subs, sel)
	local a = function(subs,sel,button,config) return button end
	button = show_dialog(subs,sel,{},{},"tlorg_ctrl_commands")
	aegisub.debug.out(0, table_serialize(button,' '))
end

--批量载入宏		
TLL_macros = {
	{
		script_name = "划分汉字音节",
		script_description = "自动识别汉字等宽字符并以卡拉OK标签隔断",
		entry = function(subs, sel) show_dialog(subs, sel, 'wchar_dialogs', 'wchar_buttons', 'wchar_commands') end,
		validation = false
	},
	{
		script_name = "清理占位音节",
		script_description = "删除字幕前后的占位音节并保证时间点正确",
		entry = function(subs,sel,config) show_dialog(subs, sel, 'strip_dialogs', 'strip_buttons', 'strip_commands') end,
		validation = false
	},
	{
		script_name = "批量移动音节",
		script_description = "不改变起止时间，统一移动所选行音节的分隔时间",
		entry = function(subs,sel,config) show_dialog(subs, sel, 'sylmov_dialogs', 'sylmov_buttons', 'sylmov_commands') end,
		validation = false
	},
	{
		script_name = "双行字幕",
		script_description = "创建双行卡拉OK字幕",
		entry = function(subs,sel,config) show_dialog(subs, sel, 'double_dialogs', 'double_buttons', 'double_commands') end,
		validation = selection_validation
	},
	{
		script_name = "音节切换",
		script_description = "生成音节文本或根据音节文本修改字幕",
		entry = function(subs,sel,config) show_dialog(subs, sel, 'swift_dialogs', 'swift_buttons', 'swift_commands') end,
		validation = false
	},
	{
		script_name = "时间轴关系化",
		script_description = "基于样式生成时间轴同步和连续的关系信息",
		entry = function(subs,sel,config) timeline_org_main(subs, sel) end,
		validation = false
	},
}
for i = 1, #TLL_macros do
	aegisub.register_macro(script_name.."/"..TLL_macros[i]["script_name"], TLL_macros[i]["script_description"], TLL_macros[i]["entry"], TLL_macros[i]["validation"])
end
--aegisub.register_macro("TEST", script_description, test)