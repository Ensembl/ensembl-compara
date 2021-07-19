#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
use Carp;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

my ($SERVERROOT, $help, $info, $date);

## In debug mode, select queries will be run but not inserts and updates
my $DEBUG = 0;

BEGIN{
  &GetOptions(
    'help'    => \$help,
    'info'    => \$info,
    'date=s'  => \$date,
  );

  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;

  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::DBHub;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

print "\n\n";

my $hub = EnsEMBL::Web::DBHub->new;
my $sd  = $hub->species_defs;
my $tmp_dir = $sd->ENSEMBL_TMP_DIR;

# Check database to see if this release is included already, then
# give the user the option to update the release date

my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
my ($sql, $sth, @args);

my $release_id = $sd->ENSEMBL_VERSION;
my $release = $adaptor->fetch_release($release_id);

print "TMP DIR==== ".$tmp_dir;

my $file = 'Update_ensembl_archive_for_release_'.$release_id.'.sql';
open PATCH, ">$tmp_dir/$file" or die "ERROR: $!";

print PATCH "use ensembl_archive;\n\n";

if ($release) {
  print "Release $release_id is currently scheduled for ". $release->{'date'} .".
            Is this correct? [y/n]";

  while (<STDIN>) {
    chomp;
    unless (/^y$/i) {
      print "Please give the correct release date, formatted as full month name and year separated by a space, e.g. March 2015:";
      INPUT: while (<STDIN>) {
        chomp;
        my ($month, $year) = /([A-Z][a-z]+) (\d{4})/;
        if ($month && $year) {
          my $short_month = substr($month, 0, 3);
          my $archive = $short_month.$year;
          print "Setting release date to $_ and archive subdomain to $archive\n\n";
          $sql = "UPDATE ens_release SET date = '$_', archive = '$archive' WHERE release_id = $release_id";

          print PATCH "$sql\n\n";
          last INPUT;
        }
        else {
          print "Sorry, that was not a valid date format.\n";
          exit;
        }
      }
    }
    last;
  }
} else {
  my $archive = $sd->ARCHIVE_VERSION;
  my $date = $hub->pretty_date($archive);
  $sql = "INSERT INTO ens_release (release_id, number, date, archive, online, mart) values($release_id, $release_id, \"$date\", \"$archive\", \"Y\", \"Y\");";
  print "For inserting release $release_id, scheduled for $date.\n\n";
  print PATCH "$sql\n\n";
}

print "Adding species...\n\n";

# get the hash of all species in the database
my @db_spp = @{$adaptor->fetch_all_species};
my $max_id = 0;
my %lookup;

foreach my $sp (@db_spp) {
  $max_id = $sp->{'id'} if $sp->{'id'} > $max_id;
  $lookup{$sp->{'name'}} = $sp->{'id'};
}

# get a list of valid (configured) species
my @species = $sd->valid_species();
my ($result, $species_id);

SPECIES: foreach my $sp (sort @species) {

  # check if this species is in the database yet
  if (!$lookup{$sp}) {
    $max_id++;
    $species_id = $max_id;
    my $code = $sd->get_config($sp, 'SPECIES_CODE');
    $sql = sprintf ('INSERT INTO species (species_id, code, name, common_name, vega, online) VALUES (%s, %s, "%s", "%s", "%s", "%s");',
            ($species_id, $code ? qq("$code") : 'NULL'), $sd->get_config($sp, 'SPECIES_URL'),
            $sd->get_config($sp, 'SPECIES_COMMON_NAME'), 'N', 'Y');
    print PATCH "\n$sql\n";
    print "Added new species $sp to database, with ID $species_id\n";
  }
  else {
    $species_id = $lookup{$sp};
  }

  ## Now add the species to this release
  if ($species_id) {
    $sql = 'SELECT release_id FROM release_species WHERE release_id = ? AND species_id = ?';
    @args = ($release_id, $species_id);
    $sth = $adaptor->db->prepare($sql);
    $sth->execute(@args);
    my $already_done = 0;
    while (my @data = $sth->fetchrow_array()) {
      $already_done = 1;
    }
    if ($already_done) {
      print "Species $sp is already in the database.\n";
    }
    else {
      my $a_name = $sd->get_config($sp, 'ASSEMBLY_NAME') || '';
      my $a_version = $sd->get_config($sp, 'ASSEMBLY_VERSION') || '';

      ## Check if the assembly has changed - mostly to catch human error!
      $sql = 'SELECT assembly_version, assembly_name FROM release_species WHERE release_id = ? AND species_id = ?';
      @args = ($release_id-1, $species_id);
      $sth = $adaptor->db->prepare($sql);
      $sth->execute(@args);
      while (my @data = $sth->fetchrow_array()) {
        my $old_version   = $data[0];
        my $old_name      = $data[1];
        if ($old_version) {
          my $is_different  = 0;
          if ($old_version ne $a_version) {
            print "!!! $sp: Old assembly version was $old_version; new version is $a_version\n";
            $is_different = 1;
          }
          if ($old_name ne $a_name) {
            print "!!! $sp:Old assembly name was $old_name; new name is $a_name\n";
            $is_different = 1;
          }
          if ($is_different) {
            print "If this is not correct, please manually patch the core and ensembl_archive databases after this script has run\n";
          }
        }
      }

      ## Now set new assembly
      my $initial = $sd->get_config($sp, 'GENEBUILD_RELEASE') || '';
      my $latest = $sd->get_config($sp, 'GENEBUILD_LATEST') || '';
      $sql = sprintf ('INSERT INTO release_species VALUES (%d, %d, "%s", "%s", "%s", "%s", "%s", "%s", "%s");',
              $release_id, $species_id, $sd->get_config($sp, 'SPECIES_URL'), $a_version, $a_name, '', '', $initial, $latest);
      print PATCH "$sql\n\n";
    }
  }
  else {
    print "Sorry, unable to add record for $sp\n";
  }
}

close PATCH;

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
