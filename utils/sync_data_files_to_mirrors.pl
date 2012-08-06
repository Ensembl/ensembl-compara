#!/usr/local/bin/perl

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
my $target_dir = '/exports/funcgen';
my $delete     = 0;
my $dryrun     = 0;
my $level      = 0;
my %ips        = (
  useast => 'ec2-50-17-110-201.compute-1.amazonaws.com',
  uswest => 'ec2-184-169-197-19.us-west-1.compute.amazonaws.com',
  asia   => 'ec2-122-248-227-42.ap-southeast-1.compute.amazonaws.com'
);

my ($servers, $species, %targets);

GetOptions(
  'servers=s' => \$servers,
  'species=s' => \$species,
  'delete'    => \$delete,  # USE THIS ONLY AFTER THE RELEASE IS LIVE (to clean up files that are no longer in use)
  'dryrun|n'  => \$dryrun,
  'l'         => \$level,   # internal use only
);

my $rsync   = sprintf 'rsync -havu%s%s --no-group --no-perms', $dryrun ? 'n' : 'W', $delete ? ' --delete' : '';
my @servers = $servers ? grep exists $ips{$_}, split ',', $servers : qw(useast uswest asia);
my %species = map { $_ => 1 } $species ? map $sd->valid_species($sd->species_full_name(lc) || ucfirst), split ',', $species : @$SiteDefs::ENSEMBL_DATASETS;
my $clean   = !$level++ && $delete && scalar keys %species == 1;

die sprintf "Valid servers are:\n\t%s\n", join "\n\t", sort keys %ips                    unless @servers;
die sprintf "Valid species are:\n\t%s\n", join "\n\t", sort @$SiteDefs::ENSEMBL_DATASETS unless keys %species;

set_targets();

if (scalar @servers > 1) {
  my @process_list;
  
  # fork for servers;
  foreach (@servers) {
    my $child_pid = fork;
    
    die "Cannot fork, something's wrong" unless defined $child_pid;
    
    if (!$child_pid) {
      system(sprintf "$0 -l $level --servers $_%s%s%s", $delete ? ' --delete' : '', $dryrun ? ' --dryrun' : '', $species ? " --species $species" : '');
      exit;
    }
    
    push @process_list, $child_pid;
  }
  
  waitpid($_, 0) for @process_list;
} elsif (scalar keys %species > 1) {
  my @process_list;
  
  # fork for species
  foreach (sort keys %species) {
    my $child_pid = fork;
    
    die "Cannot fork, something's wrong" unless defined $child_pid;
    
    if (!$child_pid) {
      system(sprintf "$0 -l $level --servers $servers --species $_%s%s", $delete ? ' --delete' : '', $dryrun ? ' --dryrun' : '');
      exit;
    }
    
    push @process_list, $child_pid;
  }
  
  waitpid($_, 0) for @process_list;
  
  delete_empty($servers) if $delete;
} else {
  delete_unused($servers) if $delete;
  
  # Do the rsync
  foreach (sort keys %targets) {
    warn "\n$servers ($ips{$servers}): RSYNC FOR $_\n\n";
    system(sprintf "$rsync %s $ips{$servers}:$_\n\n", join ' ', @{$targets{$_}});
  }
  
  delete_empty($servers) if $clean;
}

sub set_targets {
  Bio::EnsEMBL::DBSQL::DataFileAdaptor->global_base_path($SiteDefs::DATAFILE_BASE_PATH);
  
  my %target_species;
  
  foreach my $sp (keys %species) {
    foreach my $db (map { (split '_', lc)[1] } @{$sd->get_config($sp, 'core_like_databases') || []}) {
      my $adaptor = $hub->get_adaptor('get_DataFileAdaptor', $db, $sp);
      
      next unless $adaptor;
      
      foreach (@{$adaptor->fetch_all}) {
        next if $_->absolute;
        
        my ($files, $dir) = files($_->path);
        
        $dir =~ s/$SiteDefs::DATAFILE_BASE_PATH/$target_dir/;
        
        push @{$targets{$dir}}, @$files;
        
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
        (my $dir  = $file) =~ s/$name//;
        
        $dir =~ s/$SiteDefs::DATAFILE_BASE_PATH/$target_dir/;
        
        push @{$targets{$dir}}, $file;
        
        $target_species{$sp} = 1;
      }
    }
  }
  
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

1;
