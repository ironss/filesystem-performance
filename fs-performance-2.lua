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
   { 'devnull', '/dev/null', 'random' },
}

write_fs_tests = 
{ -- name             base path         content type
--   { 'ubifs_zero'  , '/mnt/downloads', 'zero'   },
   { 'ubifs_random', '/mnt/downloads', 'random' },
--   { 'ubifs_text'  , '/mnt/downloads', 'text'   },
   { 'ramfs_text'  , '/var/volatile' , 'text'   },
   { 'nfs_text'    , '/home/root'    , 'text'   },
--   { 'ext4_text' , '/home/stephen' , 'random'   },
}


read_dev_tests = 
{
   { 'devzero', '/dev/random', },
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
--   8*1024*1024, 4*1024*1024, 2*1024*1024, 1024*1024, 512*1024, 256*1024, 128*1024, 64*1024, 32*1024, 16*1024, 8*1024, 4*1024, 2*1024, 1024, 512, 256, 128, 64
   1024*1024, 64*1024, 16*1024, 4*1024, 1*1024,
}


chunk_sizes = 
{
   8*1024, 16*1024 -- 64*1024, --256*1024
}

conditions = 
{
   { "UBI empty, uncompressed",       },
   { "UBI empty, compressed"  ,       },
   { "UBI nearly full, uncompressed", },
   { "UBI nearly full, compressed",   }
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
   local file=io.open(filename, 'w')
   local fd=posix.fileno(file)

   local sync_write = false
   local sync_end = true

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



function test_readfile(filename, size, flush)
   local flush = flush or true

   -- Flush cache if requested
   if flush then
      os.execute('echo 3 > /proc/sys/vm/drop_caches')
   end

   local starttime = tsrc.gettime()
   
   return 0
end

function run_tests(testname)
   local testname = testname or os.date("!%Y%m%d_%H%M%S")
   local write_tests = {}
   local read_tests = {}

   for _, chunk_size in ipairs(chunk_sizes) do

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
      

      for _, test_spec in ipairs(read_dev_tests) do
         local name = test_spec[1]
         local path = test_spec[2]
         
         for _, size in ipairs(filesizes) do
            local test = { fsname=name, test_type='read file', path=path, filetype='', size=size, chunk_size=chunk_size }
            read_tests[#read_tests+1] = test
         end
      end
   end


   local testresults = {}

   for i, test in ipairs(write_tests) do
--      print('Running', test.fsname, test.filetype, test.size)
      local duration = test_writefile(test.path, test.content, test.size)
      local testresult = { test=test, duration=duration }
      testresults[#testresults+1] = testresult
   end

   for i, test in ipairs(read_tests) do
      local duration = test_readfile(test.path, test.content, test.size)
      local testresult = { test=test, duration=duration }
      testresults[#testresults+1] = testresult
   end
   
   for i, testresult in ipairs(testresults) do
      local test = testresult.test
      print(test.test_type, test.fsname, test.filetype, test.size, test.chunk_size, testresult.duration, test.size / testresult.duration)
   end
end

run_tests()

