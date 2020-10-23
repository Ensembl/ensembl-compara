=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 DESCRIPTION

This modules contains common methods used when dealing with the
Compara references database.

    - update_reference_genome : add a reference genome to the given database
    - remove_reference_genome : remove reference from the db, incl dnafrags and members

=cut

package Bio::EnsEMBL::Compara::Utils::ReferenceDatabase;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

############################################################
#          update_reference_genome.pl methods              #
############################################################

=head2 update_reference_genome

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : string $species_name
  Arg[3]      : (optional) boolean $force
  Arg[4]      : (optional) int $taxon_id
  Arg[5]      : (optional) int $offset
  Description : Does everything for this species: create / update the GenomeDB entry, and load the DnaFrags.
                If the GenomeDB already exists, set $force = 1 to force the update of DnaFrags. Use $taxon_id
                to manually set the taxon id for this species (default is to find it in the core db).
                $offset can be used to override autoincrement of dbID
  Returns     : arrayref containing (1) new Bio::EnsEMBL::Compara::GenomeDB object, (2) arrayref of updated
                component GenomeDBs, (3) number of dnafrags updated
  Exceptions  : none

=cut

sub update_reference_genome {
    my $compara_dba = shift;
    my $species = shift;

    my($force, $taxon_id, $offset) = rearrange([qw(FORCE TAXON_ID OFFSET)], @_);

    my $species_no_underscores = $species;
    $species_no_underscores =~ s/\_/\ /;

    my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
    if(! $species_db) {
        $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species_no_underscores, "core");
    }
    throw ("Cannot connect to database [${species_no_underscores} or ${species}]") if (!$species_db);

    my ( $new_genome_db, $component_genome_dbs, $new_dnafrags );
    my $gdbs = $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        $new_genome_db = _update_reference_genome_db($species_db, $compara_dba, $force, $taxon_id, $offset);
        print "Reference GenomeDB after update: ", $new_genome_db->toString, "\n\n";
        print "Fetching DnaFrags from " . $species_db->dbc->host . "/" . $species_db->dbc->dbname . "\n";
        $new_dnafrags = Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_dnafrags($compara_dba, $new_genome_db, $species_db);
    } );
    $species_db->dbc()->disconnect_if_idle();
    return [$new_genome_db, $new_dnafrags];
}


=head2 _update_reference_genome_db

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[4]      : (optional) boolean $force
  Arg[5]      : (optional) int $taxon_id
  Arg[6]      : (optional) int $offset
  Description : This method takes all the information needed from the
                species database in order to update the genome_db table
                of the compara database
  Returns     : The new Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : throw if the genome_db table is up-to-date unless the
                --force option has been activated

=cut

sub _update_reference_genome_db {
    my ($species_dba, $compara_dba, $force, $taxon_id, $offset) = @_;

    # create new genome_db from the core in order to compare genebuilds
    my $new_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor($species_dba);

    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    my $stored_genome_db = eval {$genome_db_adaptor->fetch_by_core_DBAdaptor($species_dba)};

    my $genome_db;
    if ($stored_genome_db and $stored_genome_db->dbID and $stored_genome_db->genebuild eq $new_genome_db->genebuild) {
        if (not $force) {
            my $species_production_name = $stored_genome_db->name;
            my $this_assembly = $stored_genome_db->assembly;
            my $this_genebuild = $stored_genome_db->genebuild;
            print $stored_genome_db->toString, "\n";
            my ($match, $output);
            {
                # dnafrags_match_core_slices uses print. This is to capture the output
                local *STDOUT;
                open (STDOUT, '>', \$output);
                $match = Bio::EnsEMBL::Compara::Utils::MasterDatabase::dnafrags_match_core_slices($stored_genome_db, $species_dba);
            }
            my $msg = "\n\n** Reference GenomeDB with this name [$species_production_name], assembly".
            " [$this_assembly] and genebuild.last_geneset_update [$this_genebuild] is already in the compara DB **\n";
            if ($match) {
                $msg .= "** And it has the right set of DnaFrags **\n";
                $msg .= "** You can use the --force option to update the other GenomeDB fields IF YOU REALLY NEED TO!! **\n\n";
            } else {
                $msg .= "** But the DnaFrags don't match: **\n$output\n";
                $msg .= "** You can use the --force option to update the DnaFrag, but only IF YOU REALLY KNOW WHAT YOU ARE DOING!! **\n\n";
            }
            throw $msg;
        }
        else {
            print "Reference GenomeDB before update: ", $stored_genome_db->toString, "\n";

            # Get fresher information from the core database
            $stored_genome_db->db_adaptor($species_dba, 1);
            $stored_genome_db->last_release(undef);

            # And store it back in Compara
            $genome_db_adaptor->update($stored_genome_db);
            $genome_db = $stored_genome_db;
        }
    } else { # new genome or new assembly!!
        $new_genome_db->taxon_id( $taxon_id ) if $taxon_id;

        if (!defined($new_genome_db->name)) {
            throw "Cannot find species.production_name in meta table for ".($species_dba->locator).".\n";
        }
        if (!defined($new_genome_db->taxon_id)) {
            throw "Cannot find species.taxonomy_id in meta table for ".($species_dba->locator).".\n".
                  "   You can use the --taxon_id option";
        }
        print "New reference GenomeDB for Compara: ", $new_genome_db->toString, "\n";

        # new ID search if $offset is true
        if($offset) {
            my ($max_id) = $compara_dba->dbc->db_handle->selectrow_array('select max(genome_db_id) from genome_db where genome_db_id > ?', undef, $offset);
            $max_id = $offset unless $max_id;
            $new_genome_db->dbID($max_id + 1);
        }
        $genome_db_adaptor->store($new_genome_db);
        $genome_db = $new_genome_db;
    }

    $genome_db_adaptor->make_object_current($genome_db);
    return $genome_db;
}


############################################################
#          remove_reference_genome.pl methods              #
############################################################

=head2 remove_reference_genome

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : Remove all trace of $genome_db from the $compara_dba database. This includes
                dnafrags and members
  Returns     : none
  Exceptions  : throws if $genome_db is not a Bio::EnsEMBL::Compara::GenomeDB

=cut

sub remove_reference_genome {
    my ($compara_dba, $genome_db) = @_;

    my $genome_db_str = $genome_db->toString;

    my $genome_db_id;
    if ($genome_db and ($genome_db =~ /^\d+$/)) {
        $genome_db_id = $genome_db;
        $genome_db = $compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    } else {
        assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');
        $genome_db_id = $genome_db->dbID;
        if (!$genome_db_id) {
            throw("[$genome_db] does not have a dbID");
        }
    }

    # first, delete all members
    my $gene_member_adaptor = $compara_dba->get_GeneMemberAdaptor;
    my $gene_members = $gene_member_adaptor->fetch_all_by_GenomeDB($genome_db);
    foreach my $gm ( @$gene_members ) {
        # automatically deletes seq_members and associated data too
        $gene_member_adaptor->delete($gm);
    }

    # delete all dnafrags
    $compara_dba->dbc->do('DELETE FROM dnafrag WHERE genome_db_id = ?', undef, $genome_db_id);

    # delete genome_db
    $compara_dba->dbc->do('DELETE FROM genome_db WHERE genome_db_id = ?', undef, $genome_db_id);

    print "Removed GenomeDB [$genome_db_str]\n";
}

1;
