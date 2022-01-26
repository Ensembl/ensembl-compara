=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::ConsequenceTable;

### This module outputs a table of consequences for the variation documentation pages 

use strict;

use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use parent qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;

  my $impact_def = $self->hub->glossary_lookup->{'IMPACT'};
  my $impact_title = sprintf('<span class="ht _ht"><span class="_ht_tip hidden">%s</span>IMPACT</span>',  encode_entities($impact_def));

  ## Create table
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'colour',  title => '*', width => '1%', align => 'center', sort => 'none' },
      { key => 'term',    title => 'SO term', width => '14%', align => 'left', sort => 'string' },
      { key => 'desc',    title => 'SO description', width => '50%', align => 'left', sort => 'string' },
      { key => 'acc',     title => 'SO accession', width => '10%', align => 'left', sort => 'html' },
      { key => 'd_term',  title => 'Display term', width => '15%', align => 'left', sort => 'string' },
      { key => 'impact',  title => 'IMPACT', width => '10%', align => 'left', sort => 'string' },
  ], [], {'id' => 'consequence_type_table'});

  my $data = [
    { 
      'term'    => 'transcript_ablation', 
      'colour'  => 'ff0000', 
      'desc'    => 'A feature ablation whereby the deleted region includes a transcript feature', 
      'acc'     => '0001893', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'splice_acceptor_variant', 
      'colour'  => 'FF581A', 
      'desc'    => "A splice variant that changes the 2 base region at the 3' end of an intron", 
      'acc'     => '0001574', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'splice_donor_variant', 
      'colour'  => 'FF581A', 
      'desc'    => "A splice variant that changes the 2 base region at the 5' end of an intron", 
      'acc'     => '0001575', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'stop_gained', 
      'colour'  => 'ff0000', 
      'desc'    => 'A sequence variant whereby at least one base of a codon is changed, resulting in a premature stop codon, leading to a shortened transcript', 
      'acc'     => '0001587', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'frameshift_variant', 
      'colour'  => '9400D3', 
      'desc'    => 'A sequence variant which causes a disruption of the translational reading frame, because the number of nucleotides inserted or deleted is not a multiple of three', 
      'acc'     => '0001589', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'stop_lost', 
      'colour'  => 'ff0000', 
      'desc'    => 'A sequence variant where at least one base of the terminator codon (stop) is changed, resulting in an elongated transcript', 
      'acc'     => '0001578', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'start_lost', 
      'colour'  => 'ffd700', 
      'desc'    => 'A codon variant that changes at least one base of the canonical start codon',
      'acc'     => '0002012', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'transcript_amplification', 
      'colour'  => 'ff69b4', 
      'desc'    => 'A feature amplification of a region containing a transcript', 
      'acc'     => '0001889', 
      'impact'  => 'HIGH',
    },
    {
      'term'    => 'inframe_insertion', 
      'colour'  => 'ff69b4', 
      'desc'    => 'An inframe non synonymous variant that inserts bases into in the coding sequence',
      'acc'     => '0001821', 
      'impact'  => 'MODERATE',
    },
    {
      'term'    => 'inframe_deletion', 
      'colour'  => 'ff69b4', 
      'desc'    => 'An inframe non synonymous variant that deletes bases from the coding sequence',
      'acc'     => '0001822', 
      'impact'  => 'MODERATE',
    },
    {
      'term'    => 'missense_variant', 
      'colour'  => 'ffd700', 
      'desc'    => 'A sequence variant, that changes one or more bases, resulting in a different amino acid sequence but where the length is preserved', 
      'acc'     => '0001583', 
      'impact'  => 'MODERATE',
    },
    {
      'term'    => 'protein_altering_variant', 
      'colour'  => 'FF0080', 
      'desc'    => 'A sequence_variant which is predicted to change the protein encoded in the coding sequence', 
      'acc'     => '0001818', 
      'impact'  => 'MODERATE',
    },
    {
      'term'    => 'splice_region_variant', 
      'colour'  => 'ff7f50', 
      'desc'    => 'A sequence variant in which a change has occurred within the region of the splice site, either within 1-3 bases of the exon or 3-8 bases of the intron', 
      'acc'     => '0001630', 
      'impact'  => 'LOW',
    },
    {
      'term'    => 'incomplete_terminal_codon_variant', 
      'colour'  => 'ff00ff', 
      'desc'    => 'A sequence variant where at least one base of the final codon of an incompletely annotated transcript is changed', 
      'acc'     => '0001626', 
      'impact'  => 'LOW',
    },
    {
      'term'    => 'start_retained_variant',
      'colour'  => '76ee00',
      'desc'    => 'A sequence variant where at least one base in the start codon is changed, but the start remains',
      'acc'     => '0002019',
      'impact'  => 'LOW',
    },
    {
      'term'    => 'stop_retained_variant', 
      'colour'  => '76ee00', 
      'desc'    => 'A sequence variant where at least one base in the terminator codon is changed, but the terminator remains', 
      'acc'     => '0001567', 
      'impact'  => 'LOW',
    },
    {
      'term'    => 'synonymous_variant', 
      'colour'  => '76ee00', 
      'desc'    => 'A sequence variant where there is no resulting change to the encoded amino acid', 
      'acc'     => '0001819', 
      'impact'  => 'LOW',
    },
    {
      'term'    => 'coding_sequence_variant', 
      'colour'  => '458b00', 
      'desc'    => 'A sequence variant that changes the coding sequence', 
      'acc'     => '0001580', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'mature_miRNA_variant', 
      'colour'  => '458b00', 
      'desc'    => 'A transcript variant located with the sequence of the mature miRNA', 
      'acc'     => '0001620', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => '5_prime_UTR_variant', 
      'colour'  => '7ac5cd', 
      'desc'    => "A UTR variant of the 5' UTR", 
      'acc'     => '0001623', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => '3_prime_UTR_variant', 
      'colour'  => '7ac5cd', 
      'desc'    => "A UTR variant of the 3' UTR", 
      'acc'     => '0001624', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'non_coding_transcript_exon_variant', 
      'colour'  => '32cd32', 
      'desc'    => 'A sequence variant that changes non-coding exon sequence in a non-coding transcript', 
      'acc'     => '0001792', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'intron_variant', 
      'colour'  => '02599c', 
      'desc'    => 'A transcript variant occurring within an intron', 
      'acc'     => '0001627', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'NMD_transcript_variant', 
      'colour'  => 'ff4500', 
      'desc'    => 'A variant in a transcript that is the target of NMD', 
      'acc'     => '0001621', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'non_coding_transcript_variant', 
      'colour'  => '32cd32', 
      'desc'    => 'A transcript variant of a non coding RNA gene', 
      'acc'     => '0001619', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'upstream_gene_variant', 
      'colour'  => 'a2b5cd', 
      'desc'    => "A sequence variant located 5' of a gene", 
      'acc'     => '0001631', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'downstream_gene_variant', 
      'colour'  => 'a2b5cd', 
      'desc'    => "A sequence variant located 3' of a gene", 
      'acc'     => '0001632', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'TFBS_ablation', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A feature ablation whereby the deleted region includes a transcription factor binding site', 
      'acc'     => '0001895',
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'TFBS_amplification', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A feature amplification of a region containing a transcription factor binding site', 
      'acc'     => '0001892', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'TF_binding_site_variant', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A sequence variant located within a transcription factor binding site', 
      'acc'     => '0001782', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'regulatory_region_ablation', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A feature ablation whereby the deleted region includes a regulatory region', 
      'acc'     => '0001894', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'regulatory_region_amplification', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A feature amplification of a region containing a regulatory region', 
      'acc'     => '0001891', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'feature_elongation', 
      'colour'  => '7f7f7f', 
      'desc'    => 'A sequence variant that causes the extension of a genomic feature, with regard to the reference sequence', 
      'acc'     => '0001907', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'regulatory_region_variant', 
      'colour'  => 'a52a2a', 
      'desc'    => 'A sequence variant located within a regulatory region', 
      'acc'     => '0001566', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'feature_truncation', 
      'colour'  => '7f7f7f', 
      'desc'    => 'A sequence variant that causes the reduction of a genomic feature, with regard to the reference sequence', 
      'acc'     => '0001906', 
      'impact'  => 'MODIFIER',
    },
    {
      'term'    => 'intergenic_variant', 
      'colour'  => '636363', 
      'desc'    => 'A sequence variant located in the intergenic region, between genes', 
      'acc'     => '0001628', 
      'impact'  => 'MODIFIER',
    },
  ];

  ## Get glossary and lookup info
  my $hub     = $self->hub;
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $lookup  = $adaptor->fetch_lookup;

  foreach (@$data) {
    my $row = {};

    $row->{'colour'}  = {'style' => {'background-color' => '#'.$_->{'colour'}}, 'class' => 'colour-swatch'}; 
    $row->{'term'}    = $_->{'term'};
    $row->{'desc'}    = $_->{'desc'};

    my $d_term = ucfirst($_->{'term'});
    $d_term =~ s/_/ /g;
    $row->{'d_term'}  = $d_term;

    my $link = sprintf('<a href="http://www.sequenceontology.org/miso/current_svn/term/SO:%s">SO:%s</a>', $_->{'acc'}, $_->{'acc'});
    $row->{'acc'} = {'value' => $link}; 

    my $impact_key = 'IMPACT: '.$_->{'impact'};
    my $definition = $impact_key.'<br>'.$lookup->{$impact_key};
    my $helptip = sprintf('<span class="ht _ht"><span class="_ht_tip hidden">%s</span>%s</span>', encode_entities($definition), $_->{'impact'});
    $row->{'impact'} = $helptip;

    $row->{'options'} = {'id' => $_->{'term'}};
  
    $table->add_row($row);
  }

  $html .= $table->render;

  $html .= '<p><b>*</b> Corresponding colours for the Ensembl web displays.<p>';

  return $html;
}

1;
