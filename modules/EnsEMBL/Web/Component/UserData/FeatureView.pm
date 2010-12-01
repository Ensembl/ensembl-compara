# $Id$

package EnsEMBL::Web::Component::UserData::FeatureView;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Select Features to Display';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $sitename        = $species_defs->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $html;

  my $form = new EnsEMBL::Web::Form('select', $hub->species_path($current_species).'/UserData/FviewRedirect', 'post', 'std check');

  $form->add_notes({'id' => 'notes', 'heading' => 'Hint', 'text' => qq{
Using this form, you can select Ensembl features to display on a karyotype (formerly known as FeatureView).
  }});

  ## Species is set automatically for the page you are on
  my @species;
  foreach my $sp ($species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $species_defs->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );

  my @types = (
    {'value' => 'Gene',                 'name' => 'Gene'},
    {'value' => 'DnaAlignFeature',      'name' => 'Sequence Feature'},
    {'value' => 'ProteinAlignFeature',  'name' => 'Protein Feature'},
  );
  ## Disabled owing to API issues
  ##  {'value' => 'OligoProbe',           'name' => 'OligoProbe'},

  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'ftype',
      'label'   => 'Feature Type',
      'values'  => \@types,
      'select'  => 'select',
  );

  $form->add_element( type => 'Text', name => 'id', label => 'ID(s)', 'notes' => 'Hint: to display multiple features, enter them as a comma-delimited list' );

  my @colours;
  foreach my $colour (@{$species_defs->TRACK_COLOUR_ARRAY}) {
    my $colourname = ucfirst($colour);
    $colourname =~ s/Dark/Dark /;
    push @colours, {'name' => ucfirst($colourname), 'value' => $colour};
  }
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'colour',
      'label'   => 'Colour',
      'values'  => \@colours,
      'select'  => 'select',
  );

  my @styles = (
    {'value' => 'rharrow',   'name' => 'Arrow on lefthand side'},
    {'value' => 'lharrow',   'name' => 'Arrow on righthand side'},
    {'value' => 'bowtie',    'name' => 'Arrows on both sides'},
    {'value' => 'wideline',  'name' => 'Line'},
    {'value' => 'widebox',   'name' => 'Box'},
  );
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'style',
      'label'   => 'Pointer style',
      'values'  => \@styles,
      'select'  => 'select',
  );

  $form->add_button('type' => 'Submit', 'name' => 'submit', 'value' => 'Show features', 'classes' => ['submit', 'modal_close']);
  $form->add_element('type' => 'ForceReload');

  $html .= $form->render;
  
  return $html;
}

1;
