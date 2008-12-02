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

use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::ReleaseSpecies;

print "\n\n";

# Connect to web database and get news adaptor
use EnsEMBL::Web::RegObj;

$ENSEMBL_WEB_REGISTRY = EnsEMBL::Web::Registry->new();
my $SD = $ENSEMBL_WEB_REGISTRY->species_defs;

# Check database to see if this release is included already, then
# give the user the option to update the release date
my $release_id = $SD->ENSEMBL_VERSION;
my $release = EnsEMBL::Web::Data::Release->new($release_id);

if ($release) {

    print "Release $release_id is currently scheduled for ". $release->full_date .".
            Is this correct? [y/n]";

    while (<STDIN>) {
        chomp;
        unless (/^y$/i) {
            print "Please give the correct release date, formatted as yyyy-mm-dd:";  
            INPUT: while (<STDIN>) {
                chomp;
                if (/\d{4}-\d{2}-\d{2}/) {
                    print "Setting release date to $_\n\n";
                    $release->date($_);
                    $release->update;
                    last INPUT;
                }
                print "Sorry, that was not a valid date format.\nPlease input a date in format yyyy-mm-dd:";
            }
        }
        last;
    }
} else {
    if (!$date || $date !~ /\d{4}-\d{2}-\d{2}/) { 
        # no valid date supplied, so default to 1st of next month
        my @today = localtime(time);
        my $year = $today[5]+1900;
        my $nextmonth = $today[4]+2;
        if ($nextmonth > 12) {
            $nextmonth - 12;
            $year++;
        }
        $nextmonth = sprintf "%02d", $nextmonth;
        $date = $year.'-'.$nextmonth.'-01';
    }
    my $archive = $SiteDefs::ARCHIVE_VERSION;
    $release = EnsEMBL::Web::Data::Release->new({
        'release_id' => $release_id,
        'number'     => $release_id,
        'date'       => $date,
        'archive'    => $archive,
    });
    $release->save;
    
    print "Inserting release $release_id ($archive), scheduled for $date.\n\n";
}

# get the hash of all species in the database
my @db_spp = EnsEMBL::Web::Data::Species->find_all;
my %lookup;
foreach my $sp (@db_spp) {
  $lookup{$sp->name} = $sp->id;
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
    my $new_sp = EnsEMBL::Web::Data::Species->new($record);
    $species_id = $new_sp->save;
    print "Adding new species $sp to database, with ID $species_id\n";
  }
  else {
    $species_id = $lookup{$sp};
  }

  if ($species_id) {
    my $rs = EnsEMBL::Web::Data::ReleaseSpecies->find('release_id' => $release_id, 'species_id' => $species_id);
    my $rs_id = $rs->id;
    unless ($rs_id) {
      my $a_code = $SD->get_config($sp, 'ASSEMBLY_NAME');
      my $a_name = $SD->get_config($sp, 'ASSEMBLY_DISPLAY_NAME');
      my $record = { 
        'release_id' => $release_id,
        'species_id' => $species_id,
        'assembly_code' => $a_code || '',
        'assembly_name' => $a_name || '',
      };
      $rs = EnsEMBL::Web::Data::ReleaseSpecies->new($record);
      $rs_id = $rs->save;
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
