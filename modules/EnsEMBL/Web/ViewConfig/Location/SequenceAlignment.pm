package EnsEMBL::Web::ViewConfig::Location::SequenceAlignment;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my $view_config = shift;
  
  my $sp         = $view_config->species;
  my $variations = $view_config->species_defs->databases->{'DATABASE_VARIATION'}||{};
  my $ref        = $variations->{'REFERENCE_STRAIN'};
  
  $view_config->_set_defaults(qw(
    display_width   120
    exon_ori        all
    match_display   dot
    snp_display     snp
    line_numbering  sequence
    codons_display  off
    title_display   off
    strand          1
  ));
  
  $view_config->_set_defaults($_, 'yes') for grep $_ ne $ref, @{$variations->{'DEFAULT_STRAINS'}||[]};
  $view_config->_set_defaults($_, 'no')  for grep $_ ne $ref, @{$variations->{'DISPLAY_STRAINS'}||[]};
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $sp         = $view_config->species;
  my $variations = $view_config->species_defs->databases->{'DATABASE_VARIATION'} || {};
  my $strains    = $object->species_defs->translate('strain');
  my $ref        = $variations->{'REFERENCE_STRAIN'};
  
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # shared with compara_markup and marked-up sequence
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;   # shared with compara_markup
  
  push @{$general_markup_options{'exon_ori'}{'values'}}, { value => 'off' , name => 'None' };
  $general_markup_options{'exon_ori'}{'label'} = 'Exons to highlight';
  
  $view_config->add_form_element($other_markup_options{'display_width'});
  $view_config->add_form_element($other_markup_options{'strand'});
  $view_config->add_form_element($general_markup_options{'exon_ori'});

  $view_config->add_form_element({
    type     => 'DropDown', 
    select   => 'select',   
    name     => 'match_display',
    label    => 'Matching basepairs',
    values   => [
      { value => 'off', name => 'Show all' },
      { value => 'dot', name => 'Replace matching bp with dots' }
    ]
  });
  
  $view_config->add_form_element($general_markup_options{'snp_display'}) if $object->species_defs->databases->{'DATABASE_VARIATION'};
  $view_config->add_form_element($general_markup_options{'line_numbering'});
  $view_config->add_form_element($other_markup_options{'codons_display'});
  $view_config->add_form_element($other_markup_options{'title_display'});
  
  $view_config->add_form_element({
    type  => 'NoEdit',
    name  => 'reference_individual',
    label => "Reference $strains",
    value => $ref
  });
  
  $strains .= 's';

  $view_config->add_fieldset("Resequenced $strains");

  foreach (@{$variations->{'DEFAULT_STRAINS'}||[]}, @{$variations->{'DISPLAY_STRAINS'}||[]}) {
    next if $_ eq $ref;
    
    $view_config->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => $_,
      value => 'yes', 
      raw   => 1
    });
  }
}

1;
