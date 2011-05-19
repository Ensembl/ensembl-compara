# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::ExonsSpreadsheet;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    panel_exons       => 'on',
    panel_supporting  => 'on',
    sscon             => 25,
    seq_cols          => 60,
    flanking          => 50,
    fullseq           => 'no',
    oexon             => 'no',
    line_numbering    => 'off',
    variation         => 'off',
    population_filter => 'off',
    min_frequency     => 0.1
  });
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
    name   => 'seq_cols',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, name => "$_ bps" }} map $_*15, 2..8
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
  
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  
  $self->add_form_element($general_markup_options{'line_numbering'});
  
  if ($self->species_defs->databases->{'DATABASE_VARIATION'}) {
    $self->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'variation',
      label  => 'Show variation features',
      values => [
        { value => 'off',  name => 'No'            },
        { value => 'on',   name => 'Yes'           },
        { value => 'exon', name => 'In exons only' },
      ]
    });
    
    my $populations = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $self->add_form_element($general_markup_options{'pop_filter'});
      $self->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $_->set_flag($self->SELECT_ALL_FLAG) for @{$self->get_form->fieldsets};
}


1;
