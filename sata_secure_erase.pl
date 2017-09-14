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
my $ssd_cmd_1 = "sg_format --wait --format /dev/%s";
my $ssd_cmd_2 = "hdparm --user-master u --security-set-pass password  /dev/%s";
my $ssd_cmd_3 = "hdparm --user-master u --security-erase-enhanced password /dev/%s";
chomp(@devices    = `ls /sys/block`);
$in = "";
$count=0;
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

printf "Launching secure erase jobs:\n";
foreach $dev (@ssds) {
  # unlock drive
  $cmd = (sprintf $ssd_cmd_2,$dev,$dev);
  printf "\t%s\t-> %s\n",$dev,$cmd;
  $rc = `$cmd`;
  
  # secure erase drive
  $cmd = (sprintf $ssd_cmd_3,$dev,$dev);
  printf "\t%s\t-> %s\n",$dev,$cmd;
  $rc = `$cmd`;

}

printf "Secure erase launched on drives: %s\nCheck with hdparm -I /dev/DRIVE for completion (look for 'not enabled'\n", join(",",@ssds);
