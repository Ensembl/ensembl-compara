#!/usr/local/bin/perl

use strict;
use warnings;
use File::Find;
use FindBin qw($Bin);
use Cwd;
use File::Basename;
use Time::localtime;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use utils::Tool;

use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");

# Input -----------------------------------------------------------------------
my @SPECIES;
my @TYPES;
my $DUMPDIR;
my $VERBOSITY;
my $release;
my $help;
my $info;
my $warn;
my $size;
my $mysql_dir;
my $logfile;

&GetOptions(
            'species:s'     => \@SPECIES,
            'release:s'     => \$release,
            'type:s'        => \@TYPES,
	    'verbose:s'     => \$VERBOSITY,
            'dumpdir:s'     => \$DUMPDIR,
	    'mysql_dir:s'   => \$mysql_dir,
            'help'          => \$help,
            'info'          => \$info,
            'size'          => \$size,
	    'warn'          => \$warn,
            'logfile:s'     => \$logfile,
           ) || pod2usage(2);


pod2usage(-verbose => 2) if $info;
pod2usage(-verbose => 1) if $help;
error("Script needs an release version e.g. 29!") unless $release;

if ($logfile){
  open(STDERR, "> $logfile") || die "Can't create file:$!\n";
}

$DUMPDIR   ||= "/mysql/dumps/FTP";
$mysql_dir ||= "/mysql/current/var";
$VERBOSITY = defined($VERBOSITY) ? $VERBOSITY: 1;
our $WARN_ONLY = $warn;
&calculate_size($DUMPDIR) if $size;

# Sort out dumping types ------------------------------------------------------
my %ok_types = (fasta => 1, flatfiles => 1, mysql =>1 );
our %types;
if (@TYPES) {
  %types  = map { die "Invalid type: $_" unless $ok_types{$_};  $_ => 1 } @TYPES;
}
else {%types = %ok_types};
info(1, "Checking these dumps: ". join ", ", keys %types);


# Check the dumpdir directory has the correct number of directories ----------
my %dumped_check;          # All folders present in dumpdir
my $count_dirs = 0;
opendir(DUMP_DIR, $DUMPDIR) || die ("Can't open dir $DUMPDIR: $!\n");
while (defined(my $file = readdir(DUMP_DIR))) {
  next if $file =~ /^\.+$/;         #skip filenames starting with "."
  $dumped_check{$file} = "not checked";
  $count_dirs++;
}
close DUMP_DIR;


# Sort out species ------------------------------------------------------------
if (@SPECIES) {  @SPECIES = @{ utils::Tool::check_species(\@SPECIES) };  }
else {  @SPECIES = @{ utils::Tool::all_species()};  }
info(1, "Checking these species:\n".join "\n", @SPECIES);


# Check each species ---------------------------------------------------------
my $sitedefs_release =  $SiteDefs::ENSEMBL_VERSION;
if ($sitedefs_release ne $release) {
 die "[*DIE] Ensembl release version requested is $release but site defs is configured to use $sitedefs_release";
}


# Mysql stuff -------------------------------------------
my %kill_list = map {$_=>1} qw( ENSEMBL_BLAST ENSEMBL_HELP
				ENSEMBL_WEBSITE
                                ENSEMBL_COMPARA_MULTIPLE
                                ENSEMBL_BLAST_LOG
                                ENSEMBL_FASTA
                                ENSEMBL_GLOVAR );

# Compile a list of all mysql db from the database
our %mysql_db =  %{ utils::Tool::mysql_db($release) }; 
$mysql_db{"ensembl_web_user_db_$release"} = 1;
$mysql_db{"ensembl_website_$release"} = 1;


