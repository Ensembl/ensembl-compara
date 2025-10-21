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

Bio::EnsEMBL::Compara::RunnableDB::Alignment::CodingExonLengthStats

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Alignment::CodingExonLengthStats;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::Stats qw(get_coding_exon_regions);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $method_types = $self->param_required('coding_exon_method_types');
    my $dnafrag_id = $self->param_required('dnafrag_id');

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $dnafrag_dba = $self->compara_dba->get_DnaFragAdaptor;

    my $dnafrag = $dnafrag_dba->fetch_by_dbID($dnafrag_id);
    my $genome_db = $dnafrag->genome_db;
    $self->param('genome_db', $genome_db);

    my @mlss_ids;
    foreach my $method_type (@{$method_types}) {
        my $mlsses_of_type = $mlss_dba->fetch_all_by_method_link_type_GenomeDB($method_type, $genome_db);
        foreach my $mlss (@{$mlsses_of_type}) {
            push(@mlss_ids, $mlss->dbID);
        }
    }
    $self->param('mlss_ids', \@mlss_ids);

    my $totals = { 'coding_exon_length' => 0 };
    $dnafrag->genome_db->db_adaptor->dbc->prevent_disconnect( sub {

        my $slice_dba = $dnafrag->genome_db->db_adaptor->get_SliceAdaptor();

        #Necessary to get unique bits of Y
        my $slices = $slice_dba->fetch_by_region_unique('toplevel', $dnafrag->name);
        die "No slices for dnafrag ".$dnafrag->name unless @$slices;

        foreach my $slice (@$slices) {
            my $slice_coding_exons = get_coding_exon_regions($slice);
            foreach my $coding_exon (@$slice_coding_exons) {
                my ($start, $end) = @$coding_exon;
                $totals->{'coding_exon_length'} += ($end - $start + 1);
            }
        }
    });

    $self->param('totals', $totals);
}


sub write_output {
    my $self = shift;

    my $mlss_ids = $self->param('mlss_ids');
    my $totals = $self->param('totals');

    my $sql = q/
        REPLACE INTO statistics
            (method_link_species_set_id, genome_db_id, dnafrag_id, coding_exon_length)
        VALUES
            (?,?,?,?)
    /;

    my $sth = $self->dbc->prepare($sql);
    foreach my $mlss_id (@{$mlss_ids}) {
        $sth->execute($mlss_id, $self->param('genome_db')->dbID, $self->param('dnafrag_id'), $totals->{'coding_exon_length'});
    }

    $sth->finish;
}


1;
