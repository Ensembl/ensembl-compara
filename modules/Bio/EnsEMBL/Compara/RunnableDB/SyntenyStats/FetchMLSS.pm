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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::FetchMLSS

=head1 DESCRIPTION

Generate a set of synteny analyses on which to calculate statistics.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SyntenyStats::FetchMLSS;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
  my ($self) = @_;
  
  if( $self->param("registry") ){
   $self->load_registry($self->param("registry"));
  }
  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my @mlss = @{$mlssa->fetch_all_by_method_link_type("SYNTENY")};
  
    foreach my $mlss (@mlss) {
      print "Output mlss_id = ".$mlss->dbID()."\n";
      $self->dataflow_output_id({'mlss_id' => $mlss->dbID()}, 1);
    }
}

1;
