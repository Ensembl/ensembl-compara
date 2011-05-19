# $Id$

package EnsEMBL::Web::ViewConfig::Gene::HomologAlignment;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs);

sub init {
  my $self = shift;
  
  $self->SUPER::init if $self->hub->referer->{'ENSEMBL_ACTION'} eq 'Compara_Ortholog';
  
  $self->set_defaults({
    seq         => 'Protein',
    text_format => 'clustalw',
  });
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
  
  $self->SUPER::form if $self->hub->referer->{'ENSEMBL_ACTION'} eq 'Compara_Ortholog';;
}

1;
