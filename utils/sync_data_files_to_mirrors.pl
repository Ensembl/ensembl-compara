#!/usr/local/bin/perl

#TODO: 
#      before copying files check partitions are present on the mirrors
#      option to only rsync in case there are file updates (1 or 2 files change, fdt is not required, just rsync based on species to all servers -  dry run option as well)
#      moving server name and destination dir. to a configuration file
#      There was an error once where the previous file transfer didnt finish and got connection refused with an error coming back but then any further transfer to that specific server was hanging. The solution to this will be to use the time start for the fdt command and use while loop to continuously check the output and if it is hanging on one specific file transfer. If it is go to the destination server and kill the fdt and restart it again. Might have been one off.

use strict;

use File::Basename qw(dirname);
use File::Find;
use File::Spec;
use File::Path     qw(mkpath);
use FindBin        qw($Bin);
use Getopt::Long;
use IO::Select;
use POSIX qw(strftime);

BEGIN {
  local $SIG{'__WARN__'} = sub { my $str = "@_"; print STDERR @_ unless $str =~ /Retrieving conf/; };
  
  my $serverroot = dirname($Bin);
  
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
  
  require EnsEMBL::Web::Hub;
  require Bio::EnsEMBL::DBSQL::DataFileAdaptor;
}

my $hub        = new EnsEMBL::Web::Hub;
my $sd         = $hub->species_defs;
my $target_dir = '/exports/datafiles';
my $delete     = 0;
my $dryrun     = 0;
my $level      = 0;

#my %ips         = (
#    useast  => 'ec2-23-22-173-8.compute-1.amazonaws.com',
#    asia    => 'ec2-54-251-95-197.ap-southeast-1.compute.amazonaws.com'
#);
my %ips        = (
  useast => 'ec2-23-20-211-155.compute-1.amazonaws.com',
  uswest => 'ec2-54-241-205-36.us-west-1.compute.amazonaws.com',
  asia   => 'ec2-54-251-69-136.ap-southeast-1.compute.amazonaws.com'
);

my ($servers, $species_set, %targets, %hash);

GetOptions(
  'servers=s' => \$servers,
  'species=s' => \$species_set,
  'delete'    => \$delete,  # USE THIS ONLY AFTER THE RELEASE IS LIVE (to clean up files that are no longer in use)
  'dryrun|n'  => \$dryrun,
  'l'         => \$level,   # internal use only
);

#my $rsync   = sprintf 'rsync -havu%s%s --no-group --no-perms', $dryrun ? 'n' : 'W', $delete ? ' --delete' : '';
my @servers = $servers ? grep exists $ips{$_}, split ',', $servers : qw(useast uswest asia);
my %species = map { $_ => 1 } $species_set ? map $sd->valid_species($sd->species_full_name(lc) || ucfirst), split ',', $species_set : @$SiteDefs::ENSEMBL_DATASETS;
my $clean   = !$level++ && $delete && scalar keys %species == 1;
die sprintf "Valid servers are:\n\t%s\n", join "\n\t", sort keys %ips                    unless @servers;
die sprintf "Valid species are:\n\t%s\n", join "\n\t", sort @$SiteDefs::ENSEMBL_DATASETS unless keys %species;

set_targets(); #create hash of files that needs to be copied across

#creating file handle for the output file for each mirrors
open(FH_USEAST, "> fdt_output_useast.txt") || die "Can't create file:$!\n" if(!$dryrun);
open(FH_USWEST, "> fdt_output_uswest.txt") || die "Can't create file:$!\n" if(!$dryrun);
open(FH_ASIA,   "> fdt_output_asia.txt")   || die "Can't create file:$!\n" if(!$dryrun);

