# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons       => 'yes',
    snp_display => 'off',
    number      => 'no'
  });

  $self->title = 'Protein Sequence';
  $self->SUPER::init;
}

sub form {
  my $self = shift;

  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'display_width',
    label  => 'Number of amino acids per row',
    values => [
      map {{ value => $_, name => "$_ aa" }} map 10*$_, 3..20
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'exons', select => 'select', label => 'Show exons' });
  $self->variation_options({ populations => [ 'fetch_all_HapMap_Populations', 'fetch_all_1KG_Populations' ], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
  $self->add_form_element({ type => 'YesNo', name => 'number', select => 'select', label => 'Number residues' });
}

1;
