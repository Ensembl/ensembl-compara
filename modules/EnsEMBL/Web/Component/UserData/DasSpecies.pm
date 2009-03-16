package EnsEMBL::Web::Component::UserData::DasSpecies;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Filter::DAS;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Choose a species';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Catch any errors at the server end
  my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$object});
  my $sources = $filter->catch($object->param('dsn'));

  my $url = '/'.$object->data_species.'/UserData/';
  if ($filter->error_code) {
    $form = $self->modal_form('select_das', $url.'DasSources', {'wizard' => 1});
    $object->param->('filter_module', 'DAS');
    $object->param->('filter_code', $filter->error_code);
  }
  else {

    my $form = $self->modal_form('select_species', $url.'DasCoords', {'wizard' => 1});
    my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
    $form->add_notes( {'heading' => 'Info', 'text' => "$sitename is not able to automatically configure one or more DAS sources. Please select the species' the sources below have data for. If they contain data for all species' (e.g. gene or protein-based sources) choose 'None species-specific'. If the sources do not use the same coordinate system, go back and add them individually."} );

    my @values = map {
      { 'name' => $_, 'value' => $_, }
      } @{ $self->object->species_defs->ENSEMBL_SPECIES };
    unshift @values, { 'name' => 'Not species-specific', 'value' => 'NONE' };

    $form->add_element('name'   => 'species',
                     'label'  => 'Species',
                     'type'   => 'MultiSelect',
                     'select' => 1,
                     'value'  => [$self->object->species_defs->ENSEMBL_PRIMARY_SPECIES], # default species
                     'values' => \@values);

    $form->add_element( 'type' => 'SubHeader',   'value' => 'DAS Sources' );
    my @coord_unknown = grep { !scalar @{$_->coord_systems} } @{ $sources };
    $self->output_das_text(@coord_unknown);
  }
  return $form->render;
}

1;
