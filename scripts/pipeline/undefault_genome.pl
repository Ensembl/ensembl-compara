#!/usr/bin/env perl
# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

my $description = q{
###########################################################################
##
## PROGRAM undefault_genome.pl
##
## DESCRIPTION
##    This script takes a GenomeDB and sets its as non-default, updating
##    all the collections it belongs to
##
###########################################################################

};

=head1 NAME

undefault_genome.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script sets a genome_db as non-default, and removes it from all the collections

=head1 SYNOPSIS

perl undefault_genome.pl --help

perl undefault_genome.pl
    [--compara_url compara_master_url]
        The Compara master database to update
    [--genome_db_id genome_db_id | --species species_name]
        The name / genome_db_id of the species to make non-default

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--compara_url compara_master_url]>

The Compara master database to update

=item B<[--genome_db_id genome_db_id | --species species_name]>

The name / genome_db_id of the species to make non-default

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Getopt::Long;

my $usage = qq{
perl undefault_genome.pl

  Getting help:
    [--help]

  General configuration:
    [--compara_url compara_master_url]
        The Compara master database to update
    [--genome_db_id genome_db_id | --species species_name]
        The name / genome_db_id of the species to make non-default
};

my $help;

my $compara_url;
my $species;
my $genome_db_id;

GetOptions(
    "help" => \$help,
    "compara_url=s" => \$compara_url,
    "species=s" => \$species,
    "genome_db_id=i" => \$genome_db_id,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !($species or $genome_db_id) or !$compara_url) {
    print $description, $usage;
    exit(0);
}

die "Do not give both -genome_db_id and -species\n" if ($genome_db_id and $species);

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $compara_url);
throw ("Cannot connect to database [$compara_url]") if (!$compara_dba);

my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_dba->dbc);
$helper->transaction( -CALLBACK => sub {
    my $genome_db = update_genome_db($compara_dba, $genome_db_id, $species);
    update_collections($compara_dba, $genome_db);
});


exit(0);


=head2 update_genome_db

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : int $genome_db_id
  Arg[3]      : string $species
  Description : This method fetches the GenomeDB and sets its assembly_default field to 0
  Returns     : The new Bio::EnsEMBL::Compara::GenomeDB object

=cut

sub update_genome_db {
    my ($compara_dba, $genome_db_id, $species) = @_;

    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $genome_db = $genome_db_id
        ? $genome_db_adaptor->fetch_by_dbID($genome_db_id)
        : $genome_db_adaptor->fetch_by_name_assembly($species);

    die "Could not fetch the GenomeDB\n" unless $genome_db;
    die "This GenomeDB is already non-default\n" unless $genome_db->assembly_default;

    my $sth = $compara_dba->dbc->prepare('UPDATE genome_db SET assembly_default = 0 WHERE genome_db_id = ?');
    my $nrows = $sth->execute($genome_db->dbID);
    $sth->finish();
    die "assembly_default has not been updated |\n" unless $nrows;

    # Here, the cache is partly invalid (we haven't udpated the lookup for
    # name / default assembly)
    return $genome_db;
}


=head2 update_collections

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method updates all the collection species sets to
                exclude the given genome_db
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub update_collections {
  my ($compara_dba, $genome_db) = @_;

  # Gets all the collections with that genome_db
  my $sql = 'SELECT species_set_id FROM species_set_tag JOIN species_set USING (species_set_id) JOIN genome_db USING (genome_db_id) WHERE tag = "name" AND value LIKE "collection-%" AND name = ?';
  my $ss_ids = $compara_dba->dbc->db_handle->selectall_arrayref($sql, undef, $genome_db->name);

  my $ssa = $compara_dba->get_SpeciesSetAdaptor;
  my $sss = $ssa->fetch_all_by_dbID_list([map {$_->[0]} @$ss_ids]);

  foreach my $ss (@$sss) {
      my $new_genome_dbs = [grep {$_->dbID != $genome_db->dbID} @{$ss->genome_dbs}];
      my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $new_genome_dbs );
      $ssa->store($species_set);
      my $sql = 'UPDATE species_set_tag SET species_set_id = ? WHERE species_set_id = ? AND tag = "name"';
      my $sth = $compara_dba->dbc->prepare($sql);
      $sth->execute($species_set->dbID, $ss->dbID);
      $sth->finish();
  }
}


