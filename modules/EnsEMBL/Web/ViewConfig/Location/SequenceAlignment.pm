# $Id$

package EnsEMBL::Web::ViewConfig::Location::SequenceAlignment;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $sp         = $self->species;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'}||{};
  my $ref        = $variations->{'REFERENCE_STRAIN'};
  my %strains;
  
  $strains{$_} = 'yes' for grep $_ ne $ref, @{$variations->{'DEFAULT_STRAINS'} || []};
  $strains{$_} = 'no'  for grep $_ ne $ref, @{$variations->{'DISPLAY_STRAINS'} || []};
  
  $self->set_defaults({
    display_width  => 120,
    exon_ori       => 'all',
    match_display  => 'dot',
    snp_display    => 'snp',
    line_numbering => 'sequence',
    codons_display => 'off',
    title_display  => 'off',
    strand         => 1,
    %strains
  });
}

sub form {
  my $self       = shift;
  my $sp         = $self->species;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'} || {};
  my $strains    = $self->species_defs->translate('strain');
  my $ref        = $variations->{'REFERENCE_STRAIN'};
  
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # shared with compara_markup and marked-up sequence
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;   # shared with compara_markup
  
  push @{$general_markup_options{'exon_ori'}{'values'}}, { value => 'off', name => 'None' };
  $general_markup_options{'exon_ori'}{'label'} = 'Exons to highlight';
  
  $self->add_form_element($other_markup_options{'display_width'});
  $self->add_form_element($other_markup_options{'strand'});
  $self->add_form_element($general_markup_options{'exon_ori'});

  $self->add_form_element({
    type     => 'DropDown', 
    select   => 'select',   
    name     => 'match_display',
    label    => 'Matching basepairs',
    values   => [
      { value => 'off', name => 'Show all' },
      { value => 'dot', name => 'Replace matching bp with dots' }
    ]
  });
  
  $self->add_form_element($general_markup_options{'snp_display'}) if $variations;
  $self->add_form_element($general_markup_options{'line_numbering'});
  $self->add_form_element($other_markup_options{'codons_display'});
  $self->add_form_element($other_markup_options{'title_display'});
  
  $self->add_form_element({
    type  => 'NoEdit',
    name  => 'reference_individual',
    label => "Reference $strains",
    value => $ref
  });
  
  $strains .= 's';

  $self->add_fieldset("Resequenced $strains");

  foreach (@{$variations->{'DEFAULT_STRAINS'} || []}, @{$variations->{'DISPLAY_STRAINS'} || []}) {
    next if $_ eq $ref;
    
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => $_,
      value => 'yes', 
      raw   => 1
    });
  }
}

1;
