=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig);

sub _new {
  ## @override
  my $self = shift->SUPER::_new(@_);

  $self->{'code'} = 'Gene::HomologAlignment';

  return $self;
}

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;
  my $hub = $self->hub;
  foreach ($self->species_defs->valid_species) {
    # complicated if statement which shows/hides strain or main species depending on the view you are (i.e. when you are on a main species, do not show strain species and when you are on a strain species or strain view from main species, show only strain species)          
    next if (
            ($hub->action !~ /Strain_/ && $hub->is_strain($_)) || 
            (($hub->action =~ /Strain_/  || $hub->is_strain) && !$self->hub->species_defs->get_config($_, 'RELATED_TAXON'))
            );
    $self->set_default_options({ 'species_' . lc($_) => 'yes' });    
  }

  $self->title('Homologs');
}

sub field_order { } # no default fields
sub form_fields { } # no default fields

sub init_form {
  ## @override
  ## Fields are added according to species
  my $self  = shift;
  my $form  = $self->SUPER::init_form(@_);

  $form->add_species_fieldset;

  return $form;
}

1;
