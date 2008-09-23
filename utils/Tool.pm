package utils::Tool;

### Collection of methods created for use with the dumping scripts

use strict;
use warnings;
use Pod::Usage;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use DBI;
use Time::localtime;
use File::Path;

use vars qw( $SERVERROOT );
our $VERBOSITY = 1;

BEGIN {
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;  
}
require EnsEMBL::Web::SpeciesDefs; 

#----------------------------------------------------------------------
sub all_species {

  ### Example     : my @all_species = @{ utils::Tool::all_species };
  ### Description : returns a list of all the species configured in SiteDefs
  ###                ENSEMBL_SPECIES
  ### Returns arrayref

  return $SiteDefs::ENSEMBL_SPECIES || [];
}

#------------------------------------------------------------------------
sub start_with_species {

  ### Arg1        : species name
  ### Arg2        : arrayref
  ### Example     : my @species = @{ utils::Tool::start_with_species };
  ### Description : removes species from the name supplied whoose names 
  ###              come before the species name supplied (when listed 
  ###              alphabetically)
  ### Returns arrayref

  my ($start_with, $species) = @_;

  foreach (sort @$species) {
    last if $start_with eq $_;
    info(1, "Skipping $_ and all species until $start_with");
    shift @$species;
  }
  return $species || [] ;
}

#----------------------------------------------------------------------
sub end_with_species {

  ### Arg1        : species name
  ### Arg2        : arrayref
  ### Example     : my @species = @{ utils::Tool::end_with_species };
  ### Description : removes species from a list whoose names start
  ###                after the argument supplied when listed alphabetically
  ### Returns arrayref

  my ($end_with, $species) = @_;

  my @return;
  foreach (sort @$species) {
    push @return, shift @$species;
    last if $end_with eq $_;
  }

  info(1, "Skipping these species: @$species");
  return \@return || [] ;
}

#----------------------------------------------------------------------
sub check_dir {

  ### Arg[1]     : directory name and path
  ### Example    : utils::Tool::check_dir($dir);
  ### Description: checks to see if directory exists. If yes, returns, if no, 
  ###            it creates all the necessary directories in the path for the 
  ###         directory to exist
  ###  Return type: 1

  my $dir = shift;
  if( ! -e $dir ){
    info(1, "Creating $dir" );
    eval { mkpath($dir) };
    if ($@) {
      print "Couldn't create $dir: $@";
    }
  }
  return 1;
}
  
#------------------------------------------------------------------------
sub mail_log {

 ### Arg1 (optional): log to check
 ### Arg2 (optional): email address
 ### Description: checks log and emails you the results

  my ($file, $email_address, $additional_text) = @_;
  open IN, "< $file" or die "Can't open $file : $!";
  my $content;
  while (<IN>) {
    $content .= $_  unless $_=~ /^\[INFO\]/;
  }

  my $sendmail = "/usr/sbin/sendmail -t";
  my $subject  = "Subject: Dumping report\n";

  open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
  print SENDMAIL $subject;
  print SENDMAIL "To: $email_address\n";
  print SENDMAIL 'From: ssg-ensembl@sanger.ac.uk\n';
  print SENDMAIL "Content-type: text/plain\n\n";
  print SENDMAIL $content . $additional_text;
  close(SENDMAIL);
  print "[INFO] Sent report to $email_address\n";
}


#-----------------------------------------------------------------------
sub check_species {

  ### Arg1        : arrayref of species to check
  ### Arg2(Optional):  personalised error message
  ### Example     : my @OK_SPECIES = @{ utils::Tool::check_species(\@SPECIES) };
  ### Description : checks each species from arg1 to see if they are valid
  ###                returns arrayref if they are all valid.  
  ###             Otherwise throws an error
  ### Returns array_ref or error message

   my $species = shift;
  my $error   = shift || "[*DIE] Invalid species. Select from:\n";
  my %all_species = map{$_=>1} ( @{&all_species}, "Multi");
  
  foreach my $spp (@$species) {
    next if $all_species{$spp};
    pod2usage("$spp: $error". join( "\n  ", sort keys %all_species ) );
  }
  return $species;
}
#---------------------------------------------------------------------
sub get_config {

  ### Arg1        : hashref of arguments 
  ### Example     : my %tmp = %{utils::Tool::get_config(  { species=>$spp, 
  ###				 	      values => $source}   )};
  ### Description : retrieves the value of $args->{values} from species defs
  ### Returns hashref

  my $args = shift;
  my $species_defs = &species_defs;
  my $values = $species_defs->get_config($args->{species}, $args->{values});
  return $values || {};
}

#----------------------------------------------------------------------
sub sz {
  return(0,0);
  ## ps parameters not compatible with Linux!
  my $size = `ps -o vsz $$ | tail -1`;
  chomp $size;
  my $unit = chop $size;
  if($unit eq "M"){
    $size *= 1024;
  } elsif ($unit eq "G"){
    $size *= 1048576;   # 1024*1024
  }
  my $rss = `ps -o rss $$ | tail -1`;
  chomp $rss;
  $unit = chop $rss;
  if($unit eq "M"){
    $rss *= 1024;
  } elsif ($unit eq "G"){
    $rss *= 1048576;   # 1024*1024
  }

  return($size, $rss); ### Returns 0 for share, to avoid undef warnings
}