if (scalar @servers >= 1) {
   
   # preparing keys for ssh
   my @keys=qw(e59-asia.pem ensweb-key uswest-web);
   my $keyline = join("; ",'eval `ssh-agent -s`',(map { "ssh-add ~/.ssh/$_" } @keys),'');
   my $kp = join(" ",map { "-i ~/.ssh/$_" } @keys);

#use Data::Dumper;warn Dumper(%hash);

  my $size_check;
  my $partition_number = 1;
  my $print_counter = 0; #using this counter just to print the server details only once

# call for algorithm to sort species to find on the partitions
  my @sorted_species = SpeciesSizeSorter(%hash);
#use Data::Dumper;warn Dumper @sorted_species;

  #Sorting species based on the total files size, bigger at the top and smaller at the bottom. 
  foreach my $species_name(@sorted_species) {
    my %commands;
    $print_counter++;
    $size_check += $hash{$species_name};

    #if size_check(disk space) exceed 990GB then move to another partition
    if($size_check >= 1063000000000) {
      $size_check = 0; #reset counter
      $partition_number++; #increment partition_number to reflect the new partition where files have to go to.      
    }
    
    #if we have more than 1 partition, we need to create symlink in /exports/datafiles for the species in the other partitions
    if($partition_number > 1) {
      my $symlink_command = "ln -s /nfs/ensnfs-live_$partition_number/".lc($species_name)." ".lc($species_name);
      $commands{"symlink_command"} = $symlink_command;
    }


    #accessing each species files and copying the files to the partition using fdt
    foreach (sort keys %{$targets{$species_name}}) {
      my $file_list = join ' ', map { /\/result_feature\// ? "$_/*" : $_ } @{$targets{$species_name}{$_}};
      $_ =~ s/datafiles/datafiles_$partition_number/gi if($partition_number > 1);

      foreach my $remote_server (@servers) {
        warn "\n$remote_server ($ips{$remote_server}): copying the following files:\n $file_list \n TO $_\n\n" if($dryrun && $species_set && $species{$species_name});

        if(!$dryrun) {
          #do the fdt here
           my $fdt_command = "/software/bin/java -jar ~/fdt.jar -N -r -P 150 -c $ips{$remote_server} -d $_ $file_list";
           $commands{"fdt_$remote_server"} = $fdt_command;

           my $rsync_command = "rsync -aWv $file_list $ips{$remote_server}:$_ 2>&1";
           $commands{"rsync_$remote_server"} = $rsync_command;

           if($commands{"symlink_command"}) {
             print "\n$remote_server: Creating symlink [$commands{symlink_command}]";
             my $ssh_command = "ssh -o StrictHostKeyChecking=no $kp $ips{$remote_server} 'cd /exports/datafiles; $commands{symlink_command}'";
             my $ssh_out = `$ssh_command`;             
           }
          
           my $now_string = strftime "%a %b %e %H:%M:%S %Y", localtime;
           print "\n$remote_server($now_string): Starting file transfer for $species_name \n" if(!$dryrun);

           print(FH_USEAST "$fdt_command \n") if(!$dryrun && $remote_server eq 'useast');
           print(FH_USWEST "$fdt_command \n") if(!$dryrun && $remote_server eq 'uswest');
           print(FH_ASIA "$fdt_command \n") if(!$dryrun && $remote_server eq 'asia');
        }
      
      } #end of for loop for generating command for sending files to each server

#use Data::Dumper;warn Dumper(%commands);
      # Transferring the files to all 3 servers at the same tiem 
      my $read_set = IO::Select->new;
      my %fhs;
      foreach my $k (keys %commands) {
        if($k =~ /fdt_/) {     #only run fdt command
          open(my $fd,"$commands{$k} 2>&1 |") or die;
          $fhs{fileno($fd)} = $k;
          $fhs{fileno($fd)} =~ s/fdt_//;
          $read_set->add($fd);
        }
      }

      #reading output line from running parallel command above
      while($read_set->count()) {
        my ($got_set) = IO::Select->select($read_set,undef,undef,0);
        foreach my $got (@$got_set) {
          # Some data available on file descriptor $got
          my $line = <$got>;
          my $mirror_server = $fhs{fileno($got)}; #which server is the output from

          unless($line) {
            # This gets called when a command finishes 
            $read_set->remove($got);
            next;
          }
          # This is a line from a command
          print(FH_USEAST $line) if ($mirror_server eq 'useast');
          print(FH_USWEST $line) if ($mirror_server eq 'uswest');
          print(FH_ASIA $line)   if ($mirror_server eq 'asia');

          if($line =~ /Connection refused/) {
            print "ERROR!!! FDT is not running on the destination server.... Stopping script, restart fdt on the server and run script again!!!\n\n";
            exit;
          }
          print "ERROR IN TRANSFERRING FILES FOR $species_name!!!!\n".$commands{"fdt_$fhs{fileno($got)}"}."\n\n" if($line =~ /Exit Status: Not OK|Error/);
          if($line =~ /Exit Status: OK/) {
            my $now_string = strftime "%a %b %e %H:%M:%S %Y", localtime;
            print "\n$mirror_server($now_string): Successful transfer of files for $species_name \n";
            print "$mirror_server: Running dry rsync to update timestamp \n";
            print(FH_USEAST "$commands{\"rsync_$mirror_server\"} \n\n\n") if(!$dryrun && $mirror_server eq 'useast');
            print(FH_USWEST "$commands{\"rsync_$mirror_server\"} \n\n\n") if(!$dryrun && $mirror_server eq 'uswest');
            print(FH_ASIA "$commands{\"rsync_$mirror_server\"} \n\n\n") if(!$dryrun && $mirror_server eq 'asia');
            
            my $rsync_output = `$commands{"rsync_$mirror_server"}`;

          }
          
        }
      } #end of while loop for reading output line

      
    } # end of for loop for accessing each species

  } #end of for loop for species_name, going through each species already sorted by the algorithm

# close all output file first
if(!$dryrun) {
  close (FH_USEAST);
  close (FH_USWEST);
  close (FH_ASIA); 
}


} # end of if scalar @servers

sub set_targets {
  Bio::EnsEMBL::DBSQL::DataFileAdaptor->global_base_path($SiteDefs::DATAFILE_BASE_PATH);

  my %target_species;
  my $totalsize;

  foreach my $sp (keys %species) {
    my ($filesize,$regulation_filesize, $rna_filesize);
    foreach my $db (map { (split '_', lc)[1] } @{$sd->get_config($sp, 'core_like_databases') || []}) {
      my $adaptor = $hub->get_adaptor('get_DataFileAdaptor', $db, $sp);
      
      next unless $adaptor;
      foreach (@{$adaptor->fetch_all}) {
        next if $_->absolute;
       
        my $filepath = $_->path;
        $rna_filesize += `du -b $filepath |awk '{print \$1}'`;

        my ($files, $dir) = files($_->path);

        $dir =~ s/$SiteDefs::DATAFILE_BASE_PATH/$target_dir/;
        
        push @{$targets{$sp}{$dir}}, @$files;
        
        $target_species{$sp} = 1;
      }
    }
    foreach my $db (map { (split '_', lc)[1] } @{$sd->get_config($sp, 'funcgen_like_databases') || []}) {
      my $adaptor = $hub->get_adaptor('get_ResultSetAdaptor', 'funcgen', $sp);
      
      next unless $adaptor;
      
      $adaptor->dbfile_data_root(join '/', $SiteDefs::DATAFILE_BASE_PATH, lc $sp, $sd->get_config($sp, 'ASSEMBLY_NAME'));
      
      foreach (@{$adaptor->fetch_all}) {
        next unless $_->is_displayable;
        
        my $name  = $_->name;
        (my $file = $_->dbfile_data_dir) =~ s|//|/|;        
        (my $dir = $file) =~ s/$SiteDefs::DATAFILE_BASE_PATH/$target_dir/;

# hack to remove filename in destination path for dna_methylation file(which has to be different from others) to get the right fdt command 
# note: specifying the whole file path with the filename in the destination will cause  a directory to be created under that filename.
# can make it more generic later on remove filename if there is filename at the end or after the last /
        if($dir =~ /\/dna_methylation_feature\//) {
          my ($files, $dir_dna) = files($dir);
          $dir = $dir_dna if($dir =~ /\/dna_methylation_feature\//);
        }

        $regulation_filesize += `du -b $file |awk '{print \$1}'`;

        push @{$targets{$sp}{$dir}}, $file;
        
        $target_species{$sp} = 1;
      }
    }
    $filesize = $regulation_filesize + $rna_filesize;   #filesize is in bytes
    $totalsize += $filesize;     
    $hash{$sp} = $filesize if($filesize);
    
    print "$sp\n Regulation: ".HRSize($regulation_filesize,2)." + RNASeq: ".HRSize($rna_filesize,2)." == ".HRSize($filesize,2)." \n" if($filesize && $dryrun); #will display the disk space in dryrun mode
  }

  print "\nTotal Size == ".HRSize($totalsize,2)." (This is the total disk space you will need on the mirrors, create the volumes accordingly and make sure fdt is running!) \n" if($dryrun);
#  $hash{"total_size"} = HRSize($totalsize,0); #dont need it for me, be careful if we are adding back again as it will affect the count in SpeciesSizeSorter function.

  %species = %target_species;
}

sub files {
  my $source_file = shift;
  my ($volume, $dir, $name) = File::Spec->splitpath($source_file);
  my $regex = qr/^$name.*/;
  my @files;
  
  find(sub { push @files, $File::Find::name if $_ =~ $regex; }, $dir);
  
  return (\@files, $dir);
}

# Delete any directories like /nfs/ensnfs-live/SPECIES/ASSEMBLY/FILETYPE which are not in the targets list - they won't be needed for this release
sub delete_unused {
  my $server        = shift;
  my $ip            = $ips{$server};
  my $existing_dirs = `ssh $ip 'find $target_dir -mindepth 3 -maxdepth 3 -type d -not -path "*/biomart_results*"'`;
  
  foreach (grep { !exists $targets{"$_/"} } split /\n/, $existing_dirs) {
    (my $check = $_) =~ s|$target_dir/||;
    
    next unless $species{ucfirst [split '/', $check]->[0]};
    
    warn "\n$server ($ip): DELETING UNUSED DIRECTORY $_\n";
    system("ssh $ip 'rm -rf $_'") unless $dryrun;
  }
}

# Delete any empty directories in /nfs/ensnfs-live
sub delete_empty {
  my $server = shift;
  my $ip     = $ips{$server};
  
  for (3, 2, 1) {
    my $empty = `ssh $ip 'find $target_dir -mindepth $_ -maxdepth $_ -type d -empty -not -path "*/biomart_results*"'`;
    
    foreach (split /\n/, $empty) {
      warn "\n$server ($ip): DELETING EMPTY DIRECTORY $_\n";
      system("ssh $ip 'rm -rf $_'") unless $dryrun;
    }
  }
}

sub HRSize {
  # function to work out size in human readable way
  my $size  = $_[0]; # size in bytes
  my $dp    = $_[1]; # Number of decimal places to show sizes in
  my @units = ('bytes','kB','MB','GB','TB','PB','EB','ZB','YB');

  my $u = 0;
  $dp = ($dp > 0) ? 10**$dp : 1;
  while($size > 1024){
    $size /= 1024;
    $u++;
  }
  if($units[$u]){ return (int($size*$dp)/$dp)." ".$units[$u]; } else{ return int($size); }
}


# Algorithm to sort species file size in order to fit on the partitions.
# return array of species name (order will be based on which one fit on one partition)
sub SpeciesSizeSorter {
  my %hash = @_;
  
  my %temp_hash = %hash; #thats because we can't override global %hash
  my (@species_array, $size_counter, $previous_size, @temp_array);  
  
  #keep looping through the hash until there is no element (all species have been sorted)
  while (scalar keys %temp_hash > 0) {
    my $count =  scalar keys %temp_hash;  
    last if(scalar keys %temp_hash eq 0); #this is just a sanity check and preventing from going in infinite loop

    foreach my $species_name(sort{$temp_hash{$b} <=> $temp_hash{$a}} keys %temp_hash) {
      # calculating total size of species in temp_array up till now
      foreach (@temp_array) {
        if($_) {
          $previous_size += $hash{$_};
        } else {  
          $previous_size = 0;
        }
      }
      $size_counter = $previous_size + $temp_hash{$species_name};
      if($size_counter >= 1063000000000 && $count ne 1) {
        $count--; # decrease hash element count 
        next;
      } elsif ($size_counter >= 1063000000000 && $count eq 1) {
        push (@species_array,@temp_array); # we got one set set of species which fit one partition, empty temp_array and go through the loop again
        @temp_array = (); #empty temp_array            
        $previous_size = 0;
      }else {
        push (@temp_array,$species_name);
        $count--; #decrease hash element count
        delete $temp_hash{$species_name};  #remove species from $hash
        push(@species_array,@temp_array) if($count eq 0); #just in case we are at the last element of the hash, push everything
      }
    }
  } # end of while loop
 
  return @species_array;
}
1;
