=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

=head1 DESCRIPTION

=head1 AUTHOR

ckong

=cut
package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) 	= @_;

    my $division          = $self->param_required('division')          || die "'division' is an obligatory parameter";
    my $method_link_types = $self->param_required('method_link_types') || die "'method_link_types' is an obligatory parameter";

    $self->param('division', $division);
    $self->param('method_link_types', $method_link_types);

return 0;
}

sub run {
    my ($self)  = @_;

return 0;
}

sub write_output {
    my ($self)  = @_;

    my $division          = $self->param('division');
    my $method_link_types = $self->param('method_link_types');

    # Get MethodLinkSpeciesSet adaptor:
    my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($division, 'compara', 'MethodLinkSpeciesSet');

    foreach my $ml_typ (@$method_link_types){
       # Get MethodLinkSpeciesSet Objects for required method_link_type
       my $mlss_listref = $mlssa->fetch_all_by_method_link_type($ml_typ);

my $count =0;
           
       foreach my $mlss (@$mlss_listref){ 
	  #next unless $count < 2;
          $count++;

          my $mlss_id     = $mlss->dbID();
	  my $ref_species = $mlss->get_value_for_tag('reference_species');

          warn("Reference species missing! Please check the 'reference species' tag in method_link_species_set_tag for mlss_id ".$mlss_id)if(!defined $ref_species);
          next unless (defined $ref_species);

	  $self->dataflow_output_id({'mlss_id' => $mlss_id, 'species' => $ref_species, 'method_link_type' => $ml_typ}, 2) if (defined $mlss_id);          
       }
   }
return 0;
}


1;


