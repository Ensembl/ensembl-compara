package EnsEMBL::Web::TextSequence::Legend::GeneSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Legend);

sub extra_keys {
  my ($self, $config) = @_;

  my $exon_type;
  $exon_type = $config->{'exon_display'} unless $config->{'exon_display'} eq 'selected';
  $exon_type = 'All' if !$exon_type || $exon_type eq 'core';
  $exon_type = ucfirst $exon_type;

  return {
    exons => {
      gene    => { class => 'eg', text => "$config->{'gene_name'} $config->{'gene_exon_type'}" },
      other   => { class => 'eo', text => "$exon_type exons in this region" },
      compara => { class => 'e2', text => "$exon_type exons in this region" }
    }
  };
}

1;
