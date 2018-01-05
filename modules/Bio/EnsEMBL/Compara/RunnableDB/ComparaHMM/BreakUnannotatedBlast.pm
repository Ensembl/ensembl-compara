
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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BreakUnannotatedBlast

=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run ncbi_blastp and parse the output into
PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara database
Supported keys:

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BreakUnannotatedBlast;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
            %{$self->SUPER::param_defaults},
    };
}

sub run{
    my ($self) = @_;
    my $members_list    = $self->param_required('member_id_list');
    my $param_index     = $self->param_required('param_index');

    foreach my $member (@$members_list) {
        $self->dataflow_output_id({"member_id_list" => [$member], "param_index" => $param_index}, 2);
    }
}

1;
