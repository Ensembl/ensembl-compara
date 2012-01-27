# $Id$

package EnsEMBL::Web::ViewConfig::Gene::GeneSeq;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    flank5_display => 600,
    flank3_display => 600,
    exon_display   => 'core',
    exon_ori       => 'all',
    snp_display    => 'off',
    line_numbering => 'off',
  });

  $self->title = 'Sequence';
  $self->SUPER::init;
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
  $self->variation_options({ populations => [ 'fetch_all_LD_Populations' ] }) if $dbs->{'DATABASE_VARIATION'};
  $self->add_form_element($general_markup_options{'line_numbering'});
}

1;
