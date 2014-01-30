=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on a
method_link_species_set_id, calculates the median dS where dS
values are available, and stores 2*median in the threshold_on_ds
tag of the current method_link_species_set

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS;

use strict;
use warnings;

use Statistics::Descriptive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;
    my $mlss_id = $self->param_required('mlss_id');

    my $stats = new Statistics::Descriptive::Full;

    my $sql = 'SELECT ds FROM homology WHERE method_link_species_set_id = ? AND ds IS NOT NULL';
    my $sth = $self->compara_dba->dbc->prepare($sql);

    $sth->execute($mlss_id);

    # Gets all the dS values and stores them in the stat object
    my $dS;
    $sth->bind_columns(\$dS);
    while ($sth->fetch) {
        $stats->add_data($dS);
    }
    $sth->finish;

    $self->param('stats', $stats);
}

sub run {
    my $self = shift @_;

    my $stats = $self->param('stats');
    my $mlss_id = $self->param('mlss_id');

    # Finds the right threshold from the median
    if ($stats->count) {
        my $median = $stats->median;
        print STDERR "method_link_species_set_id: $mlss_id; median: $median; 2\*median: ",2*$median;

        if($median >1.0) {
            print STDERR "  threshold exceeds 2.0 - to distant -> set to 2\n";
            $self->param('threshold', 2.0);
        } else {
            print STDERR "  threshold below 1.0 -> set to 1\n";
            $self->param('threshold', 1.0);
        }
    } else {
        $self->param('threshold', undef);
    }
    $self->param('stats', undef);
}


sub write_output {
    my $self = shift @_;

    # Updates the tag
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
    $mlss->store_tag('threshold_on_ds', $self->param('threshold'));
}


1;

