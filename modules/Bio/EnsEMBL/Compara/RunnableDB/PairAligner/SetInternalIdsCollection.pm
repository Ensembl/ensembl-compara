=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection

=head1 DESCRIPTION

This module rewrite the genomic_align(_block) entries so that the dbIDs are in the range of method_link_species_set_id * 10**10

=head1 CONTACT

Post questions to the Ensembl development list: http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsCollection;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::SqlHelper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    $self->param_required('method_link_species_set_id');
}



sub run {
    my $self = shift;

    return if ($self->param('skip'));

    $self->_setInternalIds();
}



#Makes the internal ids unique
sub _setInternalIds {
    my $self = shift;

    my $mlss_id = $self->param('method_link_species_set_id');
    my $gdbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
    if (scalar(@$gdbs) <= 2) {
        $self->warning('AUTO_INCREMENT should have been set earlier by "set_internal_ids". Nothing to do now');
    }


    # Write new blocks in the correct range
    my $sql1 = 'INSERT INTO genomic_align_block SELECT (method_link_species_set_id*10000000000 + (genomic_align_block_id % 10000000000)), method_link_species_set_id, score , perc_id, length , group_id , level_id FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / 10000000000) != method_link_species_set_id AND method_link_species_set_id = ?';
    # Update the dbIDs in genomic_align
    my $sql2 = 'UPDATE genomic_align SET genomic_align_block_id = (method_link_species_set_id*10000000000 + (genomic_align_block_id % 10000000000)), genomic_align_id = (method_link_species_set_id*10000000000 + (genomic_align_id % 10000000000)) WHERE (FLOOR(genomic_align_block_id / 10000000000) != method_link_species_set_id OR FLOOR(genomic_align_id / 10000000000) != method_link_species_set_id) AND method_link_species_set_id = ?';
    # Remove the old blocks
    my $sql3 = 'DELETE FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / 10000000000) != method_link_species_set_id AND method_link_species_set_id = ?';

    # We really need a transaction to ensure we're not screwing the database
    my $dbc = $self->compara_dba->dbc;
    my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $dbc);
    $helper->transaction( -CALLBACK => sub {
            $dbc->do($sql1, undef, $mlss_id);
            $dbc->do($sql2, undef, $mlss_id);
            $dbc->do($sql3, undef, $mlss_id);
        }
    );
}

1;
