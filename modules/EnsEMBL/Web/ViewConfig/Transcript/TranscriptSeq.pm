# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::TranscriptSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons       => 'yes',
    codons      => 'yes',
    utr         => 'yes',
    coding_seq  => 'yes',
    translation => 'yes',
    rna         => 'no',
    snp_display => 'yes',
    number      => 'yes'
  });
  
  $self->title = 'cDNA sequence';
  $self->SUPER::init;
}

sub form {
  my $self = shift;

  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'display_width',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, name => "$_ bps" }} map $_*15, 2..12
    ] 
  });

  $self->add_form_element({ type => 'YesNo', name => 'exons',       select => 'select', label => 'Show exons'            });
  $self->add_form_element({ type => 'YesNo', name => 'codons',      select => 'select', label => 'Show codons'           });
  $self->add_form_element({ type => 'YesNo', name => 'utr',         select => 'select', label => 'Show UTR'              });
  $self->add_form_element({ type => 'YesNo', name => 'coding_seq',  select => 'select', label => 'Show coding sequence'  });
  $self->add_form_element({ type => 'YesNo', name => 'translation', select => 'select', label => 'Show protein sequence' });
  $self->add_form_element({ type => 'YesNo', name => 'rna',         select => 'select', label => 'Show RNA features'     });
  $self->variation_options({ populations => [ 'fetch_all_HapMap_Populations', 'fetch_all_1KG_Populations' ], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
  $self->add_form_element({ type => 'YesNo', name => 'number', select => 'select', label => 'Number residues' });
}

1;
