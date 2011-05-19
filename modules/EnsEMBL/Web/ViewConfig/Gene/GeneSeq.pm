# $Id$

package EnsEMBL::Web::ViewConfig::Gene::GeneSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    flank5_display    => 600,
    flank3_display    => 600,
    display_width     => 60,
    exon_display      => 'core',
    exon_ori          => 'all',
    snp_display       => 'off',
    population_filter => 'off',
    min_frequency     => 0.1,
    line_numbering    => 'off',
  });
}

sub form {
  my $self                   = shift;
  my $dbs                    = $self->species_defs->databases;
  my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;
  
  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'vega',          name => 'Vega exons'     } if $dbs->{'DATABASE_VEGA'};
  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', name => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
  
  $self->add_form_element($gene_markup_options{'flank5_display'});
  $self->add_form_element($gene_markup_options{'flank3_display'});
  $self->add_form_element($other_markup_options{'display_width'});
  $self->add_form_element($gene_markup_options{'exon_display'});
  $self->add_form_element($general_markup_options{'exon_ori'});
  
  if ($dbs->{'DATABASE_VARIATION'}) {
    $self->add_form_element($general_markup_options{'snp_display'});
    
    my $populations = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $self->add_form_element($general_markup_options{'pop_filter'});
      $self->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $self->add_form_element($general_markup_options{'line_numbering'});
}

1;
