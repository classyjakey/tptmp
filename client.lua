--Cracker64's Lua Multiplayer Script
--See forum post http://powdertoy.co.uk/Discussions/Thread/View.html?Thread=14352 for more info
--VER 1.2 UPDATE http://pastebin.com/raw.php?i=33mxQcvW

--Version 1.2

--TODO's
--finish tool functions
--check alt on mouseup for line/box snap
-------------------------------------------------------

--CHANGES:
--Most things synced.  Awaiting new tpt api functions for full sync
--It connects to server! and chat
--Basic inputbox
--Basic chat box, moving window
--Cleared everything

local issocket,socket = pcall(require,"socket")
if MANAGER_EXISTS then using_manager=true else MANAGER_PRINT=print end

local PORT = 34403 --Change 34403 to your desired port
local KEYBOARD = 1 --only change if you have issues. Only other option right now is 2(finnish).
local pauseNextFrame=false

local tptversion = tpt.version.build
local jacobsmod = tpt.version.jacob1s_mod~=nil
math.randomseed(os.time())
local username = tpt.get_name()
if username=="" then error"Please Identify" end
local con = {connected = false,
		 socket = nil,
		 members = nil,
		 pingTime = os.time()+60}
local function conSend(cmd,msg,endNull)
	if not con.connected then return false,"Not connected" end
	msg = msg or ""
	if endNull then msg = msg.."\0" end
	if cmd then msg = string.char(cmd)..msg end
	--print("sent "..msg)
	con.socket:send(msg)
end
local function connectToMniip(ip,port)
	if con.connected then return false,"Already connected" end
	ip = ip or "mniip.com"
	port = port or 34403
	local sock = socket.tcp()
	sock:settimeout(10)
	local s,r = sock:connect(ip,port)
	if not s then return false,r end
	sock:settimeout(0)
	sock:setoption("keepalive",true)
	sock:send(string.char(tpt.version.major)..string.char(tpt.version.minor)..username.."\0")
	local c,r
	while not c do
	c,r = sock:receive(1)
	if not c and r~="timeout" then break end
	end
	if not c and r~="timeout" then return false,r end

	if c~= "\1" then 
	if c=="\0" then
		local err=""
		c,r = sock:receive(1)
		while c~="\0" do
		err = err..c
		c,r = sock:receive(1)
		end
		return false,err
	end
	return false,"Bad Connect"
	end

	con.socket = sock
	con.connected = true
	return true
end
--get up to a null (\0)
local function conGetNull()
	local c,r = con.socket:receive(1)
	local rstring=""
	while c~="\0" do
	rstring = rstring..c
	c,r = con.socket:receive(1)
	end
	return rstring
end
--get next char/byte
local function conGetByte()
	local c,r
	while not c do
	c,r = con.socket:receive(1)
	end
	return c
end
--return table of arguments
local function getArgs(msg)
	if not msg then return {} end
	local args = {}
	for word in msg:gmatch("([^%s%c]+)") do
	table.insert(args,word)
	end
	return args
end

local GoLrule = {{0,0,0,0,0,0,0,0,0,2},{0,0,1,3,0,0,0,0,0,2},{0,0,1,3,0,0,2,0,0,2},{0,0,0,2,3,3,1,1,0,2},{0,1,1,2,0,1,2,0,0,2},{0,0,0,3,1,0,3,3,3,2},{0,1,0,3,0,3,0,2,1,2},{0,0,1,2,1,1,2,0,2,2},{0,0,1,3,0,2,0,2,1,2},{0,0,0,2,0,3,3,3,3,2},{0,0,0,3,3,0,0,0,0,2},{0,0,0,2,2,3,0,0,0,2},{0,0,1,3,0,1,3,3,3,2},{0,0,2,0,0,0,0,0,0,2},{0,1,1,3,1,1,0,0,0,2},{0,0,1,3,0,1,1,3,3,2},{0,0,1,1,3,3,2,2,2,2},{0,3,0,0,0,0,0,0,0,2},{0,3,0,3,0,3,0,3,0,2},{1,0,0,2,2,3,1,1,3,2},{0,0,0,3,1,1,0,2,1,4},{0,1,1,2,1,0,0,0,0,3},{0,0,2,1,1,1,1,2,2,6},{0,1,1,2,2,0,0,0,0,3},{0,0,2,0,2,0,3,0,0,3}}
--get different lists for other language keyboards
local keyboardshift = { {before=" qwertyuiopasdfghjklzxcvbnm1234567890-=.,/`|;'[]\\",after=" QWERTYUIOPASDFGHJKLZXCVBNM!@#$%^&*()_+><?~\\:\"{}|",},{before=" qwertyuiopasdfghjklzxcvbnm1234567890+,.-'��������������<",after=" QWERTYUIOPASDFGHJKLZXCVBNM!\"#�������%&/()=?;:_*`^>",}  }
local keyboardaltrg = { {nil},{before=" qwertyuiopasdfghjklzxcvbnm1234567890+,.-'�������<",after=" qwertyuiopasdfghjklzxcvbnm1@�������$�6{[]}\\,.-'~|",},}

local function shift(s)
	if keyboardshift[KEYBOARD]~=nil then
		return (s:gsub("(.)",function(c)return keyboardshift[KEYBOARD]["after"]:sub(keyboardshift[KEYBOARD]["before"]:find(c,1,true))end))
	else return s end
end
local function altgr(s)
	if keyboardaltgr[KEYBOARD]~=nil then
		return (s:gsub("(.)",function(c)return keyboardaltgr[KEYBOARD]["after"]:sub(keyboardaltgr[KEYBOARD]["before"]:find(c,1,true))end))
	else return s end
end

