package utils::Tool;

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

=head2 all_species

  Arg[1]      :
  Example     : my @all_species = @{ utils::Tool::all_species };
  Description : returns a list of all the species configured in SiteDefs
                ENSEMBL_SPECIES
  Return type : arrayref

=cut

sub all_species {
  return $SiteDefs::ENSEMBL_SPECIES || [];
}

#----------------------------------------------------------------------

=head 2 check_dir

  Arg[1]     : directory name and path
  Example    : utils::Tool::check_dir($dir);
  Description: checks to see if directory exists. If yes, returns, if no, 
               it creates all the necessary directories in the path for the 
               directory to exist
  Return type: 1

=cut

sub check_dir {
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

=head2 mail_log

 Arg[1]: log to check
 Arg[2]: email address
 Description: checks log and emails you the results

=cut

sub mail_log {
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
  print SENDMAIL "Content-type: text/plain\n\n";
  print SENDMAIL $content . $additional_text;
  close(SENDMAIL);
  print "[INFO] Sent report to $email_address\n";
}


#-----------------------------------------------------------------------

=head2 check_species

  Arg1        : arrayref of species to check
  Arg[2]      : (Optional) personalised error message
  Example     : my @OK_SPECIES = @{ utils::Tool::check_species(\@SPECIES) };
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
  Example     : my %tmp = %{utils::Tool::get_config(  { species=>$spp, 
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
  Example     : utils::Tool::info(1, "Current release is $release");
  Description : Prints message to STDERR
  Return type : none

=cut

sub sz {
  my $size = `ps $$ -o vsz |tail -1`;
  chomp $size;
  my $unit = chop $size;
  if($unit eq "M"){
    $size *= 1024;
  } elsif ($unit eq "G"){
    $size *= 1048576;   # 1024*1024
  }
  my $rss = `ps $$ -o rss |tail -1`;
  chomp $rss;
  $unit = chop $rss;
  if($unit eq "M"){
    $rss *= 1024;
  } elsif ($unit eq "G"){
    $rss *= 1048576;   # 1024*1024
  }

  return($size, $rss); # return 0 for share, to avoid undef warnings
}

#------------------------------------------------------------------------
sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  my @sz = sz();
  if ($v > 1) {
    warn( "[INFO_2] ".$msg." (@sz)\n" );
  }
  else {
    warn( "[INFO] ".$msg." (@sz)\n" );
  }

  return 1;
}


#--------------------------------------------------------------------
=head2 mysql_db

  Arg[1]      : current ensembl release e.g. 30
  Example     : our %mysql_db =  %{ utils::Tool::mysql_db($release) };
  Description : produces a list of all the mysql database that match *$release*
  Return type : hashref

=cut

sub mysql_db {
  my $release = shift || "";
  my $species_defs = &species_defs;
  my $dsn = "DBI:mysql:host=". $species_defs->ENSEMBL_HOST .";port=" . $species_defs->ENSEMBL_HOST_PORT;
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
  Example     : $contents =  utils::Tool::mysql_db(\@contents, "Update here", $fh);
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
  Example     : my $mth =  utils::Tool::release_month();
  Description : Returns the first 3 letters (lowercase) of 
                either the current month if today's ' date is within the 
                first 10 days of the month 
                or the next month if today's ' date is after the 15th.
                This is a rough hack to estimate the month of the next Ensembl release
  Return type : three letter string

=cut


sub release_month {
  my $archive_date = lc($SiteDefs::ARCHIVE_VERSION);
  $archive_date =~ s/\d+//;
  return $archive_date;

  # Old way
  my @months = qw (jan feb mar apr may jun jul aug sep oct nov dec);
  my $day      = localtime->mday;
  my $curr_mth = localtime->mon;
  return $months[$curr_mth];
  #return  $day <10 ? $months[$curr_mth] : $months[$curr_mth +1];
}
#--------------------------------------------------------------------
=head2 site_logo

  Arg[1]      : none  
  Example     : my %logo = %{ utils::Tool::site_logo() };
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
  Example     : utils::Tool::species_defs
  Description : 
  Return type : $species_defs

=cut

sub species_defs {
  my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new(); 
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
  Example   : my %types = %{ utils::Tool::validate_types(\%valid_types, \%compound_types, \@user_types) };
  Description : Used make a list of types from a mixture of compound types and or valid types 
  Return type : hashref of types to use

=cut

sub validate_types {
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
  my @sz = sz();
  warn( "[WARN] ".$msg." (@sz)\n" );
  return 1;
}
#----------------------------------------------------------------------


__END__
           
=head1 NAME
                                                                                
Tool

=head1 SYNOPSIS

    use <path>::Tool;
    # Brief but working code example(s) here showing the most common usage

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible!

=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e. =head2, =head3, etc).

=head1 METHODS

An object of this class represents...

Below is a list of all public methods:



=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of 
whether they are likely to be fixed in an upcoming release.

=head1 AUTHOR
                                                                                
[name], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html


__END__
           
=head1 NAME
                                                                                
Tool

=head1 SYNOPSIS

    use <path>::Tool;
    # Brief but working code example(s) here showing the most common usage

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible!

=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e. =head2, =head3, etc).

=head1 METHODS

An object of this class represents...

Below is a list of all public methods:



=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of 
whether they are likely to be fixed in an upcoming release.

=head1 AUTHOR
                                                                                
[name], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
1;
