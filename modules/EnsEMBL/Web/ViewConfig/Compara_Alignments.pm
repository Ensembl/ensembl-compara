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

package EnsEMBL::Web::ViewConfig::Compara_Alignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init_cacheable {
  ## @override
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my $alignments   = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};
  my %defaults;

  foreach my $key (grep { $alignments->{$_}{'class'} !~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$key}{'species'}}) {
      my @name = split '_', $alignments->{$key}{'name'};
      my $n    = shift @name;
      $defaults{lc "species_${key}_$_"} = [ join(' ', $n, map(lc, @name), '-', $species_defs->get_config($_, 'SPECIES_COMMON_NAME') || 'Ancestral sequences'), /ancestral/ ? 'off' : 'yes' ];
    }
  }

  $self->SUPER::init_cacheable;

  $self->set_default_options({
    'flank5_display'        => 600,
    'flank3_display'        => 600,
    'exon_display'          => 'core',
    'exon_ori'              => 'all',
    'snp_display'           => 'off',
    'line_numbering'        => 'off',
    'display_width'         => 120,
    'conservation_display'  => 'off',
    'region_change_display' => 'off',
    'codons_display'        => 'off',
    %defaults
  });

  $self->title('Alignments');
}

sub init_form_non_cacheable {
  ## @override
  ## Adding species specific fieldsets for configuring species within an alignment (TODO - get rid of referer)
  my $self          = shift;
  my $hub           = $self->hub;
  my $form          = $self->SUPER::init_form_non_cacheable(@_);
  my $referer       = $hub->referer;
  my $species       = $referer->{'ENSEMBL_SPECIES'};
  my $species_defs  = $self->species_defs;
  my $alignments    = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};

  # Only show if the alignment has been selected in the dropdown and !align="" in url
  # Order by number of species (name is in the form "6 primates EPO"
  if(grep $_ ne '', @{$referer->{'params'}{'align'} || []}) {
    foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}{$species} && $_->{'id'} eq @{$referer->{'params'}{'align'}}[0]} values %$alignments) {
      my $sp            = $row->{'species'};
      my @name          = split '_', $row->{'name'};
      my $n             = shift @name;
      $sp->{$_}         = $species_defs->species_label($species_defs->production_name_mapping($_)) for keys %$sp;
      my $fieldset_name = join ' ', $n, map lc, @name;

      foreach (sort { ($sp->{$a} =~ /^<.*?>(.+)/ ? $1 : $sp->{$a}) cmp ($sp->{$b} =~ /^<.*?>(.+)/ ? $1 : $sp->{$b}) } keys %$sp) {
        $self->add_form_element({
          'fieldset'  => $fieldset_name,
          'type'      => 'CheckBox',
          'label'     => $sp->{$_},
          'name'      => sprintf('species_%s_%s', $row->{'id'}, lc $_),
          'value'     => 'yes',
        });
      }
    }
  }
}

sub field_order {
  ## Abstract method implementation
  return
    qw(flank5_display flank3_display display_width exon_display exon_ori),
    $_[0]->variation_fields,
    qw(line_numbering codons_display conservation_display region_change_display title_options);
}

sub form_fields {
  ## Abstract method implementation
  my $self    = shift;
  my $dbs     = $self->species_defs->databases;
  my $markup  = $self->get_markup_options({'vega_exon' => 1, 'otherfeatures_exon' => 1});
  my $fields  = {};

  $markup->{'conservation_display'} = {
    'name'  => 'conservation_display',
    'label' => 'Show conservation regions',
    'type'  => 'Checkbox',
    'value' => 'on',
  };

  $markup->{'region_change_display'} = {
    'name'  => 'region_change_display',
    'label' => 'Mark alignment start/end',
    'type'  => 'Checkbox',
    'value' => 'on',
  };

  $fields->{$_} = $markup->{$_} for $self->field_order;

  return $fields;
}

1;
