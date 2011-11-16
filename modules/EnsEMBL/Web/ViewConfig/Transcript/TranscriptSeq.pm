# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::TranscriptSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons             => 'yes',
    codons            => 'yes',
    utr               => 'yes',
    coding_seq        => 'yes',
    display_width     => 60,
    translation       => 'yes',
    rna               => 'no',
    variation         => 'yes',
    population_filter => 'off',
    min_frequency     => 0.1,
    number            => 'yes'
  });
  
  $self->title = 'cDNA sequence';
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
  
  if ($self->species_defs->databases->{'DATABASE_VARIATION'}) {
    $self->add_form_element({ type => 'YesNo', name => 'variation', select => 'select', label => 'Show variation features' });
    
    my $populations = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {
      my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $self->add_form_element($general_markup_options{'pop_filter'});
      $self->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $self->add_form_element({ type => 'YesNo', name => 'number', select => 'select', label => 'Number residues' });
}

1;
