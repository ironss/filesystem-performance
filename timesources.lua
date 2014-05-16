-- Various timesources.

local timesources = {}
local timesources_sorted = {}

local function counter(start, increment)
   local count = start
   return function()
      count = count + increment
      return count
   end
end

local function timediff(t2, t2)
   return t2 - t1
 end

local function timesource_new(t)
   timesources[t.name] = t
   timesources_sorted[#timesources_sorted+1] = t
   table.sort(timesources_sorted, function(a, b)
      return a.resolution > b.resolution
   end)
end


timesource_new{
   name='test',
   gettime=counter(0, 1),
   diff=timediff,
   resolution=0,
}

timesource_new{
   name='lua',
   gettime=os.time,
   diff=os.difftime,
   units=1,
   resolution=1,
}


local status, socket = pcall(require, 'socket')
if status then
   timesource_new{
      name='socket',
      gettime=socket.gettime,
      diff=timediff,
      resolution=1000,
   }
end


local status, posix = pcall(require, 'posix')
if status then
   local function gettime_posix()
      local s, f = posix.clock_gettime("")
      local t = s + f / 1000000000
      return t
   end
   timesource_new{
      name='posix',
      gettime=gettime_posix,
      diff=timediff,
      resolution=1000000,
   }
end


local function timesource_by_name(name)
   return timesources[name]
end


local M = {
   new = timesource_new,
   best = timesources_sorted[1],
   get = timesource_by_name,
   all = timesources_sorted,
}

return M
