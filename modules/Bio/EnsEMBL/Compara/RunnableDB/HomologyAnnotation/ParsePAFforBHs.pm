=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::ParsePAFforBHs

=head1 DESCRIPTION

Parses peptide_align_feature table for RBBH (and BBH if there are no RBBHs)
then stores analysis results as homologies in homology_table.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::ParsePAFforBHs;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
    my $self = shift;

    my $query_gdb_id   = $self->param_required('genome_db_id');
    my $hit_gdb_id     = $self->param_required('target_genome_db_id');
    my $seq_member_ids = $self->param('member_id_list');

    my $paf_adaptor    = $self->compara_dba->get_PeptideAlignFeatureAdaptor;
    my $ref_db         = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param_required('rr_ref_db'));
    my $ref_mem_adap   = $ref_db->get_SeqMemberAdaptor;
    my $query_mem_adap = $self->compara_dba->get_SeqMemberAdaptor;

    # MLSS will not exist for hit_gdb: it is a reference and belongs to a different db
    my $mlss = $self->_create_superficial_mlss($self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($query_gdb_id), $ref_db->get_GenomeDBAdaptor->fetch_by_dbID($hit_gdb_id));

    foreach my $member ( @$seq_member_ids ) {
        # rbbh search for each member first
        my $bbh;
        my $rbh = $paf_adaptor->fetch_BRH_by_member_genomedb($member, $hit_gdb_id);
        foreach my $rbh_entry (@$rbh) {
            $rbh_entry->{_hit_member} = $ref_mem_adap->fetch_by_dbID($rbh_entry->hit_member_id);
            print Dumper $rbh_entry if $self->debug;
            $self->call_within_transaction( sub {
                $self->compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 0");
                $self->_write_homologies($mlss, $rbh_entry, 'homolog_rbbh');
                $self->compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 1");
            }, 1, 1 );
        }
        # if no rbbh a bbh will have to do
        if ( ! scalar @$rbh ) {
            $bbh = $paf_adaptor->fetch_BBH_by_member_genomedb($member, $hit_gdb_id);
            foreach my $bbh_entry (@$bbh) {
                $bbh_entry->{_hit_member} = $ref_mem_adap->fetch_by_dbID($bbh_entry->hit_member_id);
                print Dumper $bbh_entry if $self->debug;
                $self->call_within_transaction( sub {
                    $self->compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 0");
                    $self->_write_homologies($mlss, $bbh_entry, 'homolog_bbh');
                    $self->compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 1");
                }, 1, 1 );
            }

            if ( ! scalar @$bbh ) {
                $self->warning( "For genome_db_id: " . $query_gdb_id . " seq_member_id: " . $member . " there are no reciprocal/best blast hits with genome_db_id " . $hit_gdb_id );
            }
        }
    }
}

sub _write_homologies {
    my ($self, $mlss, $paf, $type) = @_;

    # Conversion of PAFs to Homology objects
    my $homology_adap = $self->compara_dba->get_HomologyAdaptor;
    my $homology      = $paf->create_homology($type, $mlss);
    my $dbid          = $paf->query_member->gene_member_id . $paf->hit_member->gene_member_id;

    $homology_adap->store($homology);

}

sub _create_superficial_mlss {
    my ($self, $gdb1, $gdb2) = @_;

    my $mlss_adap    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $method_adap  = $self->compara_dba->get_MethodAdaptor;
    my $species_adap = $self->compara_dba->get_SpeciesSetAdaptor;
    my $method       = $method_adap->fetch_by_type('ENSEMBL_HOMOLOGUES');
    my $species_set  = $species_adap->fetch_by_GenomeDBs([$gdb1, $gdb2]);

    unless ($method) {
        $method = Bio::EnsEMBL::Compara::Method->new(
            -dbID            => 204,
            -type            => 'ENSEMBL_HOMOLOGUES',
            -class           => 'Homology.homology',
            -display_name    => 'Homologues',
            -adaptor         => $method_adap,
        );
        $method_adap->store($method);
    }
    unless ($species_set) {
        $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
            -genome_dbs => [$gdb1, $gdb2]
        );
        $species_adap->store($species_set);
    }
    my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -adaptor             => $mlss_adap,
        -method              => $method,
        -species_set         => $species_set,
    );
    $mlss_adap->store($method_link_species_set);
    return $method_link_species_set;
}

1;
