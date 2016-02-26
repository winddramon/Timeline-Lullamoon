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
	Special Thanks to: TNBi, DracoRunan, ruzx007878, Rogersystop
--]]

script_name = "TimeLine Lullamoon"
script_description = "提供字幕起止时间和卡拉OK音节处理的多项功能，可用于制作双语、双行卡拉OK字幕等"
script_author = "Yoshiko_G"
script_version = "v1.00"

tr = aegisub.gettext

util = require'aegisub.util'
unicode = require 'aegisub.unicode'

UI_conf = {
	--[[
	swift_dialogs = {
		info = { 0, 0, 1, 1, "label", label = "请选择功能：\nCreate：根据实际字幕内容在特效字段生成按音节分割的文本；\nParse：根据特效字段的音节分割文本修改字幕内容。\nClean：清除特效字段。"  }
	},
	swift_buttons = {'Create','Parse','Clean','Cancel'},
	swift_commands = {
		function(subs,sel,config) kara_swift(subs, sel, 0) end,
		function(subs,sel,config) kara_swift(subs, sel, 1) end,
		function(subs,sel,config) kara_swift(subs, sel, 2) end,
		function(subs,sel,config) aegisub.cancel() end
	},--]]
	
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
		function(subs,sel,config) kara_strip_holder_syls(subs, sel, config) end,
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
		{ 1, 0, 1, 1, "label", label = "编号" },
		{ 2, 0, 1, 1, "label", label = "接续号" },
		{ 3, 0, 1, 1, "label", label = "同步号" },
		{ 4, 0, 3, 1, "label", label = "字幕样式" },
		{ 7, 0, 3, 1, "label", label = "字幕文本" },
	},
	tlorg_ctrl_dialogs_2 = {
		{ 0, 0, 1, 1, "label", label = "关键" },
		{ 1, 0, 1, 1, "label", label = "编号" },
		{ 2, 0, 1, 1, "label", label = "同步号" },
		{ 3, 0, 3, 1, "label", label = "字幕文本" },
	},
	tlorg_ctrl_buttons = {"Apply", "Last Page", "Next Page", "Execute Sync and Clasp", "Subtitle Mode", "Syllable Mode", "Switch", "Refresh", "Cancel" },
	tlorg_ctrl_commands = function(subs,sel,button,config) return button, config end,
}

