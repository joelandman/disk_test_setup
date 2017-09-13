#!/usr/bin/perl



# FIO testing generator
#
# usage:
# ./disk_fio.pl /topmount Njob_per_LUN TYPE SIZE_in_GB BLOCKSIZE
#
# where /topmount is the mount point where you made the mounts
#       Njob_per_LUN are the number of simultaneous jobs running against each mount point
#       TYPE is read or write (or randread / randwrite )
#       SIZE_in_GB is how much data to use across all jobs on each LUN
#       BLOCKSIZE is the size of blocks we use 128k by default


use strict;
my ($dev,@paths,$entry,$fh,$header);
use constant { true => (1==1), false=> (1==0) };

my $toppath    = shift || "/data";

# assuming LUNs are mounted under $toppath as $toppath/1 $toppath/2 ... $toppath/N
chomp(@paths    = `ls $toppath`);

# 1st arg is number of jobs (assuming 1) per LUN.  This sets concurrency
my $njobs = shift || 1;

# 2nd arg is read or write (default)
my $mode  = shift || "write";

# 3rd arg is size of each file in GB.  This will be divided by the number of
# jobs to keep the read/write size the same
my $size = shift || 10;

my $blocksize = shift || "128k";

$size/=$njobs;
my $size_string = sprintf "%im",int($size*1024);

my $fn = sprintf "%s_%s_%i_%i.fio",$mode,$njobs,$size,$blocksize;

open($fh,">".$fn);
$header = <<"EOF";
[global]
size=$size_string
iodepth=32
direct=1
blocksize=$blocksize
numjobs=$njobs
nrfiles=1
ioengine=vsync
group_reporting
loops=1
create_serialize=0
create_on_open=1
rw=$mode

EOF

printf $fh $header;
foreach $dev (@paths)
  {
   next if ($dev !~ /^\d+$/);
   $entry = sprintf "$toppath/%s/test",$dev;
   printf $fh "[%s]\ndirectory=$toppath/%s/test\n\n",$dev,$dev;
   mkdir $entry;
  }

close($fh);
