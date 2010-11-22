package EnsEMBL::Web::ViewConfig::Gene::Sequence;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    flank5_display    600
    flank3_display    600
    display_width     60
    exon_display      core
    exon_ori          all
    snp_display       off
    population_filter off
    min_frequency     0.1
    line_numbering    off
  ));
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $dbs                    = $object->species_defs->databases;
  my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;
  
  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'vega', name => 'Vega exons' } if $dbs->{'DATABASE_VEGA'};
  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', name => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
  
  $view_config->add_form_element($gene_markup_options{'flank5_display'});
  $view_config->add_form_element($gene_markup_options{'flank3_display'});
  $view_config->add_form_element($other_markup_options{'display_width'});
  $view_config->add_form_element($gene_markup_options{'exon_display'});
  $view_config->add_form_element($general_markup_options{'exon_ori'});
  
  if ($dbs->{'DATABASE_VARIATION'}) {
    $view_config->add_form_element($general_markup_options{'snp_display'});
    
    my $populations = $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_all_LD_Populations;
    
    if (scalar @$populations) {      
      push @{$general_markup_options{'pop_filter'}{'values'}}, sort { $a->{'name'} cmp $b->{'name'} } map {{ value => $_->name, name => $_->name }} @$populations;
    
      $view_config->add_form_element($general_markup_options{'pop_filter'});
      $view_config->add_form_element($general_markup_options{'pop_min_freq'});
    }
  }
  
  $view_config->add_form_element($general_markup_options{'line_numbering'});
}

1;
