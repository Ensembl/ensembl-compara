=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use base ('Bio::EnsEMBL::Hive::Process');
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub write_output {
  my ($self) = @_;
  
  my $division = $self->param_required('division');
  my $mlss_id  = $self->param('mlss_id');
  my $reg = 'Bio::EnsEMBL::Registry';
  if( $self->param("reg_conf") ){
   $reg->load_all( $self->param("reg_conf") );
  } elsif ( $self->param("store_in_pipeline_db") ){
   my $pipe_db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( %{ $self->param('pipeline_db') });
  }
  my $mlssa = $reg->get_adaptor($division, 'compara', 'MethodLinkSpeciesSet');
  my @mlss = @{$mlssa->fetch_all_by_method_link_type("SYNTENY")};
  
  if (defined $mlss_id) {
    my %mlss = map {$_->dbID() => 1} @mlss;
    if (exists $mlss{$mlss_id}) {
      print "Output mlss_id = $mlss_id\n";
      $self->dataflow_output_id({'mlss_id' => $mlss_id}, 1);
    } else {
      $self->throw("The MLSS id parameter $mlss_id does not exist for $division.");
    }
  } else {
    foreach my $mlss (@mlss) {
      print "Output mlss_id = ".$mlss->dbID()."\n";
      $self->dataflow_output_id({'mlss_id' => $mlss->dbID()}, 1);
    }
  }
}

1;
