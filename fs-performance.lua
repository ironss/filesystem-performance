#! /usr/bin/lua

local timesources = require('timesources')
local tsrc = timesources.best


--[[
   - Create 1M of data: zero, random, text
   - Write the following files
   -   nfs: random only, all sizes, all chunk sizes
   -   ram: random only, all sizes
   -   ubifs: zero, random and text, all sizes, compressed and uncompressed
   -   /dev/null: random only, all sizes
   -  
   - Read the following files
   -   nfs: random only, all sizes
   -   ram: random only, all sizes
   -   ubifs: zero, random and text, all sizes, compressed and uncompressed
   -   /dev/zero: all sizes
   -   /dev/urandom: all sizes
--]]


write_dev_tests = 
{ -- name       device       content type
   { '/dev/null', '/dev/null', 'random' },
}

write_fs_tests = 
{ -- name             base path         content type
   { 'ubifs_zero'  , '/mnt/downloads', 'zero'   },
   { 'ubifs_random', '/mnt/downloads', 'random' },
   { 'ubifs_text'  , '/mnt/downloads', 'text'   },
   { 'ubifs_zero_nocomp'  , '/mnt/filesystem/red', 'zero'   },
   { 'ubifs_random_nocomp', '/mnt/filesystem/red', 'random' },
   { 'ubifs_text_nocomp'  , '/mnt/filesystem/red', 'text'   },
   { 'ramfs_text'  , '/var/volatile' , 'text'   },
   { 'nfs_text'    , '/home/root'    , 'text'   },
--   { 'ext4_text' , '/home/stephen' , 'random'   },
}


read_fs_tests =
{ -- name             base path         content type
   { 'ubifs_zero'  , '/mnt/downloads', 'zero'   },
   { 'ubifs_random', '/mnt/downloads', 'random' },
   { 'ubifs_text'  , '/mnt/downloads', 'text'   },
   { 'ubifs_zero_nocomp'  , '/mnt/filesystem/red', 'zero'   },
   { 'ubifs_random_nocomp', '/mnt/filesystem/red', 'random' },
   { 'ubifs_text_nocomp'  , '/mnt/filesystem/red', 'text'   },
   { 'ramfs_text'  , '/var/volatile' , 'text'   },
   { 'nfs_text'    , '/home/root'    , 'text'   },
--   { 'ext4_text' , '/home/stephen' , 'random'   },
}

read_dev_tests = 
{
   { '/dev/zero'  , '/dev/zero',     'zero' },
   { '/dev/urandom', '/dev/urandom', 'random'},
}


