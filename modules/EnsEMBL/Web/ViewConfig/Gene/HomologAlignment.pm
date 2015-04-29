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

package EnsEMBL::Web::ViewConfig::Gene::HomologAlignment;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs);

sub init {
  my $self = shift;
  
  $self->SUPER::init if $self->hub->referer->{'ENSEMBL_ACTION'} eq 'Compara_Ortholog';
  
  $self->set_defaults({
    seq         => 'Protein',
    text_format => 'clustalw',
  });

  $self->title = 'Homologs';
}

sub form {
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $self->add_fieldset('Aligment output');
  
  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',     
    name   => 'seq',
    label  => 'View as cDNA or Protein',
    values => [ map {{ value => $_, caption => $_ }} qw(cDNA Protein) ]
  });
  
  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',      
    name   => 'text_format',
    label  => 'Output format for sequence alignment',
    values => [ map {{ value => $_, caption => $formats{$_} }} sort keys %formats ]
  });
  
  $self->SUPER::form if $self->hub->referer->{'ENSEMBL_ACTION'} eq 'Compara_Ortholog';;
}

1;
