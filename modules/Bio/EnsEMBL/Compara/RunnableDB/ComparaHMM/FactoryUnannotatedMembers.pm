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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers

=head1 SYNOPSIS


=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for the next analysis
Supported keys:

   'step' => <number>
       How many sequences to write into each job. Default 100

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FactoryUnannotatedMembers;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'step'  => 100,
    };
}

sub fetch_input {
    my ($self) = @_;

    my $unannotated_member_ids;
    if($self->param('use_diversity_filter')){
        $unannotated_member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_under_the_diversity_levels();
    }
    else{
        $unannotated_member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot();
    }

    $self->param('unannotated_member_ids', [sort {$a <=> $b} @$unannotated_member_ids]);

}



sub write_output {
    my $self = shift @_;

    my $step = $self->param('step');
    my @member_id_list = @{$self->param('unannotated_member_ids')};

    while (@member_id_list) {
        my @job_array = splice(@member_id_list, 0, $step);
        my $output_id = {'start_member_id' => $job_array[0], 'end_member_id' => $job_array[-1]};
        $self->dataflow_output_id($output_id, 2);
    }
}

1;