#------------------------------------------------------------------------
sub info{

  ### Arg1      : verbosity
  ### Arg2      : message
  ### Example     : utils::Tool::info(1, "Current release is $release");
  ### Description : Prints message to STDERR
  ### Returns none

  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  #if( $v > $VERBOSITY ){ return 1 }
  my @sz = () ;#sz();
  if ($v > 1) {
    warn( "[INFO_2] ".$msg." (@sz)\n" );
  }
  else {
    warn( "[INFO] ".$msg." (@sz)\n" );
  }

  return 1;
}


#--------------------------------------------------------------------
sub mysql_db {

  ### Arg[1]      : current ensembl release e.g. 30
  ### Example     : our %mysql_db =  %{ utils::Tool::mysql_db($release) };
  ### Description : produces a list of all the mysql database that match *$release*
  ### Returns hashref

  my $release = shift || "";
  my $species_defs = &species_defs;
  my $dsn = "DBI:mysql:host=". $species_defs->DATABASE_HOST .";port=" . $species_defs->DATABASE_HOST_PORT;
  my $dbh = DBI->connect($dsn, 'ensro') or die "\n[*DIE] Can't connect to database '$dsn'";
  my $mysql = $dbh->selectall_arrayref("show databases like '%$release%'");
  $dbh->disconnect;

  my %mysql_db;
  foreach (@$mysql) {
    $mysql_db{$_->[0]} = 1;
  }
  return \%mysql_db;
}

#--------------------------------------------------------------------------
sub print_next {

  ### Arg1      : arrayref where each value is a line of the file
  ### Arg2      : string to match
  ### Arg3      : file handle
  ### Example     : $contents =  utils::Tool::mysql_db(\@contents, "Update here", $fh);
  ### Description : Takes an array of file contents.  Prints each line in the array to $fh
  ### until a line matches arg2.
  ### Returns arrayref

  my $contents = shift;
  my $last     = shift;
  my $fh       = shift;

  my $count_rows;
  foreach (@$contents) {
    last if $_ =~/$last/;
    $count_rows++;
    print $fh $_;
  }

  splice(@$contents, 0, $count_rows); # @contents has rest of file
  return $contents;
}

#--------------------------------------------------------------------
sub site_logo {

  ### Example     : my %logo = %{ utils::Tool::site_logo() };
  ### Description : Retreives the SITE_LOGO as defined in DEFAULTS.ini by SITE_LOGO_KEY
  ### Returns hashref of info

  my $species_defs = &species_defs;
  return
      { src    => $species_defs->SITE_LOGO,          
        height => $species_defs->SITE_LOGO_HEIGHT,
        width  => $species_defs->SITE_LOGO_WIDTH,
        alt    => $species_defs->SITE_LOGO_ALT, 
        href   => $species_defs->SITE_LOGO_HREF}
  or die "no Site logo defined: $species_defs->SITE_LOGO";
}

#----------------------------------------------------------------------
sub species_defs {

  ### Example     : utils::Tool::species_defs
  ### Description : 
  ### Returns $species_defs

  my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new(); 
  $SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
  return $SPECIES_DEFS;
}

#----------------------------------------------------------------------
sub validate_types {

  ### Arg1      : hashref of valid types e.g. %vt = map{$_=>1}  qw(all blast ftp);
  ### Arg2      : hashref of compound types e.g. %ct = ( all => [ qw(db blast ftp) ] );
  ### Arg3      : arrayref of user types
  ### Example   : %types = %{ utils::Tool::validate_types(\%vt, \%ct, \@user_types) };
  ### Description : Used make a list of types from a mixture of compound types and or valid types 
  ### Returns hashref of types to use

   my $valid_types    = shift;
   my $compound_types = shift;
   my $user_types     = shift;

   my @types;
   foreach my $type( @$user_types ){  # user's input types
     # If it is a compound type, add the individual types to @$user_types array
     if( $compound_types->{$type} ){
       push (@$user_types, @{ $compound_types->{$type} } );
       next;
     }
     $valid_types->{$type} or pod2usage("[*DIE] Invalid update type: $type\n\n" ) 
&& next;
     push @types, $type;
   }

   scalar( @types ) or pod2usage("[*DIE] Need a valid type to dump" );
   info (1, "Dumping types: ".(join  " ", @types));
   return \@types;
 }
#-------------------------------------------------------------------------
sub warning{

  ### Arg[1]      : verbosity
  ### Arg 2       : message
  ### Example     : 
  ### Description : Prints warning message
  ### Returns 1

  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  my @sz = sz();
  warn( "[WARN] ".$msg." (@sz)\n" );
  return 1;
}
#----------------------------------------------------------------------


1;