function timeline_wchar_single(subp, tag)
	local duration = subp.end_time - subp.start_time
	local wtable = trans_wchar2table(subp["syllables"][1]["text"])
	local syls = subp.syllables
	local intv = math.floor(duration / #wtable)
	for i = 1, #wtable do
		syls[i] = {
			duration = intv,
			tag = tag,
			text = wtable[i]
		}
	end
end

function kara_parse_wchar(subs, sel, config)--宽字符自动区隔音节
	local s = {}
	local TLSubs = read_syllables(subs, sel)
	--write_syllables(subs, sel, tp)
	aegisub.progress.task("Processing...")
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		if #subp["syllables"] == 1 and subp["syllables"][1].duration == 0 then--只有在没有音节存在时才执行
			timeline_wchar_single(subp, config.tag)
		end
	end
	 write_syllables(subs, sel, TLSubs)
end

function kara_add_holder_syls(subs, sel)--给字幕所有空格加上{\k0}的标签
	for i = 1, #sel do
		local subp = subs[sel[i]]
		subp.text = string.gsub(subp.text, "%s+", "{\\k0}%0")
		subs[sel[i]] = subp
	end
end

function kara_strip_holder_syls(subs, sel, config)--去除卡拉OK标签但是维持原本的start_time和end_time
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
		if #syls > 1 then
			for j = #syls, 2, -1 do
				--echo(j..':['..syls[j].text..']->['..string.gsub(syls[j]["text"], "%s+", "").."]\n")
				if syls[j]["duration"] == 0 then
					syls[j-1]["text"] = syls[j-1]["text"] .. syls[j]["text"]
					table.remove(TLSubs[i]["syllables"],j)
				end
			end
		end
		--此功能入口废弃
		--[[
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
		--]]
	end
	write_syllables(subs, sel, TLSubs)
end
--[=[
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
--]=]
--行间关系：
--Head-关键句，认为关键句就是R有值的句子
--column-同步列C，同标记的后句的起止时间和音节都跟关键句对齐
--row-接续行R，同标记的接续行认为彼此有前后连续关系
--{"C" = 3, "R" = 5}范例

function timeline_org_main(subs, sel)
	local inum = read_infos(subs, sel)
	local TLSubs = read_syllables(subs, sel)
	local styles, headstyle = timeline_org_prepare(TLSubs)--得到style列表和预估的关键句样式
	local rmax, rnum = 9, 1
	local TLRels = timeline_create_rels(TLSubs, headstyle, styles)--生成关键句关系表
	timeline_create_rows(TLSubs, TLRels, styles, headstyle, rnum)--生成行关系
	local cmax = timeline_create_columns(TLSubs, TLRels, styles)--生成列关系
	local button, config = "", {}
	local dtype = 1
	local loop = 0
	local show_start, show_end, show_max = 1, 0, 20
	local osettings = {sync = false, sync_syls = false, sync_wchar = false, clasp = false, clasp_left = 1000, clasp_right = 1000}
	local oheadstyle, ornum = headstyle, rnum
	local showbuttons = util.deep_copy(UI_conf["tlorg_ctrl_buttons"])
	while(button and button ~= showbuttons[1] and button ~= showbuttons[9]) do--用循环达到持续显示窗体效果
		loop = loop + 1
		--起止行数的修正
		if #TLSubs <= show_max then
			show_start = 1
			show_end = #TLSubs
		else
			if show_start <= 1 then
				show_start = 1
			end
			if show_start + show_max >= #TLSubs then 
				show_start = #TLSubs - show_max + 1
			end
			show_end = show_start + show_max - 1
		end		
		--显示窗体
		button, config = timeline_org_ctrl_dialog(subs, sel, TLSubs, TLRels, show_start, show_end, dtype, styles, headstyle, rmax, rnum, cmax, inum, osettings)
		--读同步和接续的参数，如果不存在值（窗体改变）则不读取，以免读到nil
		if config.sync then
			osettings.sync, osettings.sync_syls, osettings.sync_wchar = config.sync, config.sync_syls, config.sync_wchar
		end
		if config.clasp then
			osettings.clasp, osettings.clasp_left, osettings.clasp_right = config.clasp, config.clasp_left, config.clasp_right
		end
		--更新关系表
		if dtype == 1 then--第二界面时不修改关系表
			--读关键句和R数，如果不存在值（窗体改变）则不读取，以免读到nil
			if config.headstyle and config.rnum then
				headstyle, rnum = config.headstyle, tonumber(config.rnum)	
			end		
			--1a.自动重置
			if headstyle ~= oheadstyle or rnum ~= ornum then--自动重置设定有修改时，忽略其他输入			
				TLRels = timeline_create_rels(TLSubs, headstyle, styles)--生成关键句关系表
				timeline_create_rows(TLSubs, TLRels, styles, headstyle, rnum)--生成行关系
				cmax = timeline_create_columns(TLSubs, TLRels, styles)--生成列关系
			--1b.手动重生成
			else
				timeline_edit_rels(TLRels, config, show_start, show_end)
			end
			--2.更新样式和文本
			timeline_edit_texts(TLSubs, show_start, show_end, button, config)
			--3.执行同步和接续命令，之后清空选项
			if button == showbuttons[4] or button == showbuttons[6] then
				if config.clasp then timeline_clasp(TLSubs, TLRels, config, inum) end
				osettings.clasp, osettings.clasp_left, osettings.clasp_right = false, 0, 0
			end
			if button == showbuttons[4] or button == showbuttons[6] then
				if config.sync then timeline_sync_rows(TLSubs, TLRels, config) end
				osettings.sync, osettings.sync_syls, osettings.sync_wchar = false, false, false
			end
		elseif dtype == 2 or dtype == 3 then
			--从第二窗口得到音节改变情况
			timeline_get_syl_change(TLSubs, TLRels, show_start, show_end, config, dtype)
		end
		
		--调整显示模式 1 通常  2 音节文本模式  3 音节对齐模式
		if button == showbuttons[6] then
			dtype = 2
		elseif button == showbuttons[5] then
			dtype = 1
		elseif button == showbuttons[7] then
			if dtype == 2 then dtype = 3
			elseif dtype == 3 then dtype = 2 end
		end
		--调整起止行数
		if button == showbuttons[2] then show_start = show_start - show_max end
		if button == showbuttons[3] then show_start = show_start + show_max end		
		oheadstyle, ornum = headstyle, rnum
		--回避死循环
		if loop > 1000 then
			aegisub.debug.out(0, "Error: Endless Loop")
			break
		end
	end
	if button == showbuttons[1] then
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
		
		if #subp["syllables"] > 1 then
			if headstyle == "" then headstyle = subp.style end--第一个音节数多于1的句为关键句
			local syls = subp["syllables"]
		end		
		subp["syl_table"] = trans_syls2table(subp["syllables"])
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
		else
			rel["R"] = nil
		end
		TLRels[i] = rel
	end
	return TLRels
end

function timeline_create_rows(TLSubs, TLRels, styles, headstyle, rnum)
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

--以其一为源，更新text, syl_table和syllables的其余两个
--text: 字幕原始台词，包含效果
--syllables：parse_karaoke_data生成的音节表
function timeline_TTS(subp, tp)
	if tp == "text" then
		subp.syllables = aegisub.parse_karaoke_data(util.deep_copy(subp))
		subp.syl_table = trans_syls2table(subp.syllables)
	elseif tp == "syllables" then
		subp.text = trans_syls2text(subp.syllables)
		subp.syl_table = trans_syls2table(subp.syllables)
	end		
end

function timeline_sync_rows(TLSubs, TLRels, config)
	local heads = {}
	for i = 1, #TLSubs do--第一遍循环，读全部关键句的起止时间和音节
		local subp = TLSubs[i]
		local relp = TLRels[i]
		if relp["R"] then
			heads[relp["C"]] = TLSubs[i]
		end
	end
	for i = 1, #TLSubs do--第二遍循环，修改全部非关键句的起止时间和音节
		local subp = TLSubs[i]
		local relp = TLRels[i]
		local hd = heads[relp["C"]]
		if not relp["R"] and hd then
			subp.start_time = hd["start_time"]
			subp.end_time = hd["end_time"]
			if config.sync_syls then
				local tp = nil
				if config.sync_wchar then tp = 1 end
				timeline_sync_syls(subp, hd, tp)
			end
			timeline_TTS(subp, "syllables") --刷新text	
		end	
	end
end

function timeline_sync_syls(subp1, subp2, tp)--使subp1的音节与subp2完全相同，tp=0或nil为默认，tp=1为先划分syls1音节
	local syls1, syls2 = subp1.syllables, util.deep_copy(subp2.syllables)
	local ld, rd = 0, 0
	if (#syls1 > 1 or tp == 1) and #syls2 > 1 then
		if #syls1 == 1 and tp == 1 then
			timeline_wchar_single(subp1, "\\k")
			timeline_TTS(subp1, "syllables")
		end
		if syls1[1]["text"] == "" and syls1[1]["duration"] > 0 then--subp1第一个音节是占位符的情况
			table.remove(syls1,1)
		end
		if syls2[1]["text"] == "" and syls2[1]["duration"] > 0 then--subp2第一个音节是占位符的情况
			ld = syls2[1]["duration"]
			table.remove(syls2,1)
		end
		if syls1[#syls1]["text"] == "" and syls1[#syls1]["duration"] > 0 then--subp1最后一个音节是占位符的情况
			table.remove(syls1)
		end	
		if syls2[#syls2]["text"] == "" and syls2[#syls2]["duration"] > 0 then--subp2最后一个音节是占位符的情况
			rd = syls2[#syls2]["duration"]
			table.remove(syls2)
		end		
		local snum = math.max(#syls1, #syls2)
		for i = 1, snum do
			if i > #syls1 then--音节超过subp1，增加文本为空的音节
				syls1[i] = util.copy(syls2[i])
				syls1[i]["text"] = ""
			elseif i > #syls2 then--音节超过subp2，把音节时间改为0
				syls1[i]["duration"] = 0
			else--通常情况
				local otext = syls1[i]["text"]
				syls1[i] = util.copy(syls2[i])
				syls1[i]["text"] = otext			
			end		
		end
		if ld > 0 then
			table.insert(syls1, 1, empty_syllable(ld))
		end
		if rd > 0 then
			table.insert(syls1, empty_syllable(rd))
		end
	end	
end

function timeline_clasp(TLSubs, TLRels, config, inum)--使接续句前后连接
	local rnum = 0
	local rows = {}
	local c_left, c_right = config.clasp_left, config.clasp_right
	for i = 1, #TLRels do--第一遍循环，读全部关键句的接续段数
		local relp = TLRels[i]
		if relp["R"] then
			if relp["R"] > rnum then
				rnum = relp["R"]
				rows[relp["R"]] = {}
			end
			table.insert(rows[relp["R"]], TLSubs[i])
		end			
	end
	for rno, rlist in pairs(rows) do--第二遍循环
		for j = 1, #rlist do
			local t_left, t_right = c_left, c_right
			local rj0, rj1, rj2 = {}, rlist[j], {}
			--前移预判			
			if j > 1 then
				rj0 = rlist[j - 1] 
				
				--冲突1：前移以后，本句起始与前句结束冲突，这时本句从前句结束时间开始
				if rj1["start_time"] - t_left < rj0["end_time"] then
					t_left = rj1["start_time"] - rj0["end_time"]
				end
			end
			--前移
			if rj1["start_time"] - t_left < 0 then
				echo(string.format("错误： 检测到第 %s 行前移后起始时间小于0", rj1["no"] - inum + 1))
				aegisub.cancel()
			end
			rj1["start_time"] = rj1["start_time"] - t_left
			--后移预判
			if j < #rlist then				
				rj2 = rlist[j + 1]
				--冲突2：后移后，本局结束与后句提前的冲突，这时本句从后句的提前开始，但是不会低于0
				if rj1["end_time"] + t_right > rj2["start_time"] - c_left then
					t_right = rj2["start_time"] - c_left - rj1["end_time"]
					if t_right < 0 and t_right >= - c_left then 
						t_right = 0
					end
				end
			end
			--后移
			rj1["end_time"] = rj1["end_time"] + t_right
			--音节占位符和音节修正
			if t_left >= 0 then
				local syl = empty_syllable(t_left)
				table.insert(rj1["syllables"], 1, syl)
			else--这里是后句起始本来就比前句末尾要前的情况，不过按逻辑不会遇到
				--TODO
			end
			if t_right >= 0 then
				local syl = empty_syllable(t_right)
				table.insert(rj1["syllables"], syl)
			else--这里是本句结束本来就比后句起始要后的情况，暂时出错退出
				echo(string.format("错误： 检测到第 %s 行与第 %s 行存在时间轴冲突", rj1["no"] - inum + 1, rj2["no"] - inum + 1))
				aegisub.cancel()
			end
			timeline_TTS(rj1, "syllables") --刷新text和
		end
	end
end

function timeline_create_columns(TLSubs, TLRels, styles)--生成列关系，同时返回最大列数
	local style_proc = {}
	for _, v in pairs(styles) do
		style_proc[v] = 1
	end
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		local relp = TLRels[i]
		relp["C"] = style_proc[subp.style]
		style_proc[subp.style] = style_proc[subp.style] + 1
		TLRels[i] = relp
	end	
	local cmax = 1
	for _, v in pairs(style_proc) do
		if v > cmax then cmax = v end
	end
	return cmax
end

--从第二窗口得到单行改变情况
function timeline_get_syl_change(TLSubs, TLRels, show_start, show_end, config, dtype)
	local sylmax = timeline_sylmax(TLSubs, show_start, show_end)
	for i = show_start, show_end do
		subp = TLSubs[i]
		if not TLRels[i]["R"] then
			timeline_get_syl_change_single(subp, config, dtype, i, sylmax)
		end
	end
end

function timeline_get_syl_change_single(subp, config, dtype, i, sylmax)
	local syls = subp.syllables
	local ttable = {}
	if dtype == 2 then
		if config["text2_" .. i] then
			ttable = LuaSplit(config["text2_" .. i], ' ')
		end
	elseif dtype == 3 then
		for s = 1, sylmax do
			if config["syl_" .. i .. "_" .. s] then
				ttable[s] = config["syl_" .. i .. "_" .. s]
			end
		end
	end
	if #ttable > 0 then
		local smax = math.max(#ttable, #syls)
		for j = 1, smax do
			if j <= #ttable and j <= #syls then
				syls[j]["text"] = ttable[j]
				--aegisub.log(0, 'update:'..ttable[j].."\n")
			elseif j <= #ttable then
				local flag_t = false
				for x = j, #ttable do
					if ttable[x] ~= "" then
						flag_t = true
						break
					end
				end
				if flag_t then
					syls[j] = {
						tag = "\\k",
						duration = 0,
						text = ttable[j]
					}
				end
				--aegisub.log(0, 'update table:'..ttable[j].."\n")
			elseif j <= #syls then
				syls[j]["text"] = ""
				--aegisub.log(0, 'empty:'.."\n")
			else
				--aegisub.log(0, j..#ttable..#syls.."\n")
			end
		end
		timeline_TTS(subp, "syllables")
	end
end

function timeline_sylmax(TLSubs, show_start, show_end)
	local sylmax = 0
	for i = show_start, show_end do--先将关键句按C值归类，同时也记录最多的音节数
		if #TLSubs[i]["syllables"] > sylmax then sylmax = #TLSubs[i]["syllables"] end
	end
	return sylmax
end

function timeline_org_ctrl_dialog(subs, sel, TLSubs, TLRels, show_start, show_end, dtype, styles, headstyle, rmax, rnum, cmax, inum, osettings)
	local showlines = {}
	local showbuttons = util.deep_copy(UI_conf["tlorg_ctrl_buttons"])
	local lnum = 1
	--tlorg_ctrl_buttons = {"Apply", "Last Page", "Next Page", "Refresh", "Back to Subtitle Mode", "Save & Back to Subtitle Mode", "Syllable Mode", "Cancel" },
	if show_end >= #TLSubs then showbuttons[3] = nil end
	if show_start <= 1 then showbuttons[2] = nil end
	if dtype == 1 then showbuttons[5], showbuttons[7] = nil, nil
	elseif dtype == 2 or dtype == 3 then showbuttons[4], showbuttons[6] = nil, nil end
	--if show_end < #TLSubs then table.insert(showbuttons, 2, "Next Page") end
	--if show_start > 1 then table.insert(showbuttons, 2, "Last Page") end
	
	aegisub.progress.task("Creating Dialog...Please Wait")
	--字幕句界面
	if dtype == 1 then
		showlines = util.deep_copy(UI_conf["tlorg_ctrl_dialogs"])
		for i = show_start, show_end do
			local subp = TLSubs[i]
			local relp = TLRels[i]
			--local newline = util.deep_copy(UI_conf["tlorg_ctrl_dialog_edit_elements"])
			local hv, cv
			if relp["R"] then 
				hv = true
				rv = relp["R"]
			else
				hv = false
				rv = 0
			end
			local newline = {
				{ 0, lnum, 1, 1, "checkbox", name = "head_" .. i, value = hv },
				{ 1, lnum, 1, 1, "label", label = subp["no"] - inum + 1 },--需要修改y
				{ 2, lnum, 1, 1, "intedit", name = "row_" .. i,  value = rv, min = 0, max = rmax },
				{ 3, lnum, 1, 1, "intedit", name = "col_" .. i,  value = relp["C"], min = 1, max = 99 },
				{ 4, lnum, 3, 1, "edit", name = "style_" .. i, text = subp.style },
				{ 7, lnum, 15, 1, "edit", name = "text_" .. i, text = subp.text }		
			}	
			table_merge(showlines, newline)
			lnum = lnum + 1
		end
		local settingline = {
			{ 1, lnum + 1, 1, 1, "label", label = "接续" },--需要修改y
			{ 2, lnum + 1, 1, 1, "checkbox", name = "clasp", value = osettings.clasp, label = "起/止占位音节长" },
			{ 3, lnum + 1, 1, 1, "intedit", name = "clasp_left",  value = osettings.clasp_left, min = 0, max = 20000 },
			{ 4, lnum + 1, 1, 1, "intedit", name = "clasp_right",  value = osettings.clasp_right, min = 0, max = 20000 },
			{ 7, lnum + 1, 1, 1, "label", label = "自动重设参数： 接续段数" },--需要修改y
			{ 8, lnum + 1, 1, 1, "dropdown", name = "rnum", items = table_maken(rmax), value = rnum },--需要修改y、items、value
			{ 9, lnum + 1, 1, 1, "label", label = "  关键样式" },--需要修改y
			{ 10, lnum + 1, 1, 1, "dropdown", name = "headstyle", items = styles, value = headstyle },--需要修改y、name、items、value
			{ 11, lnum + 1, 1, 1, "label", label = " 改动自动重设参数将忽略一切手动修改" },--需要修改y
			{ 1, lnum + 2, 1, 1, "label", label = "同步" },--需要修改y
			{ 2, lnum + 2, 1, 1, "checkbox", name = "sync", value = osettings.sync, label = "时间同步  " },
			{ 3, lnum + 2, 1, 1, "checkbox", name = "sync_syls", value = osettings.sync_syls, label = "音节同步  " },
			{ 4, lnum + 2, 1, 1, "checkbox", name = "sync_wchar", value = osettings.sync_wchar, label = "宽字节转音节  " }
		}
		table_merge(showlines, settingline)
		lnum = lnum + 3
	--歌词音节界面
	elseif dtype == 2 or dtype == 3 then
		showlines = util.deep_copy(UI_conf["tlorg_ctrl_dialogs_2"])
		local csort = {}
		local sylmax = timeline_sylmax(TLSubs, show_start, show_end)
		for i = show_start, show_end do--先将关键句按C值归类
			local relp = TLRels[i]
			if not csort[relp["C"]] then csort[relp["C"]] = {} end
			if relp["R"] then table.insert(csort[relp["C"]], i)	end
		end
		for i = show_start, show_end do--再将非关键句按C值归类
			local relp = TLRels[i]
			if not relp["R"] then table.insert(csort[relp["C"]], i)	end
		end
		for _, v in pairs(csort) do--按C值顺序分组显示
			for c2 = 1, #v do
				local i = v[c2]
				local subp = TLSubs[i]
				local relp = TLRels[i]
				local hv, cv
				if relp["R"] then 
					hv = true
					rv = relp["R"]
				else
					hv = false
					rv = 0
				end
				local newline = {
					{ 0, lnum, 1, 1, "label", label = "" },
					{ 1, lnum, 1, 1, "label", label = subp["no"] - inum + 1 },--需要修改y
					{ 2, lnum, 1, 1, "label", label =  "[" .. relp["C"] .. "]" },
				}	
				if hv then newline[1]["label"] = "[√]" end
				local syls_texts = subp.syl_table
				if dtype == 2 then
					if hv then
						table.insert(newline, { 3, lnum, 1, 1, "label", label = table.concat(syls_texts, ' ') })
					else
						table.insert(newline, { 3, lnum, 1, 1, "edit", name = "text2_" .. i, text = table.concat(syls_texts, ' ') })
					end
				else
					for s = 1, sylmax do
						if hv then					
							if syls_texts[s] == "" then
								table.insert(newline, { 2 + s, lnum, 1, 1, "label", label = "--" })
							else
								table.insert(newline, { 2 + s, lnum, 1, 1, "label", label = syls_texts[s] })
							end
						else
							table.insert(newline, { 2 + s, lnum, 1, 1, "edit", name = "syl_" .. i .. "_" .. s, text = syls_texts[s] })	
						end
					end	
				end
							
				table_merge(showlines, newline)
				lnum = lnum + 1
			end
		end				
	end
	--aegisub.debug.out(0, table_serialize(showlines))
	local endline = { 0, lnum, 1, 1, "label", label = "" }
	table.insert(showlines, endline)
	
	return show_dialog(subs, sel, showlines, showbuttons, 'tlorg_ctrl_commands')
end

--更新关系表
function timeline_edit_rels(TLRels, config, show_start, show_end)
	for i = show_start, show_end do
	local relp = TLRels[i]
		if config["head_"..i] and config["row_"..i] and config["row_"..i] > 0 then--关键句且给出的R值>0才承认是关键句并修改R值
			relp["R"] = config["row_"..i]
		else
			relp["R"] = nil
		end
		if config["col_"..i] then relp["C"] = config["col_"..i] end
	end
end

--更新样式、文本和音节表
function timeline_edit_texts(TLSubs, show_start, show_end, button, config)
	local showbuttons = util.deep_copy(UI_conf["tlorg_ctrl_buttons"])
	for i = show_start, show_end do
		local subp = TLSubs[i]
		if config["style_"..i] then subp.style = config["style_"..i] end
		if config["text_"..i] then
			subp.text = config["text_"..i]
			timeline_TTS(subp, "text")
		end
	end
end

function timeline_write_rels(TLSubs, TLRels)
	for i = 1, #TLSubs do
		local subp = TLSubs[i]
		if TLRels[i] and TLRels[i] ~= {} then
			subp.effect =table_serialize(TLRels[i])
		end
	end
	return TLSubs
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

function empty_syllable(t)
	return {tag = "\\k", duration = t, text = ""}
end

--读变量函数：读取aegisub隐藏在subs里的信息
function read_infos(subs, sel, tp)
	local inum = 0
	local info_table = {}
	local style_table = {}
	local others = {}
	for i = 1, #subs do
		inum = inum + 1	
		local subp = subs[i]
		if subp.class == "dialogue" then break
		elseif subp.class == "info" then info_table[i] = subp
		elseif subp.class == "style" then style_table[i] = subp
		else others[i] = subp end			
	end
	return inum, info_table, style_table, others
end

function style_clean(subs, sel, tp)
	local inum, info_table, style_table = read_infos(subs, sel)
	local exist_styles = {}
	for i = inum, #subs do
		subp = subs[i]
		if not exist_styles[subp.style] then
			exist_styles[subp.style] = 1
		else
			exist_styles[subp.style] = exist_styles[subp.style] + 1
		end
	end
	
	local delete_styles = {}
	for k,v in pairs(style_table) do
		if not exist_styles[v.name] then
			delete_styles[k] = v.name
		end
	end
	--aegisub.debug.out(0, #table_keys(delete_styles))
	subs.delete(table_keys(delete_styles))
	delete_styles = table2array(delete_styles)
	local rst = string.format("成功清理了 %s 个样式", #delete_styles)
	if #delete_styles > 0 then
		rst = rst .. string.format("\n分别为 %s", table.concat(delete_styles, ', '))
	end
	aegisub.debug.out(0, rst)
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

--读音节函数：从台词文本读取每行以及每个音节的数据，使用parse_karaoke_data()函数，返回音节数组。
function read_syllables(subs, sel, tp)
	local sublist = {}
	aegisub.progress.task("Reading Lines...")
	for i = 1, #sel do
		local subp = subs[sel[i]]
		if subp.text ~= '' and not subp.comment then--空行和注释行不会被读取 
			sublist[i] = util.deep_copy(subp)
			sublist[i]["no"] = sel[i]
			sublist[i]["syllables"] ={}
--[[			if subp.effect then 
				sublist[i]["rel"] = table_unserialize(subp.effect)--顺便试图序列化行间关系，如果不存在则为nil
			else
				sublist[i]["rel"] = nil
			end
			--]]
			local syls = util.deep_copy(subs[sel[i]])
			aegisub.parse_karaoke_data(syls)
			for j = 1, #syls do
				sublist[i]["syllables"][j] = syls[j]
			end
		end		
	end
	return sublist
end


--写音节函数：把音节数据内容写回选择的行，同时也会更新text属性；tp默认为false，tp为1表示强制写入
function write_syllables(subs, sel, cont, tp)
	local sublist = cont
	for i = 1, #sublist do
		local syls = sublist[i]["syllables"]
		local sub = subs[sel[i]]
		local txtp = ""
		if tp == 1 or not(#syls == 1 and syls[1].duration == 0) then
			txtp = trans_syls2text(syls)
			--[[for j = 1, #syls do
				txtp = txtp..string.format("{%s%d}%s", syls[j].tag, syls[j].duration/10, syls[j].text)
			end--]]
		else --纯字符行去掉行首的空音节标记
			txtp = syls[1].text
		end
		sublist[i]["text"] = txtp
		sub.start_time = sublist[i]["start_time"]
		sub.end_time = sublist[i]["end_time"]
		sub.text = sublist[i]["text"]
		sub.style = sublist[i]["style"]
		sub.effect = sublist[i]["effect"]
		subs[sel[i]] = sub
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

function table_maken(n)
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
function array_search(tbl, val) 
	local pos = nil
	for k, v in pairs(tbl) do
		if v == val then
			pos = k
			break
		end
	end
	return pos
end

--底层函数：替换第一个找到的表值
function table_replace(tbl, val1, val2)
	for k, v in pairs(tbl) do
		if v == val1 then
			tbl[k] = val2
			break
		end
	end
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

function table2array(tbl)
	local arr = {}
	for k, v in pairs(tbl) do
		table.insert(arr, v)
	end
	return arr
end


function trans_syls2table(syls)
	local tbl = {}
	for i = 1, #syls do
		local text = string.gsub(syls[i]["text"], ' ', '_')
		table.insert(tbl, text)--转换的时候，音节里的空格替换成下划线，方便显示
	end
	return tbl
end

function trans_syls2text(syls)
	local text = ""
	for i = 1, #syls do
		text = text..string.format("{%s%d}%s", syls[i].tag, syls[i].duration/10, string.gsub(syls[i]["text"], '_', ' '))--下划线替换成空格，保证实际文本里不出现下划线
	end
	return text
end

function trans_wchar2table(str)
	local sw0 = ""
	local sw = {}
	local length = unicode.len(str)
	local j = 1
	for chr in unicode.chars(str) do--利用unicode长度与ascii长度不同来判断是否宽字符/单词，如果是则载入数组，达到区隔音节的目的
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
	return sw
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

function echo(str)
	aegisub.progress.task("Error")
	aegisub.log(0, str)
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
	--_,_,_,o = read_infos(subs, sel)
	text = ""
	for k,v in ipairs(subs) do
		text = text .. k.."=".. table_serialize(v).."\n"
	end
	aegisub.debug.out(0,text)
end

function test2(subs, sel)
	a = {1, 2}
	aegisub.debug.out(0,a[-1])
end

--批量载入宏		
TLL_macros = {
	{
		script_name = "清理样式",
		script_description = "清理字幕没有用到的样式",
		entry = function(subs, sel) style_clean(subs, sel) end,
		validation = false
	},
	{
		script_name = "划分汉字音节",
		script_description = "自动识别汉字等宽字符并以卡拉OK标签隔断",
		entry = function(subs, sel) show_dialog(subs, sel, 'wchar_dialogs', 'wchar_buttons', 'wchar_commands') end,
		validation = false
	},
	{
		script_name = "空格转占位音节",
		script_description = "把所有空格换成长度为0的音节符号",
		entry = function(subs,sel) kara_add_holder_syls(subs, sel) end,
		validation = false
	},
	{
		script_name = "清理占位音节",
		script_description = "删除字幕前、中、后的占位音节并保证起止时间正确",
		entry = function(subs,sel) kara_strip_holder_syls(subs, sel) end,
		validation = false
	},
	{
		script_name = "批量移动音节",
		script_description = "不改变起止时间，统一移动所选行音节的分隔时间",
		entry = function(subs,sel) show_dialog(subs, sel, 'sylmov_dialogs', 'sylmov_buttons', 'sylmov_commands') end,
		validation = false
	},
	
--[[	{
		script_name = "音节切换",
		script_description = "生成音节文本或根据音节文本修改字幕",
		entry = function(subs,sel,config) show_dialog(subs, sel, 'swift_dialogs', 'swift_buttons', 'swift_commands') end,
		validation = false
	},--]]
	{
		script_name = "时间轴魔术",
		script_description = "通过设置时间轴同步和接续的关系，对字幕的起止时间和音节内容进行批量修改",
		entry = function(subs,sel) timeline_org_main(subs, sel) end,
		validation = false
	},
}

for i = 1, #TLL_macros do
	aegisub.register_macro(script_name.." "..script_version.."/"..TLL_macros[i]["script_name"], TLL_macros[i]["script_description"], TLL_macros[i]["entry"], TLL_macros[i]["validation"])
end
aegisub.register_macro("测试", script_description, test2)