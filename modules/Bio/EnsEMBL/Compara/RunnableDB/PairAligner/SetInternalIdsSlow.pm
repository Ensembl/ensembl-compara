=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsSlow

=head1 DESCRIPTION

This module rewrite the genomic_align(_block) entries so that the dbIDs are in the range of method_link_species_set_id * 10**10
It is a slower version of "SetInternalIdsCollection" because it copies and updates the rows one by one.

=head1 CONTACT

Post questions to the Ensembl development list: http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIdsSlow;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Iterator;

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

    my $magic_number = '1'.('0' x $self->param('mlss_padding_n_zeros'));

    my $sql_unavailable_gab_ids = "SELECT genomic_align_block_id FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number)  = method_link_species_set_id AND method_link_species_set_id = ? ORDER BY genomic_align_block_id";
    my $sql_fetch_gabs          = "SELECT *                      FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ? ORDER BY genomic_align_block_id";

    my $sql_unavailable_ga_ids = "SELECT genomic_align_id FROM genomic_align WHERE FLOOR(genomic_align_id / $magic_number)  = method_link_species_set_id AND method_link_species_set_id = ? ORDER BY genomic_align_id";
    my $sql_fetch_gas          = "SELECT genomic_align_id FROM genomic_align WHERE FLOOR(genomic_align_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ? ORDER BY genomic_align_id";

    # Update the dbIDs in genomic_align
    my $sql_update_ga_gab_id  = 'UPDATE genomic_align       SET genomic_align_block_id = ? WHERE genomic_align_block_id = ?';
    my $sql_update_ga_id      = 'UPDATE genomic_align       SET genomic_align_id = ?       WHERE genomic_align_id = ?';

    # Remove the old blocks
    my $sql3 = "DELETE FROM genomic_align_block WHERE FLOOR(genomic_align_block_id / $magic_number) != method_link_species_set_id AND method_link_species_set_id = ?";

    # We really need a transaction to ensure we're not screwing the database
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction(sub {
            my $unavailable_gab_ids = $dbc->sql_helper->execute_simple( -SQL => $sql_unavailable_gab_ids, -PARAMS => [$mlss_id], );
            my $gab_iter = $self->_make_dbID_iterator($unavailable_gab_ids, $mlss_id * $magic_number + 1);

            my $nd = 0;
            my $nm = 0;

            my $sth_fetch_gabs = $dbc->prepare($sql_fetch_gabs);
            $sth_fetch_gabs->execute($mlss_id);
            my $sth_update_ga_gab_id = $dbc->prepare($sql_update_ga_gab_id);
            while(my $row = $sth_fetch_gabs->fetch) {
                my $new_gab_id = $gab_iter->next();
                my @data = @$row;
                # Assumes genomic_align_block_id is the first column
                $data[0] = $new_gab_id;
                #print "GAB ", $row->[0], " -> ", $new_gab_id, "\n";
                $dbc->do(sprintf('INSERT INTO genomic_align_block VALUES (%s)', join(',', map {'?'} @data)), undef, @data);
                $nd++;
                $nm += $sth_update_ga_gab_id->execute($new_gab_id, $row->[0]);
            }
            $sth_update_ga_gab_id->finish();
            $sth_fetch_gabs->finish();
            print STDERR "$nd rows duplicated in genomic_align_block\n";
            print STDERR "$nm rows of genomic_align redirected to the new entries in genomic_align_block \n";
            print STDERR (my $nr = $dbc->do($sql3, undef, $mlss_id)), " rows removed from genomic_align_block\n";

            my $unavailable_ga_ids = $dbc->sql_helper->execute_simple( -SQL => $sql_unavailable_ga_ids, -PARAMS => [$mlss_id], );
            my $ga_iter = $self->_make_dbID_iterator($unavailable_ga_ids, $mlss_id * $magic_number + 1);

            my $na = 0;

            my $sth_fetch_gas = $dbc->prepare($sql_fetch_gas);
            $sth_fetch_gas->execute($mlss_id);
            my $sth_update_ga_id = $dbc->prepare($sql_update_ga_id);
            while(my $row = $sth_fetch_gas->fetch) {
                my $new_ga_id = $ga_iter->next();
                #print "GA ", $row->[0], " -> ", $new_ga_id, "\n";
                $sth_update_ga_id->execute($new_ga_id, $row->[0]);
                $na++;
            }
            $sth_update_ga_id->finish();
            $sth_fetch_gas->finish();
            print STDERR "$na rows adjusted in genomic_align\n";
        }
    );
}

# Returns an iterator that generates auto-incrementing dbIDs starting from
# $start_dbID but avoiding $unavailable_dbIDs
sub _make_dbID_iterator {
    my ($self, $unavailable_dbIDs, $start_dbID) = @_; 

    # Remove out of range values
    while (scalar(@$unavailable_dbIDs) and ($start_dbID > $unavailable_dbIDs->[0])) {
        shift @$unavailable_dbIDs;
    }

    # We could bypass the Bio::EnsEMBL::Utils::Iterator interface and
    # return the sub directly
    return Bio::EnsEMBL::Utils::Iterator->new( sub {
            while (scalar(@$unavailable_dbIDs) and ($start_dbID == $unavailable_dbIDs->[0])) {
                $start_dbID++;
                shift @$unavailable_dbIDs;
            }   
            return $start_dbID++;
        } );
}

1;
