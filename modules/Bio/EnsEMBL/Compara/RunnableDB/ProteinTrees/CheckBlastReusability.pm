=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckBlastReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of ProteinTrees pipeline

The format of the input_id follows the format of a Perl hash reference.
Example:
    { 'genome_db_id' => 90 }

supported keys:
    'genome_db_id'  => <number>
        the id of the genome to be checked (main input_id parameter)

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession).

    'reuse_this'    => <0|1>
        (optional) if defined, the code is skipped and this value is passed to the output

    'do_not_reuse_list' => <list_of_species_ids_or_names>
        (optional)  is a 'veto' list of species we definitely do not want to be reused this time

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckBlastReusability;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability');



sub fetch_input {
    my $self = shift @_;

    my $genome_db_adaptor   = $self->compara_dba->get_GenomeDBAdaptor;
    $genome_db_adaptor->_id_cache->clear_cache();

    my $genome_db_id = $self->param('genome_db_id');
    my $genome_db    = $genome_db_adaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with genome_db_id='$genome_db_id'";
    my $species_name = $genome_db->name();

    # For polyploid genomes, the reusability is only assessed on the principal genome
    if ($genome_db->genome_component) {
        # -1 means that we haven't checked the species
        $self->param('reuse_this', -1);
        return;

    # But in fact, we can't assess the reusability of a polyploid genomes
    # that comes from files. This is because we would have to read the
    # files of the components, which shouldn't be done in this module (this
    # module only deals with *1* genome at a time)
    } elsif ($genome_db->is_polyploid) {
        $self->param('reuse_this', 0);
        return;
    }

    return if(defined($self->param('reuse_this')));  # bypass fetch_input() and run() in case 'reuse_this' has already been passed


    my $do_not_reuse_list = $self->param('do_not_reuse_list') || [];
    foreach my $do_not_reuse_candidate (@$do_not_reuse_list) {
        if( looks_like_number( $do_not_reuse_candidate ) ) {

            if( $do_not_reuse_candidate == $genome_db_id ) {
                $self->param('reuse_this', 0);
                return;
            }

        } else {    # not using registry names here to avoid clashes with previous release registry entries:

            if( $do_not_reuse_candidate eq $genome_db->name ) {
                $self->param('reuse_this', 0);
                return;
            }
        }
    }

    if(my $reuse_db = $self->param('reuse_db')) {

            # Need to check that the genome_db_id has not changed (treat the opposite as a signal not to reuse) :
        my $reuse_compara_dba       = $self->get_cached_compara_dba('reuse_db');    # may die if bad parameters
        my $reuse_genome_db_adaptor = $reuse_compara_dba->get_GenomeDBAdaptor();
        my $reuse_genome_db = $reuse_genome_db_adaptor->fetch_by_name_assembly($species_name, $genome_db->assembly);
        if (not $reuse_genome_db) {
            $self->warning("Could not fetch genome_db object for name='$species_name' and assembly='".$genome_db->assembly."' from reuse_db");
            $self->param('reuse_this', 0);
            return;
        }
        my $reuse_genome_db_id = $reuse_genome_db->dbID();

        if ($reuse_genome_db_id != $genome_db_id) {
            $self->warning("Genome_db_ids for '$species_name' ($reuse_genome_db_id -> $genome_db_id) do not match, so cannot reuse");
            $self->param('reuse_this', 0);
            return;
        }

        $self->param('reuse_dba', $reuse_compara_dba);

    } else {
        $self->warning("reuse_db hash has not been set, so cannot reuse");
        $self->param('reuse_this', 0);
        return;
    }
}


sub run {
    my $self = shift @_;

    return if(defined($self->param('reuse_this')));  # bypass run() in case 'reuse_this' has either been passed or already computed

    my $prev_hash = $self->hash_all_canonical_members( $self->param('reuse_dba')->dbc );
    my $curr_hash = $self->hash_all_canonical_members( $self->compara_dba->dbc );
    my ($removed, $remained1) = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability::check_hash_equals($prev_hash, $curr_hash);
    my ($added, $remained2)   = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability::check_hash_equals($curr_hash, $prev_hash);

    my $coding_objects_differ = $added || $removed;
    if($coding_objects_differ) {
        $self->warning("The coding objects changed: $added hash keys were added and $removed were removed");
    }

    $self->param('reuse_this', $coding_objects_differ ? 0 : 1);
}


# ------------------------- non-interface subroutines -----------------------------------

sub hash_all_canonical_members {
    my ($self, $compara_dbc) = @_;

    my $sql = qq{
        SELECT CONCAT_WS(':', gm.gene_member_id, gm.stable_id, gd.name, gm.dnafrag_start, gm.dnafrag_end, gm.dnafrag_strand, sm.seq_member_id, sm.stable_id, sd.name, sm.dnafrag_start, sm.dnafrag_end, sm.dnafrag_strand, s.md5sum)
          FROM (gene_member gm JOIN dnafrag gd USING (dnafrag_id)) JOIN (seq_member sm JOIN dnafrag sd USING (dnafrag_id) JOIN sequence s USING (sequence_id)) ON seq_member_id=canonical_member_id
         WHERE gm.genome_db_id = ? AND biotype_group = "coding";
    };

    my %member_set = ();

    my $sth = $compara_dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'));

    while(my ($key) = $sth->fetchrow()) {
        $member_set{$key} = 1;
    }

    return \%member_set;
}


1;
