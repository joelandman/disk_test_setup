#!/usr/bin/env perl

use strict;
use IPC::Run qw( start pump finish timeout  );
use constant { true => (1==1), false=> (1==0) };

my ($dev,@devices,$cmd,$rc,$res,$fh,$line,$size,$B,@c,%h,$model);
my ($in,%out,%err,@ssds,$ssdi,$done,@k,$state);
my ($mounted,$raided,$rotational);

my $mode    = shift || "noop";
my $fio_cmd = "fio --blocksize=128k --ioengine=aio --direct=1 --iodepth=1 --rw=write --numjobs=1 --group_reporting --filename=/dev/%s --name=%s --fill_device=1 --loops=5 --runtime=10800"; # 3 hour run
chomp(@devices    = `ls /sys/block`);
$in = "";

foreach $dev (@devices)
  {
   next if ($dev !~ /sd.*/i);
   
   # skip non-rotational media
   chomp($rotational = `cat /sys/block/$dev/queue/rotational`);
   if ($rotational != 0) {
      printf "skipping device %s: is a disk, not an ssd\n",$dev;
      next ;
   }

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
  }

printf "SSDs: %s\n",join(",",@ssds);

# launch jobs
printf "Launching jobs:\n";
foreach $dev (@ssds) {
   $out{$dev} = "";
   $err{$dev} = "";
   $cmd = (sprintf $fio_cmd,$dev,$dev);
   @c=split(/\s+/,$cmd);
   printf "\t%s\t-> %s\n",$dev,$cmd;
   $h{$dev} = start \@c, \$in, \$out{$dev}, \$err{$dev};
   $state->{$dev} = 1;
  }

printf "Monitoring jobs:\n";
$done = false;

do {
	foreach $dev (@ssds) {
		$h{$dev}->pump_nb if ($h{$dev}->pumpable);
	}
	sleep 5;
	printf "tick %s\n",localtime();	

   } until $done;
