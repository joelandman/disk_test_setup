#!/usr/bin/env perl

use strict;
use IPC::Run qw( start pump finish timeout  );
use constant { true => (1==1), false=> (1==0) };

my ($dev,@devices,$cmd,$rc,$res,$fh,$line,$size,$B,@c,%h,$model);
my ($in,%out,%err,@ssds,$ssdi,$done,@k,$state,$fini,$count);
my ($mounted,$raided,$rotational);

my $userot     = shift ;
$userot = 1 if (!defined($userot));  # 1 (disk) or 0 (ssd/nvme)

my $ssd_cmd_0 = "sdparm -s WCE=1 /dev/%s";
my $ssd_cmd_1 = "wipefs -a /dev/%s";
my $ssd_cmd_2 = "dd if=/dev/zero oflag=direct bs=1M count=1000 of=/dev/%s";

chomp(@devices    = `ls /sys/block`);
$in = "";
$count=0;

# only wipe unmounted and non-raided disks
foreach $dev (@devices)
  {
   next if ($dev !~ /^sd.*/i);

   # skip non-$userot media
   chomp($rotational = `cat /sys/block/$dev/queue/rotational`);
   next if ($rotational != $userot);

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

   push @ssds,$dev;
   $count++;
}

printf "SSDs=%s\n",join(",",@ssds);
#exit;

# launch jobs
printf "enabling write cache:\n";
foreach $dev (@ssds) {
   $cmd = (sprintf $ssd_cmd_0,$dev,$dev);
   printf "\t%s\t-> %s\n",$dev,$cmd;
   $rc = `$cmd`;
}

printf "wiping the drive:\n";
foreach $dev (@ssds) {
   $cmd = (sprintf $ssd_cmd_1,$dev,$dev);
   printf "\t%s\t-> %s\n",$dev,$cmd;
   # wipe twice ... wipefs -a needs 2 passes sometimes, so make it default
   $rc = `$cmd`;
   $rc = `$cmd`;
}

printf "zeroing out first 1GB of drive:\n";
foreach $dev (@ssds) {
   $cmd = (sprintf $ssd_cmd_2,$dev,$dev);
   printf "\t%s\t-> %s\n",$dev,$cmd;
   $rc = `$cmd`;
}

