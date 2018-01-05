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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'mlss_padding_n_zeros' => 10.
    }
}

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
#    my $gdbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
#    if (scalar(@$gdbs) <= 2) {
#        $self->warning('AUTO_INCREMENT should have been set earlier by "set_internal_ids". Nothing to do now');
#    }

    my $magic_number = '1'.('0' x $self->param('mlss_padding_n_zeros'));

    # Write new blocks in the correct range
    my $sql0 = "SELECT MIN(genomic_align_id % $magic_number), MIN(genomic_align_block_id % $magic_number) FROM genomic_align WHERE (FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id OR FLOOR(genomic_align_id / $magic_number) != method_link_species_set_id) AND method_link_species_set_id = ?";
    my $sql1 = "INSERT INTO genomic_align_block SELECT (genomic_align_block_id % $magic_number) + ?, method_link_species_set_id, score , perc_id, length , group_id , level_id FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";
    # Update the dbIDs in genomic_align
    my $sql2 = "UPDATE genomic_align SET genomic_align_block_id = ? + (genomic_align_block_id % $magic_number), genomic_align_id = ? + (genomic_align_id % $magic_number) WHERE (FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id OR FLOOR(genomic_align_id / $magic_number) != method_link_species_set_id) AND method_link_species_set_id = ?";
    # Remove the old blocks
    my $sql3 = "DELETE FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";

    # We really need a transaction to ensure we're not screwing the database
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction(sub {
            my ($min_ga, $min_gab) = $dbc->db_handle->selectrow_array($sql0, undef, $mlss_id);
            if (not defined $min_ga) {
                $self->warning("Entries for mlss_id=$mlss_id are already in the correct range. Nothing to do");
                return;
            };
            my $offset_ga = $mlss_id * $magic_number + 1 - $min_ga;
            my $offset_gab = $mlss_id * $magic_number + 1 - $min_gab;
            print STDERR "Offsets: genomic_align_block_id=$offset_gab genomic_align_id=$offset_ga\n";
            print STDERR (my $nd = $dbc->do($sql1, undef, $offset_gab, $mlss_id)), " rows duplicated in genomic_align_block\n";
            print STDERR $dbc->do($sql2, undef, $offset_gab, $offset_ga, $mlss_id), " rows of genomic_align redirected to the new entries in genomic_align_block \n";
            print STDERR (my $nr = $dbc->do($sql3, undef, $mlss_id)), " rows removed from genomic_align_block\n";
            die "Numbers mismatch: $nd rows duplicated and $nr removed\n" if $nd != $nr;
        }
    );
}

1;