foreach my $species (@SPECIES) {
  info (1, "Species: $species");

  my $ok_dirs;
  my $mysql_conf;
  my $species_folder;
  my @search_dirs;          # list of folders to search according to config


  if ($species eq 'Multi' && $types{mysql} ) {
    $species_folder = "multi_species_$release";

    foreach my $x qw( ensembl_website ensembl_web_user_db ) {
      $ok_dirs->{"$DUMPDIR/$species_folder/data/mysql/$x"."_$release"} = [1];
      $mysql_conf++; 
    }
    $dumped_check{"mart_$release"} = 1;  # indicates this dir will be checked
    push (@search_dirs, "$DUMPDIR/mart_$release"); # search this
  }

  else {
    my $sp_release = $SPECIES_DEFS->get_config($species,"SPECIES_RELEASE_VERSION") || "";
    $sp_release =~ s/\.//g;
    $species_folder = join "_", (lc($species), $release, $sp_release);

    $ok_dirs = {
		 "$DUMPDIR/$species_folder/data/fasta/cdna"        => [1],
		 "$DUMPDIR/$species_folder/data/fasta/dna"         => [1],
		 "$DUMPDIR/$species_folder/data/fasta/pep"         => [1],
		 "$DUMPDIR/$species_folder/data/fasta/rna"         => [1],
		 "$DUMPDIR/$species_folder/data/flatfiles/genbank" => [1],
		 "$DUMPDIR/$species_folder/data/flatfiles/embl"    => [1],
		};
  }
  push @search_dirs,  "$DUMPDIR/$species_folder";  # all folders to search

  # Put directories for mysql databases in $ok_dirs
  # Check there is a core db configured for this species
  my $databases  = $SPECIES_DEFS->get_config($species, "databases");
  error("No core database configured for this species $species") unless $databases->{'ENSEMBL_DB'}->{'NAME'} or $species eq 'Multi';


  foreach my $db (keys %$databases) {
    next if $kill_list{$db};
    my $name = $databases->{$db}->{'NAME'};
    next unless $name;
    $mysql_conf++;

    if ( $name =~ /_mart_/ ) {
      $ok_dirs->{"$DUMPDIR/mart_$release/data/mysql/$name"} = [1];
    }
    else {
      $ok_dirs->{"$DUMPDIR/$species_folder/data/mysql/$name"} = [1];
    }
  }


  # Checking there is a directory for this species
  #info(1, "Checking directory for this species exists");
  if ( !$dumped_check{$species_folder} ) {
    error("No folder for this species. (Searching for $species_folder)");
    next;
  }
  $dumped_check{$species_folder} = 1;


  my $genbank_files = 0;
  my $embl_files    = 0;
  my $mysql_count   = 0;
  my $sp_mysql;


  # Recursively search each spp directory
  find sub {
    my $path_dir  = $File::Find::name;
    my $dir       = $_;
    ($ok_dirs, $sp_mysql) = check_dir($path_dir, $dir, $ok_dirs, $species) if (-d $dir);
    $mysql_count += $sp_mysql;

    # Store the number files in embl and genbank dirs
    if ($ok_dirs->{$path_dir}) {
      $genbank_files = scalar( @{$ok_dirs->{$path_dir}} ) if $dir eq 'genbank';
      $embl_files    = scalar( @{$ok_dirs->{$path_dir} } ) if $dir eq 'embl';
    }
  }, @search_dirs;

  # Check there are files for each of the directories listed in ok_dirs
  if (keys %types ==3 ) { # i.e. if you are checking all directories
    info (1, "Check all directories (pep, rna, cdna, dna, embl, genbank, mysql for files )");
    foreach my $dir (keys %$ok_dirs) {
      next if $dir =~ /rna$/;
      error("No files in $dir directory") if $ok_dirs->{$dir}->[0] eq '1' ;
    }
  }

  # Check the flatfiles have the same num of files in genback and embl
  if ($types{flatfiles} && $species ne 'Multi') {
    info(1, "Checking embl and genbank files: $embl_files files");
    error("$species EMBL dir has $embl_files files(s) and GENBANK has $genbank_files") unless $embl_files == $genbank_files;
      error("No genbank or EMBL files for $species") if $embl_files == 0 ;
  }

  # Check the num of dirs under mysql is the same as number configured
  if ($types{mysql}) {
    info(1, "Checking mysql files");
    error("There are $mysql_count directories in $DUMPDIR/$species_folder/data/mysql instead of $mysql_conf") unless $mysql_count == $mysql_conf;
  }
}

# Check all the mysql dbs in $mysql_db have been dumped
unless (@SPECIES) {
  foreach (sort keys %mysql_db) {
    print "These mysql db are not dumped $_\n" if $mysql_db{$_} ==1;
  }

  foreach (keys %dumped_check) {
    print "Directories in $DUMPDIR not checked: $_ \n" unless $dumped_check{$_} eq '1' ;
  }
}

