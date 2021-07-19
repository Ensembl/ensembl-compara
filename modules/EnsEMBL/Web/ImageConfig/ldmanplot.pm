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

package EnsEMBL::Web::ImageConfig::ldmanplot;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub _menus {
  return (qw(
    transcript
    simple
    misc_feature
    prediction
    variation
    somatic
    ld_population
    other
    information
  ));
}

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  my $colours = $self->species_defs->colour('variation');

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    label_width     => 100,
    colours         => $colours,  # colour maps
  });

  $self->create_menus($self->_menus);

  $self->load_tracks;

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar'                             }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
  );

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );

  $self->modify_configs(
    ['simple', 'misc_feature'],
    { display => 'off', menu => 'no'}
  );

  $self->modify_configs(
    ['simple_otherfeatures_human_1kg_hapmap_phase_2'],
    {'display' => 'tiling', menu => 'yes'}
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal',  strand => 'r' }
  );
}

sub init_slice {
  my ($self, $parameters) = @_;

  $self->set_parameters({
    %$parameters,
    _userdatatype_ID   => 30,
    _transcript_names_ => 'yes'
  });
}

sub add_populations {
  my ($self, $pops) = @_;

  my @pop_tracks = ();

  my $colours = $self->get_parameter('colours');
  my $var_name = ($self->hub->param('v')) ? 'variant '.$self->hub->param('v') : 'focus variant';

  my $r2_html = 'r&sup2;';
  my $r2_tag  = 'r<sup>2</sup>'; # Use tag for the track description because of wrong interpretation of the $r2_html
  my $height  = 100;

  my $display_options = qq{You can change the region size by clicking on the link "Display options" in the "Configure this page/image" popup.};
  my $desc = 'Linkage disequilibrium data (%s score) for the %s in the %s population. %s';

  foreach my $pop_name (sort { $a cmp $b } @$pops) {
    my $pop = $pop_name;
       $pop =~ s/ /_/g;
    my $pop_caption = $pop_name;
       $pop_caption =~ s/1000GENOMES:phase_3:/1KG - /;

    # r2
    my $r2_desc = sprintf($desc, $r2_tag, $var_name, $pop_name, $display_options);
    push @pop_tracks, [ "ld_r2_$pop", '', 'ld_manplot', {
      display      => 'compact',
      strand       => 'r',
      labelcaption => "LD ($r2_html) - $pop_caption",
      caption      => "LD ($r2_html) - $pop_name",
      name         => "LD ($r2_tag) - $pop_name",
      key          => 'r2',
      description  => $r2_desc,
      pop_name     => $pop_name,
      colours      => $colours,
      height       => $height
    }];
    # D prime
    my $d_prime_desc   = sprintf($desc, 'D prime', $var_name, $pop_name, $display_options);
    my $d_prime_prefix = "LD (D') - ";
    push @pop_tracks, [ "ld_d_prime_$pop", '', 'ld_manplot', {
      display      => 'compact',
      strand       => 'r',
      labelcaption => "$d_prime_prefix$pop_caption",
      caption      => "$d_prime_prefix$pop_name",
      name         => "$d_prime_prefix$pop_name",
      key          => 'd_prime',
      description  => $d_prime_desc,
      pop_name     => $pop_name,
      colours      => $colours,
      height       => $height
    }];
  }

  $self->add_tracks('ld_population', @pop_tracks);
}

1;

