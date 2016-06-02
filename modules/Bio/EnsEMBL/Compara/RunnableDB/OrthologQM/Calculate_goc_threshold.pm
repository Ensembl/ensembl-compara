=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

   Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold

=head1 SYNOPSIS

=head1 DESCRIPTION
use the genetic distance of a pair species to determine what the goc threshold should be. 

Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold -genetic_distance 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
    my $self = shift;
    return {
            %{ $self->SUPER::param_defaults() },
#		'mlss_id'	=>	'100021',
#		'compara_db' => 'mysql://ensro@compara4/OrthologQM_test_db',
#		'compara_db' => 'mysql://ensro@compara4/wa2_protein_trees_84'
    };
}



sub fetch_input {
	my $self = shift;
  my $dist = $self->param_required('genetic_distance');
	$self->param('dist', $dist);
}

sub run {
  my $self = shift;

  if ($self->param('dist') > 100) {
    $self->param('threshold', 50);
  }
  else {
    $self->param('threshold', 75); 
  }

}

sub write_output {
  	my $self = shift @_;
#    print $self->param('threshold');
    $self->dataflow_output_id( {'threshold' => $self->param('threshold')} , 1);
}

1;