filetypes = 
{  -- filename      function that returns contents
   zero = { "zero"  , function(size)
                       local blocksize
                       if size < 1024 then blocksize = 1 else blocksize = 8192 end
                       local blocks = math.ceil(size / blocksize)
                       local cmd = 'dd if=/dev/zero bs='..tostring(blocksize) ..' count='.. tostring(blocks) .. ' 2>/dev/null'
--                       print(cmd)
                       local f = io.popen(cmd)
                       local content = f:read('*a')
                       if content == nil then print('**********************') end
                       return content
                    end 
   },
   random = { "random", function(size)
                       local blocksize
                       if size < 1024 then blocksize = 1 else blocksize = 8192 end
                       local blocks = math.ceil(size / blocksize)
                       local cmd = 'dd if=/dev/urandom bs='..tostring(blocksize) ..' count='.. tostring(blocks) .. ' 2>/dev/null'
--                       print(cmd)
                       local f = io.popen(cmd)
                       local content = f:read('*a')
                       return content
                    end 
   },
   text = { "text"  , function(size)
                       local t = {}
                       local count = 1
                       local length = 0
                       while length < size do
                          local tline = { os.date('!%Y%m%d_%H%M%S'), tostring(count), tostring(length) }
                          local line = table.concat(tline, ' ')
                          t[#t+1] = line
                          length = length + line:len() + 1
                          count = count + 1
                       end
                       
                       local content = table.concat(t, '\n')
                       return content
                    end
   },
}


local contents = {}
function getcontent(datatype, size)
   local dtype = filetypes[datatype]
   local generator = dtype[2]
   local key = datatype .. '_' .. tostring(size)
   if contents[key] == nil then
      print('Generating', datatype, size)
      contents[key] = generator(size)
   end
   return contents[key]
end




filesizes = 
{
--   1024, 2*1024, 4*1024, 8*1024, 16*1024, 32*1024, 64*1024, 128*1024, 256*1024, 512*1024, 1024*1024, 2*1024*1024, 4*1024*1024, 8*1024*1024, -- 16*1024*1024
   8*1024*1024, 4*1024*1024, 2*1024*1024, 1024*1024, 512*1024, 256*1024, 128*1024, 64*1024, 32*1024, 16*1024, 8*1024, 4*1024, 2*1024, 1024, 512, 256, 128, 64
--   1024*1024, 64*1024, 16*1024, 4*1024, 1*1024,
}


chunk_sizes = 
{
   4*1024, --8*1024, -- 16*1024 -- 64*1024, --256*1024
}


function os_path_join(t)
   local path = table.concat(t, '/')
   return path
end



local posix = require('posix')

function test_writefile(filename, data, size, sync)
   local data = data:sub(1, size)
   local data_size = data:len()
   local total_written = 0
   local write_size
   local written_size

   local sync_write = false
   local sync_end = true

   local file=io.open(filename, 'w')
   local fd=posix.fileno(file)

   local starttime = tsrc.gettime()

   while size > 0 do
      write_size = math.min(size, data_size)
      file:write(data)
      written_size = write_size

      if sync_write then
         posix.fsync(fd)
      end

      if written_size == nil then
         break
      end
      total_written = total_written + written_size
      size = size - written_size
   end

   if sync_end then
      posix.fsync(fd)
   end
      
   local endtime = tsrc.gettime()

   file:close()

   local duration = endtime - starttime
   return duration
end



function test_readfile(filename, content, amount_to_read, flush)
   local flush = flush or true
   local content = content:sub(1, amount_to_read)
   local chunk_size = content:len()
   local data = ''
   local amount_read
   local total_read = 0

   -- If file does not exist, create it
   local file = io.open(filename, 'r')
   if file == nil then
      print('Creating ', filename)
      local file = io.open(filename, 'w')
      local fd = posix.fileno(file)
      
      local total_written = 0
      local size = amount_to_read
      local write_size
      local written_size
   
      while size > 0 do
         write_size = math.min(size, chunk_size)
         file:write(content)
         written_size = write_size

         if written_size == nil then
            break
         end
         total_written = total_written + written_size
         size = size - written_size
      end

      posix.fsync(fd)
      file:close()
   else
      file:close()
   end

   -- Flush cache if requested
   if flush then
      os.execute('echo 3 > /proc/sys/vm/drop_caches')
   end

   local file=io.open(filename, 'r')
   local fd=posix.fileno(file)
   
--   print(filename, file)

   local starttime = tsrc.gettime()
   
   while total_read < amount_to_read do
      data = file:read(chunk_size)

      if data ~= nil then
         amount_read = data:len()
         total_read = total_read + amount_read
      else
         print('breaking')
         break
      end
   end
   
   local endtime = tsrc.gettime()
   
   local duration = endtime - starttime
   return duration
end

function run_tests(testname)
   local testname = testname or os.date("!%Y%m%d_%H%M%S")
   local write_tests = {}
   local read_tests = {}

   for _, chunk_size in ipairs(chunk_sizes) do

      for _, fstest in ipairs(write_dev_tests) do
         local name = fstest[1]
         local path = fstest[2]
         local content_type = fstest[3]
         
         for _, size in ipairs(filesizes) do
            local content = getcontent(content_type, chunk_size)
            local test = { fsname=name, test_type='write dev', filetype=content_type, size=size, content=content, path=path, chunk_size=chunk_size }

            write_tests[#write_tests+1] = test
         end
      end


      for _, fstest in ipairs(write_fs_tests) do
         local fsname = fstest[1]
         local fspath = fstest[2]
         local datatype = fstest[3]
         
         local testpath = os_path_join{fspath, 'fstest', testname}
         os.execute('rm -rf ' .. testpath)
         os.execute('mkdir -p ' .. testpath)

         for _, size in ipairs(filesizes) do
            local path = os_path_join{testpath, datatype..'_'..tostring(size)..'_'..tostring(chunk_size)}
            local content = getcontent(datatype, chunk_size)
            local test = { fsname=fsname, test_type='write file', filetype=datatype, size=size, content=content, path=path, chunk_size=chunk_size }

            write_tests[#write_tests+1] = test
         end
      end

      for _, test_spec in ipairs(read_dev_tests) do
         local name = test_spec[1]
         local path = test_spec[2]
         local content_type = test_spec[3]
         
         for _, size in ipairs(filesizes) do
            local content = getcontent(content_type, chunk_size)
            local test = { fsname=name, test_type='read device', filetype=datatype, size=size, content=content, path=path, chunk_size=chunk_size }
            read_tests[#read_tests+1] = test
         end
      end

      for _, test_spec in ipairs(read_fs_tests) do
         local fsname = test_spec[1]
         local fspath = test_spec[2]
         local datatype = test_spec[3]
         
         local testpath = os_path_join{fspath, 'fstest', testname}
         os.execute('rm -rf ' .. testpath)
         os.execute('mkdir -p ' .. testpath)

         for _, size in ipairs(filesizes) do
            local path = os_path_join{testpath, datatype..'_'..tostring(size)..'_'..tostring(chunk_size)}
            local content = getcontent(datatype, chunk_size)
            local test = { fsname=fsname, test_type='read file', filetype=datatype, size=size, content=content, path=path, chunk_size=chunk_size }

            read_tests[#read_tests+1] = test
         end
      end
   end


   -- Run tests
   local testresults = {}

   for _, test in ipairs(write_tests) do
--      print('Running', test.fsname, test.filetype, test.size)
      local duration = test_writefile(test.path, test.content, test.size)
      local testresult = { test=test, duration=duration }
      testresults[#testresults+1] = testresult

      print(test.test_type, test.fsname, test.filetype, test.size, test.chunk_size, testresult.duration, test.size / testresult.duration)
   end

   for _, test in ipairs(read_tests) do
--      print(test.path)
      local duration = test_readfile(test.path, test.content, test.size, true)
      local testresult = { test=test, duration=duration }
      testresults[#testresults+1] = testresult

      print(test.test_type, test.fsname, test.filetype, test.size, test.chunk_size, testresult.duration, test.size / testresult.duration)
   end


   -- Print test results
   for _, testresult in ipairs(testresults) do
      local test = testresult.test
--      print(test.test_type, test.fsname, test.filetype, test.size, test.chunk_size, testresult.duration, test.size / testresult.duration)
   end
end

run_tests()

