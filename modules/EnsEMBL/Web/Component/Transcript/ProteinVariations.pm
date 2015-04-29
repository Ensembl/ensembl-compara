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

package EnsEMBL::Web::Component::Transcript::ProteinVariations;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  return $self->non_coding_error unless $object->translation_object;

  my $hub         = $self->hub;
  my $var_styles  = $self->hub->species_defs->colour('variation');
  my $colourmap   = $self->hub->colourmap;
  my $glossary    = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub)->fetch_glossary_lookup;
  my $show_scores = $hub->param('show_scores');
  my @data;
  
  foreach my $snp (@{$object->variation_data}) {
    #next unless $snp->{'allele'};
    
    my $codons = $snp->{'codons'} || '-';
    
    if ($codons ne '-') {
      if (length($codons)>8) {
        $codons =~ s/([ACGT])/<b>$1<\/b>/g;
        $codons =~ tr/acgt/ACGT/;
        $codons = $self->trim_large_string($codons,'codons_'.$snp->{'snp_id'},8);
      }
      else {
        $codons =~ s/([ACGT])/<b>$1<\/b>/g;
         $codons =~ tr/acgt/ACGT/;
      }
    }
    my $allele = $snp->{'allele'};
    my $tva    = $snp->{'tva'};
    my $var_allele = $tva->variation_feature_seq;
    
    # Evidence status
    my $evidence = $snp->{'vf'}->get_all_evidence_values || [];
    my $status = join("",
                   map {
                     sprintf('<img src="/i/val/evidence_%s.png" class="_ht" title="%s"/><span class="hidden export">%s,</span>', $_, $_, $_)
                   } @$evidence
                 );

    # Check allele size (for display issues)
    if (length($allele)>10) {
      $allele = $self->trim_large_allele_string($allele,'allele_'.$snp->{'snp_id'},10);
    }
    $allele =~ s/$var_allele/<b>$var_allele<\/b>/ if $allele =~ /\//;
    
    # consequence type
    my $type = $self->render_consequence_type($tva);    
    
    push @data, {
      res    => $snp->{'position'},
      id     => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Variation', action => 'Summary', v => $snp->{'snp_id'}, vf => $snp->{'vdbid'}, vdb => 'variation' }), $snp->{'snp_id'}),
      type   => $type,
      status => $status,
      allele => $allele,
      ambig  => $snp->{'ambigcode'} || '-',
      alt    => $snp->{'pep_snp'} || '-',
      codons => $codons,
      sift   => $self->render_sift_polyphen($tva->sift_prediction, $tva->sift_score),
      poly   => $self->render_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score),
    };
  } 
   
  my $columns = [
    { key => 'res',    title => 'Residue',      width => '8%',  sort => 'numeric',       help => 'Residue number on the protein sequence'                     },
    { key => 'id',     title => 'Variation ID', width => '10%', sort => 'html',          help => 'Variant identifier'                                         }, 
    { key => 'type',   title => 'Type',         width => '20%', sort => 'position_html', help => 'Consequence type'                                           }, 
    { key => 'status', title => 'Evidence',     width => '10%', sort => 'string',        help =>  $self->strip_HTML($glossary->{'Evidence status (variant)'}) },
    { key => 'allele', title => 'Alleles',      width => '10%', sort => 'string',        help => 'Alternative nucleotides'                                    },
    { key => 'ambig',  title => 'Ambig. code',  width => '8%',  sort => 'string',        help => 'IUPAC nucleotide ambiguity code'                            },
    { key => 'alt',    title => 'Residues',     width => '10%', sort => 'string',        help => 'Resulting amino acid(s)'                                    },
    { key => 'codons', title => 'Codons',       width => '10%', sort => 'string',        help => 'Resulting codon(s), with the allele(s) displayed in bold'   },
  ];
 
  # add SIFT for supported species
  if ( $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'SIFT'}){
    push @$columns, ({ key => 'sift', title => 'SIFT', width => '8%', align => 'center', sort => 'position_html', $self->strip_HTML($glossary->{'SIFT'}) });
  }
  if ($hub->species =~ /homo_sapiens/i) {
    push @$columns, ({ key => 'poly', title => 'PolyPhen', width => '8%', align => 'center', sort => 'position_html', $self->strip_HTML($glossary->{'PolyPhen'}) });
  }
  
  return $self->new_table($columns, \@data, { data_table => 1, sorting => [ 'res asc' ], class => 'cellwrap_inside fast_fixed_table' })->render;
}

1;

