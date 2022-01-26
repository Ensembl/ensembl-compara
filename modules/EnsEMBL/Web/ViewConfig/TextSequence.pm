=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::TextSequence;

## Parent class for text sequence based views

use strict;
use warnings;

use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::Utils::Config;
use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self = shift;

  $self->set_default_options({
    'display_width'       => 60,
    'population_filter'   => 'off',
    'min_frequency'       => 0.1,
    'consequence_filter'  => 'off',
    'evidence_filter'     => 'off',
    'title_display'       => 'off',
    'hide_long_snps'      => 'on',
    'hide_rare_snps'      => 'off',
    hidden_sources        => [],
  });
}

sub variation_fields {
  ## Extra fields for form if variation db is present
  ## @return List of ordered field keys
  return $_[0]->species_defs->databases->{'DATABASE_VARIATION'} ? qw(snp_display hide_long_snps hide_rare_snps consequence_filter evidence_filter hidden_sources) : ();
}

sub source_list {
  my ($self) = @_;

  my $srca = $self->hub->database('variation')->get_SourceAdaptor;
  return map { $_->name => $_->name } @{$srca->fetch_all};
}

sub get_markup_options {
  ## Gets the form element hashrefs for sequence markup options
  ## @param Hashref with following keys
  ##  - no_snp_link         : Flag if on will not show 'Show variation links' option
  ##  - snp_display_opts    : Extra options for snp_display element
  ##  - snp_display_label   : Display label for snp_display field (defaults to 'Show variants')
  ##  - no_consequence      : Flag if on will not add consequence_filter field
  ##  - vega_exon           : Flag if on will include vega exons in exon display dropdown
  ##  - otherfeatures_exon  : Flag if on will include EST gene exons in exon display dropdown
  ## @return Arrayref of hashrefs as expected by Form->add_element method
  my ($self, $options) = @_;
  my $markup  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $dbs     = $self->species_defs->databases;

  # Add variation markup options if variation db is present
  if ($dbs->{'DATABASE_VARIATION'}) {

    $markup->{'snp_display'} = {
      'name'  => 'snp_display',
      'label' => $options->{'snp_display_label'} || 'Show variants',
    };

    my @snp_values;

    push @snp_values, { 'value' => 'snp_link', 'caption' => 'Yes and show links' } unless $options->{'no_snp_link'};
    push @snp_values, @{$options->{'snp_display_opts'} || []};

    if (@snp_values) {
      unshift @snp_values, { 'value' => 'off', 'caption' => 'No'  }, { 'value' => 'on', 'caption' => 'Yes' };

      $markup->{'snp_display'}{'type'}    = 'Dropdown';
      $markup->{'snp_display'}{'values'}  = \@snp_values;

    } else {
      $markup->{'snp_display'}{'type'}  = 'Checkbox';
      $markup->{'snp_display'}{'value'} = 'on';
      ## Hack for removing "show with links" option without turning SNPs off (e.g. in export)
      my $values = $self->field_values;
      $markup->{'snp_display'}{'checked'} = 'checked' if $values->{'snp_display'} eq 'snp_link';
    }

    unless($options->{'no_consequence'}) {
      my %consequence_types = map { $_->label && $_->feature_class =~ /transcript/i ? ($_->label => $_->SO_term) : () } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
      push @{$markup->{'consequence_filter'}{'values'}}, map { 'value' => $consequence_types{$_}, 'caption' => $_ }, sort keys %consequence_types;
    }

    my %attribs = %Bio::EnsEMBL::Variation::Utils::Config::ATTRIBS;
    push @{$markup->{'evidence_filter'}{'values'}}, map { 'value' => $_, 'caption' => $_ }, sort @{$attribs{'evidence'}};

    my %sources = $self->source_list;
    push @{$markup->{'hidden_sources'}{'values'}}, map { value => $sources{$_}, caption => "Hide $_" }, sort keys %sources;
  }

  # add vega exon and EST gene exon dropdown options if required
  push @{$markup->{'exon_display'}{'values'}}, { 'value' => 'vega',           'caption' => 'Vega exons'     } if $options->{'vega_exon'} && $dbs->{'DATABASE_VEGA'};
  push @{$markup->{'exon_display'}{'values'}}, { 'value' => 'otherfeatures',  'caption' => 'EST gene exons' } if $options->{'otherfeatures_exon'} && $dbs->{'DATABASE_OTHERFEATURES'};

  # Delete hide_rare_snp markup if MAF unavailable
  delete $markup->{'hide_rare_snps'} if (!$self->species_defs->get_config($self->species, 'MAF_AVAILABLE'));

  return $markup;
}

#
# DON'T USE THIS METHOD IN NEW CODE.
# Still used in tools plugin
#
sub variation_options {
### Older version - used by a couple of views that haven't been ported to new export interface
  my ($self, $options) = @_;
  my $hub    = $self->hub;
  my %markup = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;

  $markup{'snp_display'}{'label'} = $options->{'label'} if $options->{'label'};

  push @{$markup{'snp_display'}{'values'}}, { value => 'snp_link', caption => 'Yes and show links' } unless $options->{'snp_link'} eq 'no';
  push @{$markup{'snp_display'}{'values'}}, @{$options->{'snp_display'}} if $options->{'snp_display'};

  $self->add_form_element($markup{'snp_display'});
  $self->add_form_element($markup{'hide_long_snps'});
  $self->add_form_element($markup{'hide_rare_snps'}) if ($self->species_defs->get_config($self->species, 'MAF_AVAILABLE'));

  if ($options->{'consequence'} ne 'no') {
    my %consequence_types = map { $_->label && $_->feature_class =~ /transcript/i ? ($_->label => $_->SO_term) : () } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;

    push @{$markup{'consequence_filter'}{'values'}}, map { value => $consequence_types{$_}, caption => $_ }, sort keys %consequence_types;

    $self->add_form_element($markup{'consequence_filter'});
  }

  # Population filtered variants currently fail to return in a reasonable time
#  if ($options->{'populations'}) {
#    my $pop_adaptor = $hub->get_adaptor('get_PopulationAdaptor', 'variation');
#    my @populations = map @{$pop_adaptor->$_}, @{$options->{'populations'}};
#
#    if (scalar @populations) {
#      push @{$markup{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, caption => $_->name }} @populations;
#
#      $self->add_form_element($markup{'pop_filter'});
#      $self->add_form_element($markup{'pop_min_freq'});
#    }
#  }
}

1;
