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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Calculate_goc_threshold

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


sub fetch_input {
	my $self = shift;
  my $dist = $self->param_required('genetic_distance');
	$self->param('dist', $dist);

  print " START OF Calculate_goc_threshold-------------- goc_threshold -----------------------\n\n  ", $self->param('goc_mlss_id'), " <-----  goc_mlss_id\n" if ($self->debug);
}

sub run {
  my $self = shift;

  if ($self->param('dist') > 100) {
    $self->param('goc_threshold', 50);
  }
  else {
    $self->param('goc_threshold', 75); 
  }

}

sub write_output {
  	my $self = shift @_;
    print $self->param('threshold') if ( $self->debug >3 );
    $self->dataflow_output_id( {'goc_threshold' => $self->param('goc_threshold')} , 1);
}

1;