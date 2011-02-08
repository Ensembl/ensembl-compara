package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  # Always set to use the release number rather than current to get around the delay in FTP site links updating 
  my $rel = 'release-'.$species_defs->ENSEMBL_VERSION;

  my %title = (
    'dna'     => 'Masked and unmasked genome sequences associated with the assembly (contigs, chromosomes etc.)',
    'cdna'    => 'cDNA sequences for Ensembl or "ab initio" predicted genes',
    'prot'    => 'Protein sequences for Ensembl or "ab initio" predicted genes',
    'rna'     => 'Non-coding RNA gene predictions',
    'embl'    => 'Ensembl database dumps in EMBL nucleotide sequence database format',
    'genbank' => 'Ensembl database dumps in GenBank nucleotide sequence database format',
    'gtf'     => 'Gene sets for each species. These files include annotations of both coding and non-coding genes',
    'mysql'   => 'All Ensembl MySQL databases are available in text format as are the SQL table definition files',
    'emf'     => 'Alignments of resequencing data from the ensembl_compara database',
    'gvf'     => 'Variation data in GVF format',
    'funcgen' => 'Functional genomics data in GFF format',
    'bed'     => 'Constrained elements calculated using GERP',
  );

  my $html = qq(
<table class="ss tint" cellpadding="4">

<tr>
<th>Species</th>
<th colspan="3" style="text-align:center">DNA sequence only</th>
<th colspan="1" style="text-align:center">Protein sequence</th>
<th colspan="2" style="text-align:center">Annotated sequence</th>
<th colspan="1" style="text-align:center">Gene sets</th>
<th colspan="1" style="text-align:center">MySQL</th>
<th colspan="2" style="text-align:center">Resequencing data</th>
<th colspan="4" style="text-align:center">Other</th>
</tr>

);
  my @species = $species_defs->ENSEMBL_DATASETS;
  my $row = 0;
  my $class;
  foreach my $spp (sort @{$species_defs->ENSEMBL_DATASETS}) {
    (my $sp_name = $spp) =~ s/_/ /;
    my $sp_dir =lc($spp);
    my $sp_var = lc($spp).'_variation';
    my $common = $species_defs->get_config($spp, 'DISPLAY_NAME');
    my $variation = '-'; 
    if ($sp_dir =~ /bos_taurus|canis_familiaris|danio_rerio|drosophila_melanogaster|equus_caballus|felis_catus|gallus_gallus|homo_sapiens|saccharomyces_cerevisiae|monodelphis_domestica|mus_musculus|ornithorhynchus_anatinus|pan_troglodytes|pongo_pygmaeus|rattus_norvegicus|sus_scrofa|taeniopygia_guttata|tetraodon_nigroviridis/) {
      $variation = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/%s/">Variation</a>', $title{'gvf'}, $rel, $sp_dir;
    }
    my $emf = '-';
    if ($sp_dir =~ /homo_sapiens|mus_musculus|rattus_norvegicus/) {
      $emf = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/emf/%s/">EMF</a>', $title{'emf'}, $rel, $sp_var;
    }
    my $funcgen = '-';
    if ($sp_dir =~ /homo_sapiens/ || $sp_dir =~/mus_musculus/) {
      $funcgen = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/functional_genomics/%s/">FUNCGEN</a>', $title{'funcgen'}, $rel, $sp_dir;
    }
    $class = $row % 2 == 0 ? 'bg1' : 'bg2';

    $html .= sprintf qq(
<tr class="%s">
<td><strong><i>%s</i></strong> (%s)</td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a> (DNA)</td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/cdna/">FASTA</a> (cDNA)</td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/ncrna/">FASTA</a> (ncRNA)</td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/pep/">FASTA</a> (protein)</td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/embl/%s/">EMBL</a></td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/genbank/%s/">GenBank</a></td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/gtf/">GTF</a></td>
<td><a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/mysql/">MySQL</a></td>
<td>%s</td>
<td>%s</td>
<td>%s</td>
<td>-</td>
<td>-</td>
</tr>
      ), $class, $sp_name, $common,
         $title{'dna'}, $rel, $sp_dir, 
         $title{'cdna'}, $rel, $sp_dir, 
         $title{'rna'}, $rel, $sp_dir,
         $title{'prot'}, $rel, $sp_dir, 
         $title{'embl'}, $rel, $sp_dir,
         $title{'genbank'}, $rel, $sp_dir,
         $title{'gtf'}, $rel,
         $title{'mysql'}, $rel,
         $emf, $variation, $funcgen, 
    ;
    $row++;
  }
  my $rev = $class eq 'bg2' ? 'bg2' : 'bg1';
  $class = $class eq 'bg2' ? 'bg1' : 'bg2';
  my $EMF = $title{'emf'};
  my $BED = $title{'bed'};
  $html .= qq(
<tr class="$class">
<td><strong>Multi-species</strong></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td><a rel="external" title="$EMF" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/emf/ensembl-compara/">EMF</a></td>
<td>-</td>
<td>-</td>
<td><a rel="external" title="$BED" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/bed/">BED</a></td>
<td>-</td>
</tr>
<tr class="$rev">
<td><strong>Ensembl Mart</strong></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
</tr>
<tr class="$class">
<td><strong>Ensembl API</strong></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td><a rel="external" title="Entire Ensembl API, concatenated into a single TAR file and gzipped - updated daily" href="ftp://ftp.ensembl.org/pub/ensembl-api.tar.gz ">Tarball</td>
</tr>
</table>
  );

  return $html;
}

1; 
