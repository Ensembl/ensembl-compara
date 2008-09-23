package EnsEMBL::Web::BlastView::Tool;

use strict;
use warnings;
use Pod::Usage;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use DBI;
use Time::localtime;

use vars qw( $SERVERROOT );
our $VERBOSITY = 1;

BEGIN {
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;  
}
use EnsEMBL::Web::SpeciesDefs;

#----------------------------------------------------------------------

=head2 all_species

  Arg[1]      :
  Example     : my @all_species = @{ EnsEMBL::Web::BlastView::Tool::all_species };
  Description : returns a list of all the species configured in SiteDefs
                ENSEMBL_SPECIES
  Return type : arrayref

=cut

sub all_species {
  return $SiteDefs::ENSEMBL_SPECIES || [];
}

#----------------------------------------------------------------------
=head2 check_species

  Arg1        : arrayref of species to check
  Arg[2]      : (Optional) personalised error message
  Example     : my @OK_SPECIES = @{ EnsEMBL::Web::BlastView::Tool::check_species(\@SPECIES) };
  Description : checks each species from Arg1 to see if they are valid
                returns Arg1 arrayref if they are all valid.  
                Otherwise throws an error
  Return type : array_ref or error message

=cut

sub check_species {
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
=head2 get_config

  Arg1        : hashref of arguments 
  Example     : my %tmp = %{EnsEMBL::Web::BlastView::Tool::get_config(  { species=>$spp, 
				 	      values => $source}   )};
  Description : retrieves the value of $args->{values} from species defs
  Return type : hashref

=cut

sub get_config {
  my $args = shift;
  my $species_defs = &species_defs;
  my $values = $species_defs->get_config($args->{species}, $args->{values});
  return $values || {};
}

#----------------------------------------------------------------------
=head2 info

  Arg[1]      : verbosity
  Arg[1]      : message
  Example     : EnsEMBL::Web::BlastView::Tool::info(1, "Current release is $release");
  Description : Prints message to STDERR
  Return type : none

=cut

sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[INFO] ".$msg."\n" );
  return 1;
}


#--------------------------------------------------------------------
=head2 mysql_db

  Arg[1]      : current ensembl release e.g. 30
  Example     : our %mysql_db =  %{ EnsEMBL::Web::BlastView::Tool::mysql_db($release) };
  Description : produces a list of all the mysql database that match *$release*
  Return type : hashref

=cut

sub mysql_db {
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
=head2 print_next

  Arg1      : arrayref where each value is a line of the file
  Arg2      : string to match
  Arg3      : file handle
  Example     : $contents =  EnsEMBL::Web::BlastView::Tool::mysql_db(\@contents, "Update here", $fh);
  Description : Takes an array of file contents.  Prints each line in the array to $fh
                until a line matches Arg2. Returns the remainder of the file as 
                arrayref
  Return type : arrayref

=cut

sub print_next {
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
=head2 release_month

  Arg[1]      : none
  Example     : my $mth =  EnsEMBL::Web::BlastView::Tool::release_month();
  Description : Returns the first 3 letters (lowercase) of 
                either the current month if today's ' date is within the 
                first 15 days of the month 
                or the next month if today's ' date is after the 15th.
                This is a rough hack to estimate the month of the next Ensembl release
  Return type : three letter string

=cut


sub release_month {
  my @months = qw (jan feb mar apr may jun jul aug sep oct nov dec);
  my $day      = localtime->mday;
  my $curr_mth = localtime->mon;
  return  $day <15 ? $months[$curr_mth] : $months[$curr_mth +1];
}
#--------------------------------------------------------------------
=head2 site_logo

  Arg[1]      : none  
  Example     : my %logo = %{ EnsEMBL::Web::BlastView::Tool::site_logo() };
  Description : Retreives the SITE_LOGO as defined in DEFAULTS.ini by SITE_LOGO_KEY
  Return type : hashref of info

=cut

sub site_logo {
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
=head2 species_defs

  Arg[1]      : none  
  Example     : EnsEMBL::Web::BlastView::Tool::species_defs
  Description : 
  Return type : $species_defs

=cut

sub species_defs {
  my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
  $SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
  return $SPECIES_DEFS;
}

#----------------------------------------------------------------------
=head2 validate_types

  Arg1      : hashref of valid types
               my %valid_types = map{ $_ => 1 }  qw( all db blast ftp_dir  );
  Arg2      : hashref of compound types
              my %compound_types =   ( all   => [ qw( db blast ftp_dir  ) ]   );
  Arg3      : arrayref of user types
  Example   : my %types = %{ EnsEMBL::Web::BlastView::Tool::validate_types(\%valid_types, \%compound_types, \@user_types) };
  Description : Used make a list of types from a mixture of compound types and or valid types 
  Return type : hashref of types to use

=cut

sub validate_types {
   my $valid_types    = shift;
   my $compound_types = shift;
   my $user_types     = shift;

   my %types;
   foreach my $type( @$user_types ){  # user's input types
     # If it is a compound type, add the individual types to @$user_types array
     if( $compound_types->{$type} ){
       push (@$user_types, @{ $compound_types->{$type} } );
       next;
     }
     $valid_types->{$type} or pod2usage("[*DIE] Invalid update type: $type\n\n" ) 
&& next;
     $types{$type} = 1;  # add to %types if valid update
   }

   scalar( keys %types ) or pod2usage("[*DIE] Need a valid type to dump" );
   info (1, "Dumping types: ".(join  " ", keys %types));
   return \%types;
 }
#-------------------------------------------------------------------------

=head2 warning

  Arg[1]      : verbosity
  Arg 2       : message
  Example     : 
  Description : Prints warning message
  Return type : none

=cut

sub warning{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[WARN] ".$msg."\n" );
  return 1;
}
#----------------------------------------------------------------------
1;
