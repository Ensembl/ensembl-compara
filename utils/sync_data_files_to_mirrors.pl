#!/usr/local/bin/perl

#TODO: 
#      create symlink in datafiles for files on other volumes (datafiles_2, datafiles_3)
#      run fdt for 3 mirrors in parallel
#      adding time when each fdt command start
#      There has been an error once where the previous file transfer didnt finish and got connection refused with an error coming back but then any further transfer to that specific server was hanging. The solution to this will be to use open in perl to output the fdt command in there and use while loop to continuously check the output and the fdt command if it is hanging on one specific file transfer. If it is go to the destination server and kill the fdt and restart it again.
#      Dry run to include what mirrors are setup, 
#      before copying files check partitions are present on the mirrors and are empty
#      option to only rsync in case there is file updates (dry run option as well)
#      moving server name and destination dir. to a configuration file

use strict;

use File::Basename qw(dirname);
use File::Find;
use File::Spec;
use File::Path     qw(mkpath);
use FindBin        qw($Bin);
use Getopt::Long;

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
#    test  => 'ec2-23-22-173-8.compute-1.amazonaws.com'
#);
my %ips        = (
  useast => 'ec2-23-20-142-217.compute-1.amazonaws.com',
  uswest => 'ec2-184-169-223-224.us-west-1.compute.amazonaws.com',
  asia   => 'ec2-54-251-84-118.ap-southeast-1.compute.amazonaws.com'
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
my @servers = $servers ? grep exists $ips{$_}, split ',', $servers :qw(useast uswest asia); #qw(test); #qw(useast uswest asia);
my %species = map { $_ => 1 } $species_set ? map $sd->valid_species($sd->species_full_name(lc) || ucfirst), split ',', $species_set : @$SiteDefs::ENSEMBL_DATASETS;
my $clean   = !$level++ && $delete && scalar keys %species == 1;

die sprintf "Valid servers are:\n\t%s\n", join "\n\t", sort keys %ips                    unless @servers;
die sprintf "Valid species are:\n\t%s\n", join "\n\t", sort @$SiteDefs::ENSEMBL_DATASETS unless keys %species;

set_targets(); #create hash of files that needs to be copied across
open(STDERR, "> fdt_output.txt") || die "Can't create file:$!\n" if(!$dryrun);

if (scalar @servers >= 1) {
  my @process_list;
 
  delete_unused($servers) if $delete;
#use Data::Dumper;warn Dumper(%hash);  
  my $size_check;
  my $partition_number = 1;
  my $print_counter = 0; #using this counter just to print the server details only once

  #Sorting species based on the total files size, bigger at the top and smaller at the bottom. 
  foreach my $species_size(sort{$hash{$a} <=> $hash{$b}} keys %hash) {
    $print_counter++;
    $size_check += $hash{$species_size};

    #if size_check(disk space) exceed 976GB then move to another partition
    if($size_check >= 1048000000000) {
      $size_check = 0; #reset counter
      $partition_number++; #increment partition_number to reflect the new partition where files have to go to.      
    }

    #accessing each species files and copying the files to the partition using fdt
    foreach (sort keys %{$targets{$species_size}}) {
      my $file_list = join ' ', map { /\/result_feature\// ? "$_/*" : $_ } @{$targets{$species_size}{$_}};
      $_ =~ s/datafiles/datafiles_$partition_number/gi if($partition_number > 1);

      foreach my $remote_server (@servers) {
        warn "\n$remote_server ($ips{$remote_server}): copying the following files:\n $file_list \n TO $_\n\n" if($dryrun && $species_set && $species{$species_size});

        if(!$dryrun) {
          #do the fdt here
          my $fdt_command = "/software/bin/java -jar ~/fdt.jar -N -r -P 150 -c $ips{$remote_server} -d $_ $file_list 2>&1";
          print(STDERR "$fdt_command \n") if(!$dryrun);
#warn "\n$fdt_command \n\n";
          my $fdt_output = `$fdt_command`;# if($file_list =~ /H1ESC_5mC_Lister2009_PMID19829295/);
          print(STDERR "$fdt_output \n") if(!$dryrun);

          print "ERROR!!! FDT is not running on the destination server.... \n\n" if($fdt_output =~ /Connection refused/);
          print "ERROR IN TRANSFERRING FILES FOR $species_size!!!!\n$fdt_command \n\n" if($fdt_output =~ /Exit Status: Not OK/); 
 
          # if successful transfer do rsync to update timestamp 
          if($fdt_output =~ /Exit Status: OK/) {
            print "\n $ips{$remote_server}: Successful transfer of files for $species_size \n";
            print "Running dry rsync to update timestamp \n";
            my $rsync_command = "rsync -aWv $file_list $ips{$remote_server}:$_ 2>&1";
            print(STDERR "$rsync_command \n\n\n") if(!$dryrun);
            my $rsync_output = `$rsync_command`;            
          }
          
        }
      
      } #end of for loop for sending files to each server

    }

  } #end of for loop for sorting file based on size

close (STDERR) if(!$dryrun);
}

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
1;
