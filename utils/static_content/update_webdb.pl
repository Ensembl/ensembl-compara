#!/usr/local/bin/perl

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

my ( $SERVERROOT, $help, $info, $date);

BEGIN{
  &GetOptions( 
	      'help'      => \$help,
	      'info'      => \$info,
          'date=s'    => \$date,
	     );
  
  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;
  
  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

print "\n\n";

my $hub = new EnsEMBL::Web::Hub;
my $SD = $hub->species_defs;

# Check database to see if this release is included already, then
# give the user the option to update the release date

my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
my ($sql, $sth, @args); 

my $release_id = $SD->ENSEMBL_VERSION;
my $release = $adaptor->fetch_release($release_id);

if ($release) {
    print "Release $release_id is already in the database.\n\n";

} else {
    my $archive = $SiteDefs::ARCHIVE_VERSION;
    my $date = $hub->pretty_date($archive);
    $sql = 'INSERT INTO ens_release values(?, ?, ?, ?, ?, ?)';
    @args = ($release_id, $release_id, $date, $archive, 'Y', 'Y');
    $sth = $adaptor->db->prepare($sql);
    $sth->execute(@args);
    print "Inserting release $release_id, scheduled for $date.\n\n";
}

print "Adding species...\n\n";

# get the hash of all species in the database
my @db_spp = @{$adaptor->fetch_all_species}; 
my %lookup;
foreach my $sp (@db_spp) {
  $lookup{$sp->{'name'}} = $sp->{'id'};
}

# get a list of valid (configured) species
my @species = $SD->valid_species();
my ($record, $result, $species_id);

foreach my $sp (sort @species) {

  # check if this species is in the database yet
  if (!$lookup{$sp}) {
    my $record = {
      'name'          => $SD->get_config($sp, 'SPECIES_BIO_NAME'),
      'common_name'   => $SD->get_config($sp, 'SPECIES_COMMON_NAME'),
      'code'          => $SD->get_config($sp, 'SPECIES_CODE'),
    };
    $sql = 'INSERT INTO species SET code = ?, name = ?, common_name = ?, vega = ?, online = ?';
    @args = ($SD->get_config($sp, 'SPECIES_CODE'), $SD->get_config($sp, 'SPECIES_BIO_NAME'),
              $SD->get_config($sp, 'SPECIES_COMMON_NAME'), 'N', 'Y');
    $sth = $adaptor->db->prepare($sql);
    $sth->execute(@args);
    print "Adding new species $sp to database, with ID $species_id\n";
  }
  else {
    $species_id = $lookup{$sp};
  }

  if ($species_id) {
    $sql = 'SELECT release_id FROM release_species WHERE release_id = ? AND species_id = ?';
    @args = ($release_id, $species_id);
    $sth = $adaptor->db->prepare($sql);
    $sth->execute(@args);
    my $already_done = 0;
    while (my @data = $sth->fetchrow_array()) {
      $already_done = 1;
    }
    unless ($already_done) {
      my $a_code = $SD->get_config($sp, 'ASSEMBLY_NAME') || ''; 
      my $a_name = $SD->get_config($sp, 'ASSEMBLY_DISPLAY_NAME') || '';
      my $initial = $SD->get_config($sp, 'GENEBUILD_RELEASE') || ''; 
      my $latest = $SD->get_config($sp, 'GENEBUILD_LATEST') || '';
      $sql = 'INSERT INTO release_species VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
      @args = ($release_id, $species_id, $a_code, $a_name, '', '', $initial, $latest);
      $sth = $adaptor->db->prepare($sql);
      $sth->execute(@args);
      print "ADDED $sp to release $release_id \n";
    }
  }
  else {
    print "Sorry, unable to add record for $sp as no species ID found\n";
  }
}

=head1 NAME

update_webdb.pl

=head1 SYNOPSIS

update_webdb.pl [options]

Options:
  --help, --info, --date

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<-d,--date>
  Release date (optional). If this is the first time you have run this script for a release,
  you should specify a release date in the format yyyy-mm-dd - otherwise it will default to
  the first day of next month!

=head1 DESCRIPTION

B<This program:>

Updates the ensembl_website database by inserting records from the current release's ini files.

It will add information about the release itself (if not already present), based on variables in
the SiteDefs.pm module, and also prompts the user for a release date. If the release record is
present, it asks the user if the release date is still correct.

It then either adds a cross-reference record between the release and the species configured for 
that release, or reports on existing cross-reference records. If a new species has been added to 
this release, a species record will be added to the database provided there is an ini file for it 
in the correct location.

The database location is specified in Ensembl web config file:
  ../conf/ini-files/DEFAULTS.ini

=head1 AUTHOR

Anne Parker, Ensembl Web Team

Enquiries about this script should be addressed to ensembl-webteam@sanger.ac.uk

=cut
