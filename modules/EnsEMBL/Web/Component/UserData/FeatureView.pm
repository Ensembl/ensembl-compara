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

  my $form            = $self->new_form({'id' => 'select', 'class' => 'bgcolour', 'action' => {qw(type UserData action FviewRedirect __clear 1)}, 'method' => 'post'});
  my $add_track_link  = $hub->url({qw(type UserData action SelectFile __clear 1)});

  $form->add_notes({'id' => 'notes', 'heading' => 'Hint', 'text' => qq{
    <p>Using this form, you can select Ensembl features to display on a karyotype or single chromosome.</p>
    <p>If you want to use your own data file, please go to the <a href="$add_track_link" class="modal_link" rel="modal_user_data">Add custom track</a> page instead.</p>
  }});

  $form->add_field({
    'type'      => 'noedit',
    'label'     => 'Species',
    'no_input'  => 1,
    'is_html'   => 1,
    'value'     => $species_defs->species_label($current_species)  # Species is set automatically for the page you are on
  });
  $form->add_hidden({'name' => 'species', 'value' => $current_species});

  my @types = (
    {'value'  => 'Gene',                'caption' => 'Gene'},
    {'value'  => 'DnaAlignFeature',     'caption' => 'Sequence Feature'},
    {'value'  => 'ProteinAlignFeature', 'caption' => 'Protein Feature'},
  );
  ## Disabled owing to API issues
  ##  {'value' => 'OligoProbe',           'caption' => 'OligoProbe'},

  $form->add_field({
    'type'    => 'dropdown',
    'name'    => 'ftype',
    'label'   => 'Feature Type',
    'values'  => \@types
  });

  $form->add_field({
    'type'    => 'text',
    'name'    => 'id',
    'label'   => 'ID(s)',
    'notes'   => 'Hint: to display multiple features, enter them on separate lines or as a comma-delimited list'
  });

  ## Need to convert standard colours to hex colours for storing in ID file
  my @colours;
  my $colour_scheme = $hub->species_defs->ENSEMBL_STYLE || {};
  foreach my $colour (@{$species_defs->TRACK_COLOUR_ARRAY}) {
    next unless $colour_scheme->{'POINTER_'.uc($colour)};
    my $colourname = ucfirst($colour);
    $colourname =~ s/Dark/Dark /;
    my $hex = $colour_scheme->{'POINTER_'.uc($colour)};
    push @colours, {'caption' => $colourname, 'value' => $hex};
  }

  $form->add_field({
    'type'    => 'dropdown',
    'name'    => 'colour',
    'label'   => 'Colour',
    'values'  => \@colours,
    'select'  => 'select',
  });

  my @styles = (
    {'value'  => 'highlight_lharrow',   'caption' => 'Arrow on lefthand side'},
    {'value'  => 'highlight_rharrow',   'caption' => 'Arrow on righthand side'},
    {'value'  => 'highlight_bowtie',    'caption' => 'Arrows on both sides'},
    {'value'  => 'highlight_wideline',  'caption' => 'Line'},
    {'value'  => 'highlight_widebox',   'caption' => 'Box'}
  );
  $form->add_field({
    'type'    => 'dropdown',
    'name'    => 'style',
    'label'   => 'Pointer style',
    'values'  => \@styles
  });

  $form->add_button({
    'name'    => 'submit_button',
    'value'   => 'Show features',
    'class'   => 'submit'
  });
  
  return $form->render;
}

1;
