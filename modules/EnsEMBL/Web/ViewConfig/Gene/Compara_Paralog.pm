# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Compara_Paralog;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->_set_defaults(qw(
    image_width 800
    width       800
    seq         Protein
    text_format clustalw
    scale       150
  ));
  
  $self->storable = 1;
}

sub form {
  my $self    = shift;
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  $self->add_fieldset('Aligment output');
  
  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',   
    name   => 'seq',
    label  => 'View as cDNA or Protein',
    values => [ map {{ value => $_, name => $_ }} qw(cDNA Protein) ]
  });

  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',   
    name   => 'text_format',
    label  => 'Output format for sequence alignment',
    values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
  });
}

1;
