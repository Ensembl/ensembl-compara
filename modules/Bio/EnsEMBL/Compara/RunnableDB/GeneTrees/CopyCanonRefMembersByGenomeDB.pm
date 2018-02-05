=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a $rows = copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB

=head1 DESCRIPTION

This module imports all the members (and their sequences and hmm-hits) that are canonical
and on a reference dnafrag for a given genome_db_id.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyCanonRefMembersByGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::CopyMembersByGenomeDB');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults()},

        'biotype_filter'    => '',
    }
}


sub run {
    my $self = shift;

    #Creates a hash of the tables to be excluded from the copy.
    if ( defined $self->param('exclude_tables') ) {
        my %exclude_tables = map { $_ => 1 } @{ $self->param('exclude_tables') };
        $self->param( 'exclude_tables', \%exclude_tables );
    }

    $self->_copy_data_wrapper_join('dnafrag');
    $self->_copy_data_wrapper_join('gene_member');
    $self->_copy_data_wrapper_join('sequence', 'sequence USING (sequence_id)');
    $self->_copy_data_wrapper_join('seq_member');
    $self->_copy_data_wrapper_join('other_member_sequence', 'other_member_sequence USING (seq_member_id)');
    $self->_copy_data_wrapper_join('exon_boundaries', 'exon_boundaries USING (seq_member_id)');
    $self->_copy_data_wrapper_join('hmm_annot', 'hmm_annot USING (seq_member_id)');
    $self->_copy_data_wrapper_join('seq_member_projection_stable_id', 'seq_member_projection_stable_id ON seq_member_id = target_seq_member_id');
}


sub _copy_data_wrapper_join {
    my ($self, $table, $extra_join) = @_;

    #If the parameter exclude_tables is defined in the pipeline configuration, the tables defined there will be excluded from the copy.
    return if ((defined $self->param('exclude_tables')) and exists( $self->param('exclude_tables')->{$table} ));

    my $biotype_filter  = $self->param('biotype_filter');

    my $input_query     = 'SELECT ' . $table . '.* FROM gene_member JOIN dnafrag USING (dnafrag_id) JOIN seq_member ON canonical_member_id = seq_member_id'
                          . ($extra_join ? ' JOIN '.$extra_join : '')
                          . ' WHERE is_reference = 1 AND has_translation_edits = 0'
                          . ($biotype_filter ? ' AND '.$biotype_filter : '');

    $self->_copy_data_wrapper($table, $input_query, 'gene_member.');
}


1;
