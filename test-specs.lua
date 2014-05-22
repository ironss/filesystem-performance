tests = 
{
   { '/dev/zero'                  , '/dev/zero'         , 'text'  , read_device, nil         , 1, 8*1024*1024 },
   { '/dev/urandom'               , '/dev/urandom'      , 'text'  , read_device, nil         , 1, 8*1024*1024 },
   { '/dev/null'                  , '/dev/null'         , 'text'  , nil        , write_device, 1, 8*1024*1024 },
   { 'UBIFS compressed (zero)'    , '/mnt/ubifs_compr'  , 'zero'  , read_file  , write_file  , 1, 8*1024*1024 },
   { 'UBIFS compressed (text)'    , '/mnt/ubifs_compr'  , 'text'  , read_file  , write_file  , 1, 8*1024*1024 },
   { 'UBIFS compressed (random)'  , '/mnt/ubifs_compr'  , 'random', read_file  , write_file  , 1, 8*1024*1024 },
   { 'UBIFS uncompressed (zero)'  , '/mnt/ubifs_uncompr', 'zero'  , read_file  , write_file  , 1, 8*1024*1024 },
   { 'UBIFS uncompressed (text)'  , '/mnt/ubifs_uncompr', 'text'  , read_file  , write_file  , 1, 8*1024*1024 },
   { 'UBIFS uncompressed (random)', '/mnt/ubifs_uncompr', 'random', read_file  , write_file  , 1, 8*1024*1024 },
   { 'RAMFS'                      , '/var/volatile'     , 'text'  , read_file  , write_file  , 1, 4*1024*1024 },
   { 'NFS'                        , '/home/root'        , 'text'  , read_file  , write_file  , 1, 8*1024*1024 },
   { 'ext4'                       , '/home/ironss'      , 'text'  , read_file  , write_file  , 1, 8*1024*1024 },
}

block_sizes = 
{
   1024, 4*1024, 16*1024, 64*1024
}

file_sizes = 
{
   64, 128, 256, 512, 1024, 2*1024, 4*1024, 8*1024, 16*1024, 32*1024, 64*1024, 128*1024, 256*1024, 512*1024, 1024*1024, 2*1024*1024, 4*1024*1024, 8*1024*1024
}

