=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ZMenu::Transcript::LRG;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $transcript  = $object->Obj;
  my $translation = $transcript->translation;

  my $lrg_gene  = $transcript->get_Gene;
  my $lrg_tr    = $transcript->stable_id;
  my @hgnc_xrefs  = grep {$_->dbname =~ /hgnc/i} @{$lrg_gene->get_all_DBEntries()}; # Retrieve the HGNC Xref

  my $hgnc_symbol = (scalar(@hgnc_xrefs)) ? $hgnc_xrefs[0]->display_id : undef;
  my $hgnc = ($hgnc_symbol) ? qq{ ($hgnc_symbol)} : '';

  my $lrg_id = $lrg_gene->stable_id;
  $self->caption("LRG $lrg_id$hgnc");

  my $external_urls = $hub->species_defs->ENSEMBL_EXTERNAL_URLS;
  (my $href         = $external_urls->{'LRG'}) =~ s/###ID###/$lrg_id/;


  my %url_params = (
    type   => 'LRG',
    lrg    => $lrg_id
  );

  $self->add_entry({
    type  => 'Gene type',
    label => $object->gene_stat_and_biotype
  });

  if ($hgnc_symbol) {
    $self->add_entry({
      type       => 'HGNC symbol',
      label_html => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Gene', action => 'Summary', lrg => $lrg_id, lrgt => $lrg_tr, g => $hgnc_symbol}), $hgnc_symbol),
    });
  }

  $self->add_entry({
    type       => 'Gene',
    label_html => sprintf('<a href="%s">%s</a>', $hub->url({ %url_params, action => 'Summary', lrgt => $lrg_tr }), $lrg_id)
  });

  $self->add_entry({
    type       => 'Transcript',
    label_html => sprintf('<a href="%s">%s</a>', $hub->url({ %url_params, action => 'Sequence_cDNA', lrgt => $lrg_tr }), $transcript->external_name)
  });

  if ($translation) {
    $self->add_entry({
      type       => 'Protein',
      label_html => sprintf('<a href="%s">%s</a>', $hub->url({ %url_params, action => 'ProteinSummary', lrgt => $lrg_tr }), $translation->display_id),
    });
  }

  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

  $self->add_entry({
    type  => 'Base pairs',
    label => $self->thousandify($transcript->seq->length)
  });

  if ($translation) {
    $self->add_entry({
      type  => 'Amino acids',
      label => $self->thousandify($translation->length)
    });
  }

  $self->add_entry({
    label_html => sprintf(qq{<a rel="external" href="%s">%s</a>},$href,$object->analysis->description)
  });
}

1;
