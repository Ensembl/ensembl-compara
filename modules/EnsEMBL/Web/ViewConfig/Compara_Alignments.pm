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

package EnsEMBL::Web::ViewConfig::Compara_Alignments;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
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
  
  $self->SUPER::init;
  
  $self->set_defaults({
    flank5_display        => 600,
    flank3_display        => 600,
    exon_display          => 'core',
    exon_ori              => 'all',
    snp_display           => 'off',
    line_numbering        => 'off',
    display_width         => 120,
    conservation_display  => 'off',
    region_change_display => 'off',
    codons_display        => 'off',
    %defaults
  });
  
  $self->code  = $self->type . '::Compara_Alignments';
  $self->title = 'Alignments';
}

sub form {
### Override base class, because alignments have multiple configuration screens
  my $self = shift;
  my $fields = $self->form_fields;

  foreach ($self->field_order) {
    $self->add_form_element($fields->{$_});
  }
  ## Extra fieldsets for configuring species within an alignment (omitted from export)
  $self->alignment_options; 
}

sub field_order {
  my $self = shift;
  my $dbs   = $self->species_defs->databases;
  my @order;
  if (!$self->{'species_only'}) {
    if (!$self->{'no_flanking'}) {
      push @order, qw(flank5_display flank3_display);
    }
    push @order, qw(display_width);
    push @order, qw(strand) if $self->{'strand_option'};
    push @order, qw(exon_display exon_ori);
    push @order, $self->variation_fields if $dbs->{'DATABASE_VARIATION'};
    push @order, qw(line_numbering codons_display conservation_display region_change_display title_options);
  }
  return @order;
}

sub form_fields {
  my $self = shift;
  my $dbs  = $self->species_defs->databases;
  my $fields = {};
  
  if (!$self->{'species_only'}) {
    my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;

    push @{$markup_options->{'exon_display'}{'values'}}, { value => 'vega',          caption => 'Vega exons'     } if $dbs->{'DATABASE_VEGA'};
    push @{$markup_options->{'exon_display'}{'values'}}, { value => 'otherfeatures', caption => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
    
    $self->add_variation_options($markup_options) if $dbs->{'DATABASE_VARIATION'};
    
    $markup_options->{'conservation_display'} = {
                                                  name  => 'conservation_display',
                                                  label => 'Show conservation regions',
                                                  type  => 'Checkbox',
                                                  value => 'on',
                                                  };
    $markup_options->{'region_change_display'} = {
                                                  name  => 'region_change_display',
                                                  label => 'Mark alignment start/end',
                                                  type  => 'Checkbox',
                                                  value => 'on',
                                                  };
  
    foreach ($self->field_order) {
      $fields->{$_} = $markup_options->{$_};
      $fields->{$_}{'value'} = $self->get($_);
    }
  }

  return $fields;
}

sub alignment_options {
  my $self         = shift;
  my $species      = $self->hub->referer->{'ENSEMBL_SPECIES'};
  my $species_defs = $self->species_defs;
  my $alignments   = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};
  
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    my $sp   = $row->{'species'};
    my @name = split '_', $row->{'name'};
    my $n    = shift @name;
    
    $sp->{$_} = $species_defs->species_label($_) for keys %$sp;
    
    $self->add_fieldset(join ' ', $n, map lc, @name);
    
    foreach (sort { ($sp->{$a} =~ /^<.*?>(.+)/ ? $1 : $sp->{$a}) cmp ($sp->{$b} =~ /^<.*?>(.+)/ ? $1 : $sp->{$b}) } keys %$sp) {
      $self->add_form_element({
        type  => 'CheckBox', 
        label => $sp->{$_},
        name  => sprintf('species_%s_%s', $row->{'id'}, lc),
        value => 'yes',
        raw   => 1
      });
    }
  }
}

1;
