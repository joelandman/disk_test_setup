#!/usr/bin/env perl

use strict;
use constant { true => (1==1), false=> (1==0) };

my ($dev,@devices,$cmd,$rc,$fh,$line,$count,$rotational,@disks);
my ($mounted,$raided);

my $toppath    = shift || "/data";
my $userot     = shift ;
$userot = 1 if (!defined($userot));  # 1 (disk) or 0 (ssd/nvme)

my $mkfs_cmd = "mkfs.xfs -f -b size=4k -K -l size=128m -s size=4k /dev/%s";
chomp(@devices    = `ls /sys/block`);
$rc = `mkdir -p $toppath; umount -f -l $toppath/*`;
$count=0;
foreach $dev (@devices)
  {
   next if ($dev !~ /sd/i);
   
   # skip non-$userot media
   chomp($rotational = `cat /sys/block/$dev/queue/rotational`);
   next if ($rotational != $userot);
   push @disks,$dev;
  }

printf "disks=%s\n",join(",",@disks);

foreach $dev (@disks) {

   # skip and disks that are mounted ...
   chomp($mounted = `grep $dev /proc/mounts`); 
   if ($mounted ne "") {
      printf "skipping device %s: is mounted -> %s\n",$dev,$mounted;
      next ;
   }

   # ... or disks that are part of an MD-RAID 
   chomp($raided = `grep $dev /proc/mdstat`);
   if ($raided ne "") {
      printf "skipping device %s: is RAIDed -> %s\n",$dev,$raided;
      next ;
   }
   
   $cmd = (sprintf $mkfs_cmd,$dev);
   printf "cmd=%s\n",$cmd;
   open($fh,"$cmd |");
   while($line = <$fh>) {
	printf "%s: %s",$dev,$line;
   }
   close($fh);

   # make mountpoint ...
   $rc = `mkdir -p $toppath/$count`;

   # mount disk
   $rc = `mount -o inode64,noatime,nodiratime,logbufs=8,logbsize=256k /dev/$dev $toppath/$count`;
   printf "\n=====\nrc= %s\n-----\n",$rc;
   
   $count++;   
  }
