package EnsEMBL::Web::ViewConfig::LRG::Sequence;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    flank5_display 600
    flank3_display 600
    display_width  60
    exon_display   core
    exon_ori       all
    snp_display    off
    line_numbering off
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
  foreach my $o (@{$gene_markup_options{'exon_display'}{'values'}}) {
      if ($o->{value} eq 'core') {
	  $o->{name} = 'Core and LRG exons';
      }
  }

  push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', name => 'EST gene exons' } if $dbs->{'DATABASE_OTHERFEATURES'};
  
  $view_config->add_form_element($gene_markup_options{'flank5_display'});
  $view_config->add_form_element($gene_markup_options{'flank3_display'});
  $view_config->add_form_element($other_markup_options{'display_width'});
  $view_config->add_form_element($gene_markup_options{'exon_display'});
  $view_config->add_form_element($general_markup_options{'exon_ori'});
  $view_config->add_form_element($general_markup_options{'snp_display'}) if $dbs->{'DATABASE_VARIATION'};
  $view_config->add_form_element($general_markup_options{'line_numbering'});
}

1;
