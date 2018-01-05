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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory 

=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported keys:
   'genome_db_id' => <number>
       Genome_db id. Obligatory

   'step' => <number>
       How many sequences to write into the blast query file. Default 1000



=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'step'  => 1000,
    };
}


sub write_output {
    my $self = shift @_;


    #Fetch members for genome_db_id
    my $sql = 'SELECT seq_member_id FROM seq_member WHERE genome_db_id = ? ORDER BY seq_member_id';
    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute($self->param_required('genome_db_id'));
    
    my $seq_member_id_list;
    while( my ($seq_member_id) = $sth->fetchrow() ) {
	push @$seq_member_id_list, $seq_member_id;
    }

    my $step = $self->param('step');

    while (@$seq_member_id_list) {
        my @job_array = splice(@$seq_member_id_list, 0, $step);
        my $output_id = {'genome_db_id' => $self->param('genome_db_id'), 'start_member_id' => $job_array[0], 'end_member_id' => $job_array[-1] };
        $self->dataflow_output_id($output_id, 2);
    }

}
return 1;
