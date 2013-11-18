# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ExonsSpreadsheet;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;

  $self->set_defaults({
    panel_exons      => 'on',
    panel_supporting => 'on',
    sscon            => 25,
    flanking         => 50,
    fullseq          => 'no',
    oexon            => 'no',
    line_numbering   => 'off',
    snp_display      => 'off',
  });

  $self->title = 'Exons';
  $self->SUPER::init;
}

sub form {
  my $self = shift;
    
  $self->add_form_element({
    type  => 'NonNegInt',
    label => 'Flanking sequence at either end of transcript',
    name  => 'flanking'
  });
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'display_width',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, caption => "$_ bps" }} map $_*15, 2..8
    ]
  });
  
  $self->add_form_element({
    type  => 'NonNegInt',
    label => 'Intron base pairs to show at splice sites', 
    name  => 'sscon'
  });
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Show full intronic sequence',
    name  => 'fullseq',
    value => 'yes'
  });
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Show exons only',
    name  => 'oexon',
    value => 'yes'
  });
  
  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'line_numbering',
    label  => 'Line numbering',
    values => [
      { value => 'gene',  caption => 'Relative to the gene'            },
      { value => 'cdna',  caption => 'Relative to the cDNA'            },
      { value => 'cds',   caption => 'Relative to the coding sequence' },
      { value => 'slice', caption => 'Relative to coordinate systems'  },
      { value => 'off',   caption => 'None'                            },
    ]
  });
  
  $self->variation_options({ populations => [ 'fetch_all_LD_Populations' ], snp_display => [{ value => 'exon', caption => 'In exons only' }], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
  
  $_->set_flag($self->SELECT_ALL_FLAG) for @{$self->get_form->fieldsets};
}


1;
