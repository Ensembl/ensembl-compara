=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
use warnings;

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs);

sub _new {
  ## @override
  ## TODO - get rid of the use of referer
  my $self = shift->SUPER::_new(@_);

  $self->{'is_compara_ortholog'}  = ($self->hub->referer->{'ENSEMBL_ACTION'} || '') eq 'Compara_Ortholog';
  $self->{'code'}                 = $self->type.'::'.$self->component unless $self->{'is_compara_ortholog'}; # TODO - really needed

  return $self;
}

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_default_options({
    'seq'         => 'Protein',
    'text_format' => 'clustalw',
  });
}

sub init_form {
  ## @override
  my $self    = shift;
  my $form    = $self->SUPER::init_form(@_);
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $form->get_fieldset('Select species')->remove unless $self->{'is_compara_ortholog'};

  $form->add_form_element({
    'fieldset'  => 'Aligment output',
    'type'      => 'dropdown',
    'name'      => 'seq',
    'label'     => 'View as cDNA or Protein',
    'values'    => [ qw(cDNA Protein) ]
  });

  $form->add_form_element({
    'fieldset'  => 'Aligment output',
    'type'      => 'dropdown',
    'name'      => 'text_format',
    'label'     => 'Output format for sequence alignment',
    'values'    => [ map {{ 'value' => $_, 'caption' => $formats{$_} }} sort keys %formats ]
  });

  return $form;
}

1;