# Check there are the right number of directories in $DUMPDIR
if ( !@SPECIES ) { # If the user is checking all species
  info("Need a directory for each species + multi + mart in $DUMPDIR.  
There are $count_dirs directories but there should be $#SPECIES + 2.") if $count_dirs != 2+ $#SPECIES;
}


exit;


#----------------------------------------------------------------------
sub check_dir {
  my ($path_dir, $dir, $ok_dirs, $species) =@_;
  my $flag_readme     = 0;
  my $flag_checksum   = 0;
  my $flag_compatible = 0;
  my @files;         # number of files in dir

  # Check the files in the directory
  my $sp_mysql_count = 0;
  opendir(DIR, $path_dir) or die ("can't open dir $path_dir: $!\n");

  while (defined(my $file = readdir(DIR))) {
    next if $file =~ /^\.+$/;  # ignore files that start w/ "."

    # Check file isn't zero size
    error("$path_dir/$file has zero size") if -z "$path_dir/$file";

    # Check the file isn't greater than 2G
    my $file_size = -s "$path_dir/$file";
    error("$path_dir/$file is greater than 2G: $file_size") if $file_size > 2000000000;

    if ($file eq 'README') {$flag_readme =1; next;}

    # Check files contain correct type of sequence 
    # Check files are gzipped and have correct names
    my $return;
    if ($dir eq 'pep'  or $dir eq 'cdna' or $dir eq 'rna' or $dir eq 'dna'){
      $return = check_fasta_dir ($species, $dir, $path_dir, $file);
    }

    # embl/genbank
    elsif ($dir eq 'embl' or $dir eq 'genbank') {
      if ($file !~ /$species\.\d+\.dat\.gz/){ # Check file ends in dat.gz
	error("Should $path_dir/$file be here?");
      }
      $return = 1;
    }

    # mysql db folder
    elsif ($dir eq 'mysql') {
      $sp_mysql_count ++;
    }

    elsif ($path_dir =~ m!.+/data/mysql/(\w+_\w+.+\d+.*)!) {

      # Change the values of the databases in $mysql_db if they're dumped
      my $db = $1;
      $mysql_db{$db}++ if $mysql_db{$db}; 
      error("This database isn't listed in mysql $db") unless $mysql_db{$db};

      #print "in mysql and path is $path_dir\n";
      if ($file eq 'CHECKSUMS.gz') {$flag_checksum = 1;}
      elsif ($file =~ /compatible\.sql\.gz$/) {
	$return = check_mysql_sql("$path_dir/$file", $species);
	$flag_compatible++;
      }

      # Check mysql files are all gzipped
      elsif ($file !~ /\.gz/) { error("Mysql $file is not gzipped");}
      else { $return = 1; }
    }

    else{
     error("Should '$file' be here in $path_dir? (It isn't a directory)") unless (-d "$path_dir/$file");
    }
    push (@files, $file) if $return;

  } # while $file in dir



  # Check directory isn't empty
  if ($dir ne '.' and $dir ne 'data' and $dir ne 'mysql' and $dir ne 'rna' and
      $dir ne 'fasta' and $dir ne 'flatfiles') {
    error("No files in directory $dir") unless @files;
  }

  # Check readme is there
  if ($dir eq 'pep' or $dir eq 'cdna' or $dir eq 'dna' or $dir eq 'rna' or
     $dir eq 'embl' or $dir eq 'genbank'){
    error("No $species readme file for $dir") unless $flag_readme;
  }

  # Check checksum is there if mysql dir
  if ($path_dir =~ m(.+/data/mysql/\w+_\w+_\d+_\d+)){
    error("No $species checksum file for $dir") unless $flag_checksum;
  }

  # Check sql files are there if mysql dir
  if ($path_dir =~ m(.+/data/mysql/\w+_\w+_\d+_\d+)){
    error("No sql files for $dir") unless $flag_compatible;
  }

  # Check no extra files in dir
  if ($dir eq 'cdna'){error("Extra files in directory $dir") if $#files >5;}
  elsif ($dir eq 'pep'){error("Extra files in directory $dir") if $#files>4;}
  elsif ($dir eq 'rna'){error("Extra files in directory $dir") if $#files>0;}


  # Check there is a dna file for each chr
  if ($dir eq 'dna') {  check_toplevel(\@files, $species) if $types{fasta};  }

  # Check there are no files in the dir unless the directory is in $ok_files
  if (@files) {
    if ( $ok_dirs->{$path_dir} ) {
      $ok_dirs->{$path_dir} = \@files;
     }
    else {
      error("I'm not configured to have files '@files' in this dir $path_dir?");
    }
  }
  return ($ok_dirs, $sp_mysql_count);
}

#-----------------------------------------------------------------------------
sub check_mysql_sql {
  my ($file, $species) = @_;

  info(1, "Checking mysql dir $file");
  my $twolines = `gzcat $file | head -10`;
  my @file_contents = (split /\n/, $twolines);

  my $flag_host = 0;
  my $flag_db   = 0;
  my $host = 0;
  my $db   = 0;

  foreach my $line  (@file_contents) {
    next unless $line =~ /Host|Database/;
    my @host_line = split /\s/, $line;

    foreach  (@host_line) {
      if ($flag_host) {
	$host = $_;
	$flag_host = 0;
	next;
      }
      if ($flag_db) { 
	$db = $_;
	$flag_db =0;
      }
      $flag_host = 1 if $_ =~ /Host:/;
      $flag_db   = 1 if $_ =~ /Database:/;
    }
  }

  error("Couldn't work out host from $file") unless $host;
  error("Couldn't work out db from $file")   unless $db;

  # Check using correct host for mysql dumps
  my $config_host= $SPECIES_DEFS->get_config($species,"ENSEMBL_HOST");
  $config_host   = $SiteDefs::ENSEMBL_USERDB_HOST if $file =~ /ensembl_web_user_db/;

  $host =~ s/\.internal\.sanger\.ac\.uk//;
  $config_host =~ s/\.internal\.sanger\.ac\.uk//;

  if (($config_host ne $host) and ($host."d" ne $config_host)) {
    error("Wrong host for mysql dumps in $file: $host rather than $config_host");
  }

  # Check dumping correct db version
  my $databases  = $SPECIES_DEFS->get_config($species,"databases");
  my $db_conf = 0;
  return 1 if $db eq 'ensembl_web_user_db';

  # Check that the db dumped matches up with the ini file and .sql.gz
  foreach (keys %$databases) {
    my $name =  $databases->{$_}->{'NAME'} || 0;
    $db_conf = $name if $name eq $db;
  }
  error("Wrong database used for dumping: $db") unless $db_conf;

  # Check that the sql and mysql40_compatible.sql are different sizes
  my $compatible_size = -s $file;
  (my $sql_file = $file) =~ s/.{1}mysql40_compatible//;
  error ("$file doesn't exist") unless -e $file;
  error ("$sql_file doesn't exist") unless -e $sql_file;
  my $sql_size = -s $sql_file;
  error ("Error with compatibility file ($compatible_size). It is the same size as the sql file ($sql_size)") if $compatible_size == $sql_size;
  return 1;
}
#------------------------------------------------------------------------------
sub check_fasta_dir {
  my ($species, $dir, $path_dir, $file) = @_;

  # Check no rogue files here: check correct name format & end in gz
  if ($file !~ /$species\..+\.\w{3}\.$dir.*fa\.gz/){
    if ($file =~ /$species\..+\.\w{3}\.$dir\..*fa/){
      error("This file should be gzipped $path_dir/$file");
    }
    else {
      error("File name doesn't match standard format.  Should $path_dir/$file be here?");
    }
  }

  if (0) {
    # Check file contents
    my $twolines =`gzcat $path_dir/$file | head -2`;
    my @file_contents = (split /\s/, $twolines);

    if ($dir eq 'pep') {
      $file_contents[5] =~/[VLIMFWPSYQDEKRH]/ or error("Error in $file header or sequence");
    }
    else {
      my $check = $file =~ /abinitio/ ? $file_contents[5] : $file_contents[4];
      $check = $file_contents[3] if $dir eq 'dna';
      $check =~/^[ACTGN]+$/ or error("Error in $file header or sequence");
    }
  } # end of DOESNT WORK

  # Check for every dna file there is an dna_rm file (and vice versa)
  # Check that the dna_rm file is smaller than dna
  if ($dir eq 'dna') {
    my $current = $file =~/\.dna_rm\./ ? "dna_rm" : "dna"; 
    my $dna_size;
    my $dna_rmsize;
    my $dna_file;
    my $dna_rmfile;
    if ($current eq 'dna') {
      $dna_file =  $file;
      ($dna_rmfile = $dna_file) =~ s/$current/dna_rm/;
      $dna_size   = (-s "$path_dir/$dna_file") ||
	error("No DNA file $path_dir/$dna_file");
      $dna_rmsize = (-s "$path_dir/$dna_rmfile") ||
	error("No repeat masked file $path_dir/$dna_rmfile");

    }
    elsif ($current eq 'dna_rm') {
      $dna_rmfile = $file;
      ($dna_file = $dna_rmfile) =~ s/$current/dna/;
      $dna_rmsize = (-s "$path_dir/$dna_rmfile") 
	|| error("No repeat masked file $path_dir/$dna_rmfile");
      $dna_size   = (-s "$path_dir/$dna_file") ||
	error("No DNA file $path_dir/$dna_file");
    }

    # Check repeat masked DNA file is smaller than non repeat masked
    unless ($dna_rmfile =~/dna_rm.chromosome.MT.fa.gz$/) {
      error("Repeat masked DNA file $dna_rmfile is $dna_rmsize and non repeat masked is $dna_file $dna_size") if $dna_rmsize >= $dna_size;
    }
  }

  return $file;
}

#------------------------------------------------------------------------------
sub check_toplevel {
  my ($files, $species) = @_;
  return (error("No files sent to check_toplevel")) unless @$files;

  #info("Checking DNA files");
  my %chr;
  map{ $chr{$_} = 1 } @{$SPECIES_DEFS->get_config($species,"ENSEMBL_CHROMOSOMES")};
  my %dna_files;
  map{ $dna_files{$_} =1 } @$files;

  # Work out assembly and month and check it doesn't
  my $assembly;
  my $month;
  if ($files->[0] =~/$species\.?\d?\.(.+)\.(\w{3})\.dna.*\.fa\.gz/){
    $assembly = $1;
    $month = $2;
  }
  else {
    error("$files->[0] has the wrong format");
  }

  if ($species eq 'Drosophila_melanogaster') {    map {$chr{$_} = 1;} 
						    qw( U 2h 3h 4h Xh Yh Uh )
					      }
  elsif ($species eq 'Anopheles_gambiae')    {  map { $chr{$_} =1; } qw( UNKN Y_unplaced) }
  elsif ($species eq 'Gallus_gallus' or $species eq 'Monodelphis_domestica' or 
	$species eq 'Canis_familiaris') { $chr{Un} =1;}
  elsif ($species eq 'Caenorhabditis_elegans') {
    map {$chr{$_} = 1;}  qw( MtDNA );
  }
  elsif ($species eq 'Homo_sapiens') {
    map {$chr{$_} = 1;}  qw( c6_COX c6_QBL c5_H2 c22_H2 );
  }
  foreach my $chr (keys %chr) {
    my $dna_file = "$species.$assembly.$month.dna.chromosome.$chr.fa.gz";
    my $dnarm_file = "$species.$assembly.$month.dna_rm.chromosome.$chr.fa.gz";
    delete($dna_files{$dna_file})or error("File $dna_file doesn't exist");
    delete($dna_files{$dnarm_file}) or error("File $dnarm_file doesn't exist");
  }

  # Check seq level is there
  my $flag_nonchrom = 0;
  my $flag_seqlevel = 0;
  foreach my $file  (keys %dna_files){
    if ( $file =~/Saccharomyces_cerevisiae.*chromosome\.fa\.gz/ ) {
      $flag_seqlevel++;
    }
    elsif ($file =~ /chromosome/ ) {
      error("Extra chromosome file $file.  Is this an old month's file? Current month: $month. Is this chr configured in INI file?") unless $file =~ /\.MT|\.DR\d+/;
    }
    elsif ($file =~ /nonchromosomal\.fa\.gz/) { $flag_nonchrom++;  }
    elsif ($file =~ /clone|scaffold|contig|chunk/i)  { $flag_seqlevel++;  }
  }

  error("No seqlevel DNA files") unless $flag_seqlevel >1;

}
#-----------------------------------------------------------------------------
sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  print( "[INFO] ".$msg."\n" );
  return 1;
}

#----------------------------------------------------------------------
sub warning{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  print( "[WARN] ".$msg."\n" );
 return 1;
}

#----------------------------------------------------------------------
sub error{
  my $msg = shift;
  $msg || ( carp("Need a warning message" ) && return );
  die "[DIE] ".$msg."\n\n" unless $WARN_ONLY;
  print STDERR "[WARN] ".$msg."\n\n" if $WARN_ONLY;
 return 1;
}

#----------------------------------------------------------------------

sub calculate_size {
  my $ftp_dir = shift;
  opendir (FTP, $ftp_dir) or die "Can't opendir $ftp_dir: $!";

  my @species_dirs;
  while (defined (my $ftp_file =  readdir(FTP) ) ) {
    next if $ftp_file =~/^\./;
    push (@species_dirs, $ftp_dir."/".$ftp_file."/data/");
  }
  closedir (FTP);

  foreach my $file_type qw(flatfiles fasta mysql) {
    my @dirs;
    foreach (@species_dirs) {
      push (@dirs, $_.$file_type) if -e $_.$file_type;
    }

    my $count = 0;
    find sub {
      my $file  = $File::Find::name;
      $count += -s $file unless (-d $file);
    }, @dirs;

    print "\n$file_type:", sprintf("%.0f", $count/1000000000),"G\n";
  }
  exit;
}


__END__

# date 10.5.04
# check that the transcripts have stable ids in pep and cdna files

=head1 NAME

check_dump - health checks on dump directories

=head1 SYNOPSIS

check_dumps.pl --release <release_version_number> [options]

Options:
  --help, --info, --dumpdir --species, --database, --type

Example:
 ./check_dump --release 29


=head1 OPTIONS

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<--verbose>
  Set verbosity level for debug output to stdout or logfile. Default 1

B<--dumpdir>
  Optional: Specifies root dumping directory. 
  DEFAULT: /mysql/dumps/FTP

B<--logfile>
  Optional: Specify a log file for output
  DEFAULT: Output to STDOUT

B<--species>
  Optional: One or more species to dump. 
  DEFAULT: All.

B<--mysql_dir>
  Optional: Where the mysql databases are.  
  DEFAULT: /mysql/current/var/

B<--type>
  Optional: Use if you only want to check a specific type of dump. 
  DEFAULT: all types. See --info for more details

B<--warn>
  Optional: Print a warning on errors rather than die 
  DEFAULT: Script dies on erros

B<--size>
  Optional: Print out of how much size (in Gigabytes) the fasta, mysql and flatfiles use
  DEFAULT: No size evaluation


=head1 DESCRIPTION

B<This program:>

Checks the mysql, fasta and flatfile dumps.

Output may include the following:

B<  [DIE*]:> Program critical error, dumps have halted.

B<  [WARN]:> Program has encountered an error but is still running, 
          dumps may have been affected.

B<  [INFO]>: Non-critical message, dumping should continue as normal

More on --type: Valid options are:

If you want to check all the dumps (pep, cdna, dna, rna), mysql, and flatfile dumps, leave this option out.

B<  fasta:> Check the fasta DNA, peptide, cDNA, and RNA files.

B<  mysql:> Check the mysql dumps.

B<  flatfiles:> Check the flatfile (embl/genbank) dumps.

Maintained by Ensembl web team <webmaster@ensembl.org>

=head1 CHECKS
.Check there is a directory for every spp + multi+mart in /mysql/dumps/FTP

B< Per species checks:>
.Check there is an FTP BASE directory configured in the conf/species.ini file
.Check the FTP BASE directory name matches the release version given with --release option
.Check there is at least one file in each directories listed in ok_dirs (i.e. cdna, dna, pep, rna, genbank, embl directories)
.Check files in the dir are not zero size
.Check files are gzipped and have correct names
.Check there are no files in the dir unless the directory is in $ok_files

B< FASTA dumps:>
.Check README is there
.Check cdna dir has not more than 5 files
.Check pep dir has not more than 4 files
.Check rna dir has not more than 1 file
.Check cdna contain DNA sequences [check first line has only ACGTN]
.Check pep contain pep sequences [check first line has amino acid letters]

DNA
.check one file per chr [given chr in the species.ini file] 
.check each chr has file for dna and dna_rm
.Check seq level is there

B< Flatfile dumps:>
.Check EMBL and GENBANK dirs have same number of files
.Check README is there
.Check all files in the embl or genbank end in .dat.gz

B< MySQL dumps:>
.Check the num of dirs under mysql is the same as number configured
.Check there is a core db configured for this species
.Check mysql files are all gzipped [ file name matches .gz]
.Check the *.sql.gz file contains the correct host and release version
.Check the mysql dirs have checksum files and sql files

Check there are 3 directories in /mysql/dumps/FTP/<species>/data
Check there are 3 directories in /mysql/dumps/FTP/<species>/data/fasta
Check there is 'embl' and 'genbank' under mysql/dumps/FTP/<species>/data/fasta/flatfile


TODO: MYSQL
contains only directories in /mysql/dumps/FTP/<species>/data/mysql
-list of db stored in /mysql/current/var
ls | grep _22 >/ensweb/wwwdev/server/databases_22.txt
- list of dumped files:
find . | grep mysql/ | grep -v .gz > mysql_files


=cut