local ui_base local ui_box local ui_text local ui_button local ui_scrollbar local ui_inputbox local ui_chatbox
ui_base = {
new = function()
	local b={}
	b.drawlist = {}
	function b:drawadd(f)
		table.insert(self.drawlist,f)
	end
	function b:draw(...)
		for _,f in ipairs(self.drawlist) do
			if type(f)=="function" then
				f(self,unpack(arg))
			end
		end
	end
	b.movelist = {}
	function b:moveadd(f)
		table.insert(self.movelist,f)
	end
	function b:onmove(x,y)
		for _,f in ipairs(self.movelist) do
			if type(f)=="function" then
				f(self,x,y)
			end
		end
	end
	return b
end
}
ui_box = {
new = function(x,y,w,h,r,g,b)
	local box=ui_base.new()
	box.x=x box.y=y box.w=w box.h=h box.x2=x+w box.y2=y+h
	box.r=r or 255 box.g=g or 255 box.b=b or 255
	function box:setcolor(r,g,b) self.r=r self.g=g self.b=b end
	function box:setbackground(r,g,b,a) self.br=r self.bg=g self.bb=b self.ba=a end
	box.drawbox=true
	box.drawbackground=false
	box:drawadd(function(self) if self.drawbackground then tpt.fillrect(self.x,self.y,self.w,self.h,self.br,self.bg,self.bb,self.ba) end
								if self.drawbox then tpt.drawrect(self.x,self.y,self.w,self.h,self.r,self.g,self.b) end end)
	box:moveadd(function(self,x,y)
		if x then self.x=self.x+x self.x2=self.x2+x end
		if y then self.y=self.y+y self.y2=self.y2+y end
	end)
	return box
end
}
ui_text = {
new = function(text,x,y,r,g,b)
	local txt = ui_base.new()
	txt.text = text
	txt.x=x or 0 txt.y=y or 0 txt.r=r or 255 txt.g=g or 255 txt.b=b or 255
	function txt:setcolor(r,g,b) self.r=r self.g=g self.b=b end
	txt:drawadd(function(self,x,y) tpt.drawtext(x or self.x,y or self.y,self.text,self.r,self.g,self.b) end)
	txt:moveadd(function(self,x,y) 
		if x then self.x=self.x+x end
		if y then self.y=self.y+y end   
	end)
	function txt:process() return false end
	return txt
end,
--Scrolls while holding mouse over
newscroll = function(text,x,y,vis,force,r,g,b)
	local txt = ui_text.new(text,x,y,r,g,b)
	if not force and tpt.textwidth(text)<vis then return txt end
	txt.visible=vis
	txt.length=string.len(text)
	txt.start=1
	local last=2
	while tpt.textwidth(text:sub(1,last))<vis and last<=txt.length do
		last=last+1
	end
	txt.last=last-1
	txt.minlast=last-1
	txt.ppl=((txt.visible-6)/(txt.length-txt.minlast+1))
	function txt:update(text,pos)
		if text then 
			self.text=text
			self.length=string.len(text)
			local last=2
			while tpt.textwidth(text:sub(1,last))<self.visible and last<=self.length do
				last=last+1
			end
			self.minlast=last-1
			self.ppl=((self.visible-6)/(self.length-self.minlast+1))
			if not pos then self.last=self.minlast end
		end
		if pos then
			if pos>=self.last and pos<=self.length then --more than current visible
				local newlast = pos
				local newstart=1
				while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
				end
				self.start=newstart self.last=newlast
			elseif pos<self.start and pos>0 then --position less than current visible
				local newstart=pos
				local newlast=pos+1
				while tpt.textwidth(self.text:sub(newstart,newlast))<self.visible and newlast<self.length do
						newlast=newlast+1
				end
				self.start=newstart self.last=newlast-1
			end
			--keep strings as long as possible (pulls from left)
			local newlast=self.last
			if newlast<self.minlast then newlast=self.minlast end
			local newstart=1
			while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
			end
			self.start=newstart self.last=newlast
		end
	end
	txt.drawlist={} --reset draw
	txt:drawadd(function(self,x,y) 
		tpt.drawtext(x or self.x,y or self.y, self.text:sub(self.start,self.last) ,self.r,self.g,self.b) 
	end)
	function txt:process(mx,my,button,event,wheel)
		if event==3 then
			local newlast = math.floor((mx-self.x)/self.ppl)+self.minlast
			if newlast<self.minlast then newlast=self.minlast end
			if newlast>0 and newlast~=self.last then
				local newstart=1
				while tpt.textwidth(self.text:sub(newstart,newlast))>= self.visible do
					newstart=newstart+1
				end
				self.start=newstart self.last=newlast
			end
		end
	end
	return txt
end
}
ui_inputbox = {
new=function(x,y,w,h)
	local intext=ui_box.new(x,y,w,h)
	intext.cursor=0
	intext.focus=false
	intext.t=ui_text.newscroll("",x+2,y+2,w-2,true)
	intext:drawadd(function(self)
		local cursoradjust=tpt.textwidth(self.t.text:sub(self.t.start,self.cursor))+2
		tpt.drawline(self.x+cursoradjust,self.y,self.x+cursoradjust,self.y+10,255,255,255)
		self.t:draw()
	end)
	intext:moveadd(function(self,x,y) self.t:onmove(x,y) end)
	function intext:setfocus(focus)
		self.focus=focus
		if focus then tpt.set_shortcuts(0) self:setcolor(255,255,0)
		else tpt.set_shortcuts(1) self:setcolor(255,255,255) end
	end
	function intext:movecursor(amt)
		self.cursor = self.cursor+amt
		if self.cursor>self.t.length then self.cursor = self.t.length end
		if self.cursor<0 then self.cursor = 0 return end
	end
	function intext:textprocess(key,nkey,modifier,event)
		local modi = (modifier%1024)
		if not self.focus then return false end
		if event~=1 then return end
		if nkey==13 then local text=self.t.text self.cursor=0 self.t.text="" return text end --enter
		local newstr
		if nkey==275 then self:movecursor(1) self.t:update(nil,self.cursor) return end --right
		if nkey==276 then self:movecursor(-1) self.t:update(nil,self.cursor) return end --left
		if nkey==8 then newstr=self.t.text:sub(1,self.cursor-1) .. self.t.text:sub(self.cursor+1) self:movecursor(-1) --back
		elseif nkey==127 then newstr=self.t.text:sub(1,self.cursor) .. self.t.text:sub(self.cursor+2) --delete
		else 
			if nkey<32 or nkey>=127 then return end --normal key
			local addkey = (modi==1 or modi==2) and shift(key) or key
			if (math.floor(modi/512))==1 then addkey=altgr(key) end
			newstr = self.t.text:sub(1,self.cursor) .. addkey .. self.t.text:sub(self.cursor+1)
			self.t:update(newstr,self.cursor+1)
			self:movecursor(1)
			return
		end
		if newstr then
			self.t:update(newstr,self.cursor)
		end
		--some actual text processing, lol
	end
	return intext
end
}
ui_scrollbar = {
new = function(x,y,h,t,m)
	local bar = ui_base.new() --use line object as base?
	bar.x=x bar.y=y bar.h=h
	bar.total=t
	bar.numshown=m
	bar.pos=0
	bar.length=math.floor((1/math.ceil(bar.total-bar.numshown+1))*bar.h)
	bar.soffset=math.floor(bar.pos*((bar.h-bar.length)/(bar.total-bar.numshown)))
	function bar:update(total,shown,pos)
		self.pos=pos or 0
		if self.pos<0 then self.pos=0 end
		self.total=total
		self.numshown=shown
		self.length= math.floor((1/math.ceil(self.total-self.numshown+1))*self.h)
		self.soffset= math.floor(self.pos*((self.h-self.length)/(self.total-self.numshown)))
	end
	function bar:move(wheel)
		self.pos = self.pos-wheel
		if self.pos < 0 then self.pos=0 end
		if self.pos > (self.total-self.numshown) then self.pos=(self.total-self.numshown) end
		self.soffset= math.floor(self.pos*((self.h-self.length)/(self.total-self.numshown)))
	end
	bar:drawadd(function(self)
		if self.total > self.numshown then
			tpt.drawline(self.x,self.y+self.soffset,self.x,self.y+self.soffset+self.length)
		end
	end)
	bar:moveadd(function(self,x,y) 
		if x then self.x=self.x+x end
		if y then self.y=self.y+y end   
	end)
	function bar:process(mx,my,button,event,wheel)
		if wheel~=0 and not hidden_mode then
			if self.total > self.numshown then
				local previous = self.pos
				self:move(wheel)
				if self.pos~=previous then
					return wheel
				end
			end
		end
		--possibly click the bar and drag?
		return false
	end
	return bar
end
}
ui_button = {
new = function(x,y,w,h,f,text)
	local b = ui_box.new(x,y,w,h)
	b.f=f
	b.t=ui_text.new(text,x+2,y+2)
	b.drawbox=false
	b.almostselected=false
	b.invert=true
	b:drawadd(function(self) 
		if self.invert and self.almostselected then
			self.almostselected=false
			tpt.fillrect(self.x,self.y,self.w,self.h)
			local tr=self.t.r local tg=self.t.g local tb=self.t.b
			b.t:setcolor(0,0,0)
			b.t:draw()
			b.t:setcolor(tr,tg,tb)
		else
			b.t:draw() 
		end
	end)
	b:moveadd(function(self,x,y)
		self.t:onmove(x,y) 
	end)
	function b:process(mx,my,button,event,wheel)
		if mx<self.x or mx>self.x2 or my<self.y or my>self.y2 then return false end
		if event==3 then self.almostselected=true end
		if event==2 then self:f() end
		return true
	end
	return b
end
}
ui_chatbox = {
new=function(x,y,w,h)
	local chat=ui_box.new(x,y,w,h)
	chat.moving=false
	chat.lastx=0
	chat.lasty=0
	chat.relx=0
	chat.rely=0
	chat.shown_lines=math.floor(chat.h/10)-2 --one line for top, one for chat
	chat.max_width=chat.w-4
	chat.max_lines=200
	chat.lines = {}
	chat.scrollbar = ui_scrollbar.new(chat.x2-2,chat.y+11,chat.h-22,0,chat.shown_lines)
	chat.inputbox = ui_inputbox.new(x,chat.y2-10,w,10)
	chat:drawadd(function(self)
		tpt.drawtext(self.x+50,self.y+2,"Chat Box")
		tpt.drawline(self.x+1,self.y+10,self.x2-1,self.y+10,120,120,120)
		self.scrollbar:draw()
		local count=0
		for i,line in ipairs(self.lines) do
			if i>self.scrollbar.pos and i<= self.scrollbar.pos+self.shown_lines then
				line:draw(self.x+3,self.y+12+(count*10))
				count = count+1
			end
		end
		self.inputbox:draw()
	end)
	chat:moveadd(function(self,x,y)
		for i,line in ipairs(self.lines) do
			line:onmove(x,y)
		end
		self.scrollbar:onmove(x,y)
		self.inputbox:onmove(x,y)
	end)
	function chat:addline(line,r,g,b)
		if not line or line=="" then return end --No blank lines
		table.insert(self.lines,ui_text.newscroll(line,self.x,0,self.max_width,false,r,g,b))
		if #self.lines>self.max_lines then table.remove(self.lines,1) end
		self.scrollbar:update(#self.lines,self.shown_lines,#self.lines-self.shown_lines)
	end
	function chat:process(mx,my,button,event,wheel)
		if self.moving and event==3 then
			local newx,newy = mx-self.relx,my-self.rely
			local ax,ay = 0,0
			if newx<0 then ax = newx end
			if newy<0 then ay = newy end
			if (newx+self.w)>=612 then ax = newx+self.w-612 end
			if (newy+self.h)>=384 then ay = newy+self.h-384 end
			self:onmove(mx-self.lastx-ax,my-self.lasty-ay)
			self.lastx=mx-ax
			self.lasty=my-ay
			return true
		end
		if self.moving and event==2 then self.moving=false return true end
		if mx<self.x or mx>self.x2 or my<self.y or my>self.y2 then self.inputbox:setfocus(false) return false end
		self.scrollbar:process(mx,my,button,event,wheel)
		local which = math.floor((my-self.y)/10)
		if event==1 and which==0 then self.moving=true self.lastx=mx self.lasty=my self.relx=mx-self.x self.rely=my-self.y return true end
		if which==self.shown_lines+1 then self.inputbox:setfocus(true) return true else self.inputbox:setfocus(false) end --trigger input_box
		if which>0 and which<self.shown_lines+1 and self.lines[which+self.scrollbar.pos] then self.lines[which+self.scrollbar.pos]:process(mx,my,button,event,wheel) end
		return true
	end
	--commands for chat window
	chatcommands = {
	connect = function(self,msg,args)
		if not issocket then self:addline("No luasockets found") return end
		local s,r = connectToMniip(args[1],tonumber(args[2]))
		if not s then self:addline(r) end
	end,
	send = function(self,msg,args)
		if tonumber(args[1]) and args[2] then
		local withNull=false
		if args[2]=="true" then withNull=true end
		rest = rest or ""
		conSend(tonumber(args[1]),rest:sub(#args[1]+#args[2]+2),withNull)
		end
	end,
	quit = function(self,msg,args)
		con.socket:close()
		con.connected = false
		con.members = {}
	end,
	join = function(self,msg,args)
		if args[1] then conSend(16,args[1],true) end	
	end,
	stamp = function(self,msg,args)
		local stm = sim.saveStamp(0,0,611,383)
		local f = io.open("stamps/"..stm..".stm","rb")
		local data = f:read("*a")
		f:close()
		os.remove("stamps/"..stm..".stm")
		conSend(65,string.char(math.floor(#data/65536))..string.char(math.floor(#data/256)%256)..string.char(#data%256)..data)
		data=nil
	end,
	}
	function chat:textprocess(key,nkey,modifier,event)
		local text = self.inputbox:textprocess(key,nkey,modifier,event)
		if text then
			local cmd = text:match("^/([^%s]+)")
			if cmd then
				local rest=text:sub(#cmd+3)
				local args = getArgs(rest)
				self:addline("CMD: "..cmd.." "..rest)
				if chatcommands[cmd] then chatcommands[cmd](self,msg,args) end
			else
				--normal chat
				conSend(19,text,true)
				self:addline(username .. ": ".. text) 
			end
		end
		if text==false then return false end
	end
	return chat
end
}

local function incurrentbrush(i,j,rx,ry,brush)
	if brush==0 then
		return (i^2*ry^2+j^2*rx^2<=rx^2*ry^2)
	elseif brush==1 then
		return (math.abs(i)<=rx and math.abs(j)<=ry)
	elseif brush==2 then
		return ((math.abs((rx+2*i)*ry+rx*j) + math.abs(2*rx*(j-ry)) + math.abs((rx-2*i)*ry+rx*j))<=(4*rx*ry))
	else
		return false
	end
end
local function inbrushborder(i,j,rx,ry,brush)
	return incurrentbrush(i,j,rx,ry,brush) and not incurrentbrush(i,j,rx-1,ry-1,brush)
end
local function valid(x,y,energycheck,c)
    if x >= 0 and x < 612 and y >= 0 and y < 384 then
        if energycheck then
           if energytypes[tpt.get_property("type",x,y)] then return false end
       end
    return true end
end

chatwindow = ui_chatbox.new(100,100,150,200)
chatwindow:setbackground(10,10,10,235) chatwindow.drawbackground=true

local energytypes = { [18]=true, [31]=true, [136]=true, }
local tools = { [299]=true, [300]=true, [301]=true, [302]=true, [303]=true, [304]=true,}
local eleNameTable = {
["DEFAULT_PT_LIFE_GOL"] = 256,["DEFAULT_PT_LIFE_HLIF"] = 257,["DEFAULT_PT_LIFE_ASIM"] = 258,["DEFAULT_PT_LIFE_2x2"] = 259,["DEFAULT_PT_LIFE_DANI"] = 260,
["DEFAULT_PT_LIFE_AMOE"] = 261,["DEFAULT_PT_LIFE_MOVE"] = 262,["DEFAULT_PT_LIFE_PGOL"] = 263,["DEFAULT_PT_LIFE_DMOE"] = 264,["DEFAULT_PT_LIFE_34"] = 265,
["DEFAULT_PT_LIFE_LLIF"] = 276,["DEFAULT_PT_LIFE_STAN"] = 267,["DEFAULT_PT_LIFE_SEED"] = 268,["DEFAULT_PT_LIFE_MAZE"] = 269,["DEFAULT_PT_LIFE_COAG"] = 270,
["DEFAULT_PT_LIFE_WALL"] = 271,["DEFAULT_PT_LIFE_GNAR"] = 272,["DEFAULT_PT_LIFE_REPL"] = 273,["DEFAULT_PT_LIFE_MYST"] = 274,["DEFAULT_PT_LIFE_LOTE"] = 275,
["DEFAULT_PT_LIFE_FRG2"] = 276,["DEFAULT_PT_LIFE_STAR"] = 277,["DEFAULT_PT_LIFE_FROG"] = 278,["DEFAULT_PT_LIFE_BRAN"] = 279,
["DEFAULT_WL_0"] = 280,["DEFAULT_WL_1"] = 281,["DEFAULT_WL_2"] = 282,["DEFAULT_WL_3"] = 283,["DEFAULT_WL_4"] = 284,
["DEFAULT_WL_5"] = 285,["DEFAULT_WL_6"] = 286,["DEFAULT_WL_7"] = 287,["DEFAULT_WL_8"] = 288,["DEFAULT_WL_9"] = 289,["DEFAULT_WL_10"] = 290,
["DEFAULT_WL_11"] = 291,["DEFAULT_WL_12"] = 292,["DEFAULT_WL_13"] = 293,["DEFAULT_WL_14"] = 294,["DEFAULT_WL_15"] = 295,
["DEFAULT_UI_SAMPLE"] = 296,["DEFAULT_UI_SIGN"] = 297,["DEFAULT_UI_PROPERTY"] = 298,["DEFAULT_UI_WIND"] = 299,
["DEFAULT_TOOL_HEAT"] = 300,["DEFAULT_TOOL_COOL"] = 301,["DEFAULT_TOOL_VAC"] = 302,["DEFAULT_TOOL_AIR"] = 303,["DEFAULT_TOOL_GRAV"] = 304,["DEFAULT_TOOL_NGRV"] = 305,
["DEFAULT_DECOR_CLR"] = 306,["DEFAULT_DECOR_SET"] = 307,["DEFAULT_DECOR_SMDG"] = 308,["DEFAULT_DECOR_DIV"] = 309,["DEFAULT_DECOR_MUL"] = 310,["DEFAULT_DECOR_SUB"] = 311,["DEFAULT_DECOR_ADD"] = 312,	
}
local golStart,golEnd=256,279
local wallStart,wallEnd=280,295
local create
--special functions to create oddly named things, mostly tools.
local eleSpecialCreate = {
	--Some tools that are harmless, don't use default delete
	--Sample,sign,prop
	[296] = function(x,y,rx,ry) end,
	[297] = function(x,y,rx,ry) end,
	[298] = function(x,y,rx,ry) end,
	
	--WIND
	[299] = function(x,y,rx,ry) end,
	
	--HEAT
	[300] = function(x,y,rx,ry)
				local temp = tpt.get_property("type",x,y)>0 and tpt.get_property("temp",x,y) or nil
				if temp~=nil and temp<9999 then
					local heatchange = 4 --implement more temp changes later (ctrl-shift)
					tpt.set_property("temp",math.min(temp+heatchange,9999),x,y)
				end
			end,
	--COOL
	[301] = function(x,y,rx,ry)
				local temp = tpt.get_property("type",x,y)>0 and tpt.get_property("temp",x,y) or nil
				if temp~=nil and temp>0 then
					local heatchange = 4 --implement more temp changes later (ctrl-shift)
					tpt.set_property("temp",math.max(temp-heatchange,0),x,y)
				end
			end,
	--VAC and AIR are realllyy laggy, fix to not use particle create
	[302] = function(x,y,rx,ry)
				sim.pressure(x/4,y/4,sim.pressure(x/4,y/4)-0.025)
			end,
	[303] = function(x,y,rx,ry)
				sim.pressure(x/4,y/4,sim.pressure(x/4,y/4)+0.025)
			end,

	--DECO functions
	[306] = function(x,y,rx,ry) tpt.set_property("dcolour",0,x,y) end,
	[307] = function(x,y,rx,ry) --[[tpt.set_property("dcolour",???,x,y) how can we know users docolour selection? powder.pref?]]end,
	[308] = function(x,y,rx,ry) end,
	[309] = function(x,y,rx,ry) end,
	[310] = function(x,y,rx,ry) end,
	[311] = function(x,y,rx,ry) end,
	[312] = function(x,y,rx,ry) end,
}
setmetatable(eleSpecialCreate,{__index=
function(t,k)
	if k<256 then return end
	if k<=golEnd then
		return function(x,y,rx,ry) create(-2,x,y,(k-golStart)*256 + 78) end
	end
end})

--Functions that do stuff in powdertoy
create = function(p,x,y,c)
	local spec = eleSpecialCreate[c]
	if spec then spec(x,y) return end
    if c==0 then 
        tpt.delete(x,y)
    else
        local i = sim.partCreate(p,x,y,c)
    end
end
sim.createBox = sim.createBox or function(x1,y1,x2,y2,c)
   local i = 0 local j = 0
   if x1>x2 then i=x2 x2=x1 x1=i end
   if y1>y2 then j=y2 y2=y1 y1=j end
   for j=y1, y2 do
	  for i=x1, x2 do
		create(-2,i,j,c)
	  end
   end
end
local function createBoxAny(x1,y1,x2,y2,c)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWallBox(x1,y1,x2,y2,c-wallStart)
		end
		return --other tools need functions here
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createBox(x1,y1,x2,y2,c)
end
local function oldCreateParts(x,y,rx,ry,c,brush,fill)
   local energycheck = energytypes[c]
   if c == 87 or c == 158 then create(-2,x,y,c) return end --only draw one pixel of FIGH and LIGH

   if rx<=0 then--0 radius loop prevention
	  for j=y-ry,y+ry do
		 if valid(x,j,energycheck,c) then
			create(-2,x,j,c) end
	  end
	  return
   end
   local tempy = y local oldy = y
   if brush==2 then tempy=y+ry end
   for i = x - rx, x do
	  oldy = tempy
	  local check = incurrentbrush(i-x,tempy-y,rx,ry,brush)
	  if check then
		  while check do
			 tempy = tempy - 1
			 check = incurrentbrush(i-x,tempy-y,rx,ry,brush)
		  end
		  tempy = tempy + 1
		  if fill then
			 local jmax = 2*y - tempy
			 if brush == 2 then jmax=y+ry end
			 for j = tempy, jmax do
				if valid(i,j,energycheck,c) then
				   create(-2,i,j,c) end
				if i~=x and valid(x+x-i,j,energycheck,c) then
				   create(-2,x+x-i,j,c) end
			 end
		  else
			 if (oldy ~= tempy and brush~=1) or i==x-rx then oldy = oldy - 1 end
			 for j = tempy, oldy+1 do
				local i2=2*x-i local j2 = 2*y-j
				if brush==2 then j2=y+ry end
				if valid(i,j,energycheck,c) then
				   create(-2,i,j,c) end
				if i2~=i and valid(i2,j,energycheck,c) then
				   create(-2,i2,j,c) end
				if j2~=j and valid(i,j2,energycheck,c) then
				   create(-2,i,j2,c) end
				if i2~=i and j2~=j and valid(i2,j2,energycheck,c) then
				   create(-2,i2,j2,c) end
			 end
		  end
	   end
   end
end
sim.createParts = sim.createParts or oldCreateParts
local function createPartsAny(x,y,rx,ry,c,brush)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWalls(x,y,rx,ry,c-wallStart,brush)
		elseif eleSpecialCreate[c] then
			oldCreateParts(x,y,rx,ry,c,brush)
		end
		--odd tools need brush functions here
		return
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createParts(x,y,rx,ry,c,brush)
end
sim.createLine = sim.createLine or function(x1,y1,x2,y2,rx,ry,c,brush)
   if c == 87 or c == 158 then return end --never do lines of FIGH and LIGH
   local cp = math.abs(y2-y1)>math.abs(x2-x1)
   local x = 0 local y = 0 local dx = 0 local dy = 0 local sy = 0 local e = 0.0 local de = 0.0 local first = true
   if cp then y = x1 x1 = y1 y1 = y y = x2 x2 = y2 y2 = y end
   if x1 > x2 then y = x1 x1 = x2 x2 = y y = y1 y1 = y2 y2 = y end
   dx = x2 - x1 dy = math.abs(y2 - y1) if dx ~= 0 then de = dy/dx end
   y = y1 if y1 < y2 then sy = 1 else sy = -1 end
   for x = x1, x2 do
      if cp then
         createPartsAny(y,x,rx,ry,c,brush,first)
      else
         createPartsAny(x,y,rx,ry,c,brush,first)
      end
      first = false
      e = e + de
      if e >= 0.5 then
         y = y + sy
         e = e - 1
         if y1<y2 then
             if y>y2 then return end
         elseif y<y2 then return end
         if (rx+ry)==0 or c>=wallStart then
            if cp then
               createPartsAny(y,x,rx,ry,c,brush,first)
            else
               createPartsAny(x,y,rx,ry,c,brush,first)
            end
         end
      end
   end
end
local function createLineAny(x1,y1,x2,y2,rx,ry,c,brush)
	if c>=wallStart then
		if c<= wallEnd then
			sim.createWallLine(x1,y1,x2,y2,rx,ry,c-wallStart,brush)
		end
		--odd tools need line functions here
		return
	elseif c>=golStart then
		c = 78+(c-golStart)*256
	end
	sim.createLine(x1,y1,x2,y2,rx,ry,c,brush)
end
sim.floodParts = sim.floodParts or function(x,y,c,cm,bm)
    local x1=x local x2=x
    if cm==-1 then
        if c==0 then
            cm = tpt.get_property("type",x,y)
            if cm==0 then return false end
        else
            cm = 0
        end
    end
    --wall check here
    while x1>=4 do
        if (tpt.get_property("type",x1-1,y)~=cm) then break end
        x1 = x1-1
    end
    while x2<=608 do
        if (tpt.get_property("type",x2+1,y)~=cm) then break end
        x2 = x2+1
    end
    for x=x1, x2 do
        if c==0 then tpt.delete(x,y) end
        if c>0 and c<222 then create(-2,x,y,c) end
    end
    if y>=5 then
        for x=x1,x2 do
            if tpt.get_property("type",x,y-1)==cm then
                if not sim.floodParts(x,y-1,c,cm,bm) then
                    return false
                end end end
    end
    if y<379 then
        for x=x1,x2 do
            if tpt.get_property("type",x,y+1)==cm then
                if not sim.floodParts(x,y+1,c,cm,bm) then
                    return false
                end end end
    end
    return true
end
--shortcut to part or wall flood
local function floodAny(x,y,c,cm,bm)
	if c>=wallStart then
		if c<= wallEnd then
			sim.floodWalls(x,y,c-wallStart,cm,bm)
		end
		--other tools shouldn't flood
		return
	elseif c>=golStart then --GoL adjust
		c = 78+(c-golStart)*256
	end
	sim.floodParts(x,y,c,cm,bm)
end

sim.clearSim = sim.clearSim or function()
	tpt.start_getPartIndex()
	while tpt.next_getPartIndex() do
	   local index = tpt.getPartIndex()
	   tpt.set_property("type",0,index)
	end
	tpt.reset_velocity(0,0,153,96)
	tpt.set_pressure(0,0,153,96,0)
	tpt.set_wallmap(0,0,153,96,0)
end

--clicky click
local function playerMouseClick(id,btn,ev)
	local user = con.members[id]
	local createE, checkBut
	
	--MANAGER_PRINT(tostring(btn)..tostring(ev))
	if ev==0 then return end
	if btn==1 then
		user.rbtn,user.abtn = false,false
		createE,checkBut=user.selectedl,user.lbtn
	elseif btn==2 then
		user.rbtn,user.lbtn = false,false
		createE,checkBut=user.selecteda,user.abtn
	elseif btn==4 then
		user.lbtn,user.abtn = false,false
		createE,checkBut=user.selectedr,user.rbtn
	else return end
	
	if user.mousex>=612 or user.mousey>=384 then user.drawtype=false return end
	
	if ev==1 then
		user.pmx,user.pmy = user.mousex,user.mousey
		if not user.drawtype then
			--left box
			if user.ctrl and not user.shift then user.drawtype = 2 return end
			--left line
			if user.shift and not user.ctrl then user.drawtype = 1 return end
			--floodfill
			if user.ctrl and user.shift then floodAny(user.mousex,user.mousey,createE,-1) user.drawtype = 3 return end
			--an alt click
			if user.alt then return end
			user.drawtype=4 --normal hold
		end
		createPartsAny(user.mousex,user.mousey,user.brushx,user.brushy,createE,user.brush,true)
	elseif ev==2 and checkBut and user.drawtype then
		--need to check alt on up!!!
		if user.drawtype==2 then createBoxAny(user.mousex,user.mousey,user.pmx,user.pmy,createE)
		else createLineAny(user.mousex,user.mousey,user.pmx,user.pmy,user.brushx,user.brushy,createE,user.brush) end
		user.drawtype=false
		user.pmx,user.pmy = user.mousex,user.mousey
	end
end
--To draw continued lines
local function playerMouseMove(id)
	local user = con.members[id]
	local createE, checkBut
	if user.lbtn then
		createE,checkBut=user.selectedl,user.lbtn
	elseif user.rbtn then
		createE,checkBut=user.selectedr,user.rbtn
	elseif user.abtn then
		createE,checkBut=user.selecteda,user.abtn
	end
	if user.drawtype~=4 then if user.drawtype==3 then floodAny(user.mousex,user.mousey,createE,-1) end return end
	if checkBut==3 then
		if user.mousex>=612 then user.mousex=611 end
		if user.mousey>=384 then user.mousey=383 end
		createLineAny(user.mousex,user.mousey,user.pmx,user.pmy,user.brushx,user.brushy,createE,user.brush)
		user.pmx,user.pmy = user.mousex,user.mousey
	end

end

local dataCmds = {
	[2] = function() conSend(2,"",false) end,
	[16] = function()
	--room members
		con.members = {}
		local amount = conGetByte():byte()
		local peeps = {}
		for i=1,amount do
			local id = conGetByte():byte()
			con.members[id]={name=conGetNull(),mousex=0,mousey=0,brushx=4,brushy=4,brush=0,selectedl=1,selectedr=0,selecteda=296,lbtn=false,abtn=false,rbtn=false,ctrl=false,shift=false,alt=false}
			local name = con.members[id].name
			table.insert(peeps,name)
		end
		chatwindow:addline("Online: "..table.concat(peeps," "))
	end,
	[17]= function()
		local id = conGetByte():byte()
		con.members[id] ={name=conGetNull(),mousex=0,mousey=0,brushx=4,brushy=4,brush=0,selectedl=1,selectedr=0,selecteda=296,lbtn=false,abtn=false,rbtn=false,ctrl=false,shift=false,alt=false}
		chatwindow:addline(con.members[id].name.." has joined")
	end,
	[18] = function()
		local id = conGetByte():byte()
		chatwindow:addline(con.members[id].name.." has left")
		con.members[id]=nil
	end,
	[19] = function()
		chatwindow:addline(con.members[conGetByte():byte()].name .. ": " .. conGetNull())
	end,
	--Mouse Position
	[32] = function()
		local id = conGetByte():byte()
		local b1,b2,b3=conGetByte():byte(),conGetByte():byte(),conGetByte():byte()
		con.members[id].mousex,con.members[id].mousey=((b1*16)+math.floor(b2/16)),((b2%16)*256)+b3
		--MANAGER_PRINT("x "..tostring(con.members[id].mousex).." y "..tostring(con.members[id].mousey))
		playerMouseMove(id)
	end,
	--Mouse Click
	[33] = function()
		local id = conGetByte():byte()
		local d=conGetByte():byte()
		local btn,ev=math.floor(d/16),d%16
		playerMouseClick(id,btn,ev)
		if ev==0 then return end
		if btn==1 then
			con.members[id].lbtn=ev
		elseif btn==2 then
			con.members[id].abtn=ev
		elseif btn==4 then
			con.members[id].rbtn=ev
		end
	end,
	--Brush size
	[34] = function()
		local id = conGetByte():byte()
		local bsx,bsy=conGetByte():byte(),conGetByte():byte()
		con.members[id].brushx,con.members[id].brushy=bsx,bsy
	end,
	--Brush Shape change, no args
	[35] = function()
		local id = conGetByte():byte()
		con.members[id].brush=(con.members[id].brush+1)%3
	end,
	--Modifier (mod and state)
	[36] = function()
		local id = conGetByte():byte()
		local d=conGetByte():byte()
		local mod,state=math.floor(d/16),d%16~=0
		if mod==0 then
			con.members[id].ctrl=state
		elseif mod==1 then
			con.members[id].shift=state
		elseif mod==2 then
			con.members[id].alt=state
		end
	end,
	--selected elements (2 bits button, 14-element)
	[37] = function()
		local id = conGetByte():byte()
		local b1,b2=conGetByte():byte(),conGetByte():byte()
		local btn,el=math.floor(b1/64),(b1%64)*256+b2
		if btn==0 then
			con.members[id].selectedl=el
		elseif btn==1 then
			con.members[id].selecteda=el
		elseif btn==2 then
			con.members[id].selectedr=el
		end
	end,
	--cmode defaults (1 byte mode)
	[48] = function()
		local id = conGetByte():byte()
		local mode = conGetByte():byte()
		if mode==10 then mode=-1 end --alt vel is -1, fuck you jacob
		tpt.display_mode(mode)
		--Display user set mode?
	end,
	--pause set (1 byte state)
	[49] = function()
		local id = conGetByte():byte()
		local pstate = conGetByte():byte()
		myPauseState = psate==1
		tpt.set_pause(pstate)
		--Display user set pause?
	end,
	--step frame, no args
	[50] = function()
		local id = conGetByte():byte()
		tpt.set_pause(0)
		myPauseState = false
		pauseNextFrame=true
	end,
	
	--deco mode, (1 byte state)
	[51] = function()
		local id = conGetByte():byte()
		local dstate = conGetByte():byte()
		myDeco = dstate==1
		tpt.decorations_enable(dstate)
	end,
	--HUD mode, (1 byte state)
	[52] = function()
		local id = conGetByte():byte()
		local hstate = conGetByte():byte()
		myHud = hstate==1
		tpt.hud(hstate)
	end,
	--amb heat mode, (1 byte state)
	[53] = function()
		local id = conGetByte():byte()
		local astate = conGetByte():byte()
		myAmb = astate==1
		tpt.ambient_heat(astate)
	end,
	--newt_grav mode, (1 byte state)
	[54] = function()
		local id = conGetByte():byte()
		local gstate = conGetByte():byte()
		myNewt = gstate==1
		tpt.newtonian_gravity(gstate)
	end,
	
	--[[
	--debug mode (1 byte state?) can't implement
	[55] = function()
		local id = conGetByte():byte()
		--local dstate = conGetByte():byte()
		tpt.setdebug()
	end,
	--]]
	--legacy heat mode, (1 byte state)
	[56] = function()
		local id = conGetByte():byte()
		local hstate = conGetByte():byte()
		myHeat = hstate==1
		tpt.heat(hstate)
	end,
	--water equal, can ONLY toggle, could lose sync (no args)
	[57] = function()
		local id = conGetByte():byte()
		tpt.watertest()
	end,
	--[[
	--grav mode, (1 byte state) can't implement yet
	[58] = function()
		local id = conGetByte():byte()
		local state = conGetByte():byte()
		tpt.something_gravmode(state)
	end,
	--air mode, (1 byte state) can't implement yet
	[59] = function()
		local id = conGetByte():byte()
		local state = conGetByte():byte()
		tpt.something_airmode(state)
	end,
	--]]
	
	--Should these three be combined into one number with an arg determining what runs?
	--clear sparks (no args)
	[60] = function()
		local id = conGetByte():byte()
		tpt.reset_spark()
	end,
	--clear pressure/vel (no args)
	[61] = function()
		local id = conGetByte():byte()
		tpt.reset_velocity()
		tpt.set_pressure()
	end,
	--invert pressure (no args)
	[62] = function()
		local id = conGetByte():byte()
		for x=0,152 do
			for y=0,95 do
				sim.pressure(x,y,-sim.pressure(x,y))
			end
		end
	end,
	--Clearsim button (no args)
	[63] = function()
		local id = conGetByte():byte()
		sim.clearSim() --not actually a tpt function (yet)
	end,

	--[[
	--Full graphics view mode (for manual changes in display menu) (3 bytes?)
	[64] = function()
		local id = conGetByte():byte()
		--do stuff with these
		--ren.displayModes()
		--ren.renderModes()
		--ren.colorMode
	end,
	--]]
	--Stamp file recieve of a screen
	[65] = function()
		local id = conGetByte():byte()
		local len = conGetByte():byte()*65536 + conGetByte():byte()*256 + conGetByte():byte()
		local data = ""
		for i=1,len do
			data = data..conGetByte()
		end
		local f = io.open("stamps/multitemp.stm","wb")
		f:write(data)
		f:close()
		sim.clearSim()
		sim.loadStamp("multitemp",0,0)
		os.remove("stamps/multitemp.stm")
	end,
}

local function connectThink()
	if not con.connected then return end
	if not con.socket then chatwindow:addline("Disconnected") con.connected=false return end
	--check byte for message
	while 1 do --real all per frame now...
		local s,r = con.socket:receive(1)
		if s then
			local cmd = string.byte(s)
			--MANAGER_PRINT("GOT "..tostring(cmd))
			if dataCmds[cmd] then dataCmds[cmd]() end
		else break end
	end

	--ping every minute
	if os.time()>con.pingTime then conSend(2) con.pingTime=os.time()+60 end
end

local function drawStuff()
	if con.members then
		for i,user in pairs(con.members) do
			local x,y = user.mousex,user.mousey
			local brx,bry=user.brushx,user.brushy
			local brush,drawBrush=user.brush,true
			tpt.drawtext(x,y,("%s %dx%d"):format(user.name,brx,bry),0,255,0,192)
			if user.drawtype then
				if user.drawtype==1 then
					tpt.drawline(user.pmx,user.pmy,x,y,0,255,0,128)
				elseif user.drawtype==2 then
					local tpmx,tpmy = user.pmx,user.pmy
					if tpmx>x then tpmx,x=x,tpmx end
					if tpmy>y then tpmy,y=y,tpmy end
					tpt.drawrect(tpmx,tpmy,x-tpmx,y-tpmy,0,255,0,128)
					drawBrush=false
				elseif user.drawtype==3 then
					for cross=1,5 do
						tpt.drawpixel(x+cross,y,0,255,0,128)
						tpt.drawpixel(x-cross,y,0,255,0,128)
						tpt.drawpixel(x,y+cross,0,255,0,128)
						tpt.drawpixel(x,y-cross,0,255,0,128)
					end
					drawBrush=false
				end
			end
			if drawBrush then
				if brush==0 then
					if gfx.drawCircle then
						if (brx+bry)==0 then tpt.drawpixel(x,y,0,255,0,128)
						else
							gfx.drawCircle(x-brx,y-bry,brx,bry,0,255,0,128)
						end
					else
						for rx=0,brx do
						for ry=-bry,bry do
							if inbrushborder(rx,ry,brx,bry,brush) then
								pcall(tpt.drawpixel,x+rx,y+ry,0,255,0,128)
								pcall(tpt.drawpixel,x-rx,y+ry,0,255,0,128)
							end
						end
						end
					end
				elseif brush==1 then
					gfx.drawRect(x-brx,y-bry,brx*2+1,bry*2+1,0,255,0,128)
				elseif brush==2 then
					gfx.drawLine(x-brx,y+bry,x,y-bry,0,255,0,128)
					gfx.drawLine(x-brx,y+bry,x+brx,y+bry,0,255,0,128)
					gfx.drawLine(x,y-bry,x+brx,y+bry,0,255,0,128)
				end
			end
		end
	end
end
--keep our mouse locally for checking
local mymousex,mymousey
local mybrx,mybry
local mybtype = 0
local mysell,mysela,myselr
local function sendStuff()
    if not con.connected then return end
    --mouse position every frame, not exactly needed, might be better/more accurate from clicks
    local nmx,nmy = tpt.mousex,tpt.mousey
    if mymousex~= nmx or mymousey~= nmy then
        mymousex,mymousey = nmx,nmy
		local b1,b2,b3 = math.floor(mymousex/16),((mymousex%16)*16)+math.floor(mymousey/256),(mymousey%256)
		conSend(32,string.char(b1,b2,b3))
    end
	local nbx,nby = tpt.brushx,tpt.brushy
	if mybrx~=nbx or mybry~=nby then
		mybrx,mybry = nbx,nby
		conSend(34,string.char(mybrx,mybry))
	end
    --check selected elements
    local nsell,nsela,nselr = elements[tpt.selectedl] or eleNameTable[tpt.selectedl],elements[tpt.selecteda] or eleNameTable[tpt.selecteda],elements[tpt.selectedr] or eleNameTable[tpt.selectedr]
    if mysell~=nsell then
    	mysell=nsell
    	conSend(37,string.char(math.floor(mysell/256))..string.char(mysell%256))
    elseif mysela~=nsela then
    	mysela=nsela
    	conSend(37,string.char(math.floor(64 + mysela/256))..string.char(mysela%256))
    elseif myselr~=nselr then
    	myselr=nselr
    	conSend(37,string.char(math.floor(128 + myselr/256))..string.char(myselr%256))
    end
end
local function updatePlayers()

end

local function step()
	chatwindow:draw()
	drawStuff()
	sendStuff()
	if pauseNextFrame then pauseNextFrame=false myPauseState=true tpt.set_pause(1) end
	connectThink()
	updatePlayers()
end

--keep our button state to prevent excess sending (mostly 3's)
local myButton, myEvent = 0,0
local myShift,myAlt,myCtrl = false,false,false
local myDownInside = nil

--we CAN get these states as of current github, yay
local myPauseState,myNewt,myAmb,myDeco,myHeat=tpt.set_pause()==1,tpt.newtonian_gravity()==1,tpt.ambient_heat()==1,tpt.decorations_enable()==1,tpt.heat()==1

--some button locations that emulate tpt, return false will disable button
local tpt_buttons = {
	["clear"] = {x1=470, y1=408, x2=486, y2=422, f=function() conSend(63) end},
	["pause"] = {x1=613, y1=408, x2=627, y2=422, f=function() myPauseState=not myPauseState conSend(49,myPauseState and "\1" or "\0") end},
	["deco"] = {x1=613, y1=33, x2=627, y2=47, f=function() myDeco=not myDeco conSend(51,myDeco and "\1" or "\0") end},
	["newt"] = {x1=613, y1=49, x2=627, y2=63, f=function() myNewt=not myNewt conSend(54,myNewt and "\1" or "\0") end},
	["ambh"] = {x1=613, y1=65, x2=627, y2=79, f=function() myAmb=not myAmb conSend(53,myAmb and "\1" or "\0") end},
	["disp"] = {x1=597, y1=408, x2=611, y2=422, f=function() --[[activate a run once display mode check on next step]] end},
}
if jacobsmod then
	tpt_buttons["clear"] = {x1=486, y1=404, x2=502, y2=423, f=function() conSend(63) end}
	tpt_buttons["pause"] = {x1=613, y1=404, x2=627, y2=423, f=function() myPauseState=not myPauseState conSend(49,myPauseState and "\1" or "\0") end}
	tpt_buttons["deco"] = {x1=613, y1=49, x2=627, y2=63, f=function() myDeco=not myDeco conSend(51,myDeco and "\1" or "\0") end}
	tpt_buttons["newt"] = {x1=613, y1=65, x2=627, y2=79, f=function() myNewt=not myNewt conSend(54,myNewt and "\1" or "\0") end}
	tpt_buttons["ambh"] = {x1=613, y1=81, x2=627, y2=95, f=function() myAmb=not myAmb conSend(53,myAmb and "\1" or "\0") end}
	tpt_buttons["disp"] = {x1=597, y1=404, x2=611, y2=423, f=function() --[[activate a run once display mode check on next step]] end}
end

local function mouseclicky(mousex,mousey,button,event,wheel)
	if chatwindow:process(mousex,mousey,button,event,wheel) then return false end
	local obut,oevnt = myButton,myEvent
	myButton,myEvent = button,event
	if myButton~=obut or myEvent~=oevnt then --if different event
		--Send mouse here for exact drawing, this is way more accurate than step mouse
		local b1,b2,b3 = math.floor(mousex/16),((mousex%16)*16)+math.floor(mousey/256),(mousey%256)
		conSend(32,string.char(b1,b2,b3))
		mymousex,mymousey = mousex,mousey
	    conSend(33,string.char(myButton*16+myEvent))
	elseif myEvent==3 then
		local b1,b2,b3 = math.floor(mousex/16),((mousex%16)*16)+math.floor(mousey/256),(mousey%256)
		conSend(32,string.char(b1,b2,b3))
		mymousex,mymousey = mousex,mousey
	end
	--Click inside button first
	if button==1 then
		if event==1 then
			for k,v in pairs(tpt_buttons) do
				if mousex>=v.x1 and mousex<=v.x2 and mousey>=v.y1 and mousey<=v.y2 then
					--down inside!
					myDownInside = k
				end
			end
		--Up inside the button we started with
		elseif event==2 and myDownInside then
			local butt = tpt_buttons[myDownInside]
			if mousex>=butt.x1 and mousex<=butt.x2 and mousey>=butt.y1 and mousey<=butt.y2 then
				--up inside!
				myDownInside = nil
				return butt.f()~=false
			end
		--Mouse hold, we MUST stay inside button or don't trigger on up
		elseif event==3 and myDownInside then
			local butt = tpt_buttons[myDownInside]
			if mousex<butt.x1 or mousex>butt.x2 or mousey<butt.y1 or mousey>butt.y2 then
				--moved out!
				myDownInside = nil
			end
		end
	end
end

local keypressfuncs = {
	--TAB
	[9] = function() conSend(35) end,
	
	--space, pause toggle
	[32] = function() myPauseState= tpt.set_pause()==0 MANAGER_PRINT(myPauseState) conSend(49,myPauseState and "\1" or "\0") end,
		
	--View modes 0-9
	[48] = function() conSend(48,"\10") end,
	[49] = function() if myShift then conSend(48,"\9") tpt.display_mode(9)--[[force local display mode, screw debug check for now]] return false end conSend(48,"\0") end,
	[50] = function() conSend(48,"\1") end,
	[51] = function() conSend(48,"\2") end,
	[52] = function() conSend(48,"\3") end,
	[53] = function() conSend(48,"\4") end,
	[54] = function() conSend(48,"\5") end,
	[55] = function() conSend(48,"\6") end,
	[56] = function() conSend(48,"\7") end,
	[57] = function() conSend(48,"\8") end,
	
	--= key, pressure/spark reset
	[61] = function() if myCtrl then conSend(60) else conSend(61) end end,
	
	--b , deco, pauses sim
	[98] = function() if myCtrl then myDeco=not myDeco conSend(51,myDeco and "\1" or "\0") else myPauseState,myDeco=true,true conSend(49,"\1") conSend(51,"\1") end end,

	--d key, debug, api broken right now
	--[100] = function() conSend(55) end,
	
	--F , frame step
	[102] = function() conSend(50) end,

	--I , invert pressure
	[105] = function() conSend(62) end,
	
	--U, ambient heat toggle
	[117] = function() myAmb=not myAmb conSend(53,myAmb and "\1" or "\0") end,

	--R,W,Y disable (record, grav mode, air mode)
	[114] = function() return false end,
	[119] = function() return false end,
	[121] = function() return false end,

	--SHIFT,ALT,CTRL
	[304] = function() myShift=true conSend(36,string.char(17)) end,
	[306] = function() myAlt=true conSend(36,string.char(1)) end,
	[308] = function() myCtrl=true conSend(36,string.char(33)) end,
}
local keyunpressfuncs = {
	--SHIFT,ALT,CTRL
	[304] = function() myShift=false conSend(36,string.char(16)) end,
	[306] = function() myAlt=false conSend(36,string.char(0)) end,
	[308] = function() myCtrl=false conSend(36,string.char(32)) end,
}
local function keyclicky(key,nkey,modifier,event)
	local check = chatwindow:textprocess(key,nkey,modifier,event)
	if check~=false then return true end
	--MANAGER_PRINT(nkey)
	local ret
	if event==1 then
		if keypressfuncs[nkey] then
			ret = keypressfuncs[nkey]()
		end
	elseif event==2 then
		if keyunpressfuncs[nkey] then
			ret = keyunpressfuncs[nkey]()
		end
	end
	if ret~= nil then return ret end
end

tpt.register_keypress(keyclicky)
tpt.register_mouseclick(mouseclicky)
tpt.register_step(step)
