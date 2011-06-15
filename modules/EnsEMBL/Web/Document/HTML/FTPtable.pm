package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::SpreadSheet;
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
    'funcgen' => 'Regulation data in GFF format',
    'coll'    => 'Additional regulation data (not in database)',
    'bed'     => 'Constrained elements calculated using GERP',
    'extra'   => 'Additional release data stored as flat files rather than MySQL for performance reasons',
  );


  my $EMF = $title{'emf'};
  my $BED = $title{'bed'};


  my $html = qq(
<h3>Multi-species data</h3>
<table class="ss tint" cellpadding="4">
<tr>
<th>Database</th>
<th></th>
<th></th>
<th></th>
</tr>
<tr class="bg1">
<td>Comparative genomics</td>
<td style="text-align:center"><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td style="text-align:center"><a rel="external" title="$EMF" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/emf/ensembl-compara/">EMF</a></td>
<td style="text-align:center"><a rel="external" title="$BED" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/bed/">BED</a></td>
</tr>
<tr class="bg2">
<td>BioMart</td>
<td style="text-align:center"><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td>-</td>
<td>-</td>
</tr>
</table>
);

  ## Main table
  $html .= qq(
<div class="js_panel" id="ftp-table">
<input type="hidden" class="panel_type" value="Content">
<h3>Single species data</h3>
);

  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], {data_table => 1});
  $table->add_columns(
    { key => 'species', title => 'Species',             align => 'left',   width => '10%', sort => 'html' },
    { key => 'dna',     title => 'FASTA (DNA)',         align => 'center', width => '10%', sort => 'none' },
    { key => 'cdna',    title => 'FASTA (cDNA)',        align => 'center', width => '10%', sort => 'none' },
    { key => 'ncrna',   title => 'FASTA (ncRNA)',       align => 'center', width => '10%', sort => 'none' },
    { key => 'protseq', title => 'Protein sequence',    align => 'center', width => '10%', sort => 'none' },
    { key => 'embl',    title => 'Annotated sequence (EMBL)',  align => 'center', width => '10%', sort => 'none' },
    { key => 'genbank', title => 'Annotated sequence (GenBank)',  align => 'center', width => '10%', sort => 'none' },
    { key => 'genes',   title => 'Gene sets',           align => 'center', width => '10%', sort => 'none' },
    { key => 'mysql',   title => 'Whole databases',     align => 'center', width => '10%', sort => 'none' },
    { key => 'var1',    title => 'Variation (EMF)',     align => 'center', width => '10%', sort => 'html' },
    { key => 'var2',    title => 'Variation (GVF)',     align => 'center', width => '10%', sort => 'html' },
    { key => 'funcgen', title => 'Regulation (GFF)',    align => 'center', width => '10%', sort => 'html' },
    { key => 'files',   title => 'Data files',          align => 'center', width => '10%', sort => 'html' },
  );

  my @species = $species_defs->ENSEMBL_DATASETS;
  my $rows;

  foreach my $spp (sort @{$species_defs->ENSEMBL_DATASETS}) {
    (my $sp_name = $spp) =~ s/_/ /;
    my $sp_dir =lc($spp);
    my $sp_var = lc($spp).'_variation';
    my $common = $species_defs->get_config($spp, 'DISPLAY_NAME');
    my $variation = '-'; 
    if ($sp_dir =~ /bos_taurus|canis_familiaris|danio_rerio|drosophila_melanogaster|equus_caballus|felis_catus|gallus_gallus|homo_sapiens|saccharomyces_cerevisiae|monodelphis_domestica|mus_musculus|ornithorhynchus_anatinus|pan_troglodytes|pongo_pygmaeus|rattus_norvegicus|sus_scrofa|taeniopygia_guttata|tetraodon_nigroviridis/) {
      $variation = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/%s/">GVF</a>', $title{'gvf'}, $rel, $sp_dir;
    }
    my $emf   = '-';
    if ($sp_dir =~ /homo_sapiens|mus_musculus|rattus_norvegicus/) {
      $emf = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/emf/%s/">EMF</a>', $title{'emf'}, $rel, $sp_var;
    }
    my $funcgen = '-';
    my $extra = '-';
    if ($sp_dir =~ /homo_sapiens/ || $sp_dir =~/mus_musculus/) {
      $funcgen = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/functional_genomics/%s/">Regulation</a> (GFF)', $title{'funcgen'}, $rel, $sp_dir;
      my $dbs = $species_defs->get_config(ucfirst($sp_dir), 'databases');
      my $coll_dir = $dbs->{'DATABASE_FUNCGEN'}{'NAME'};
      $extra = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/data_files/%s/">Regulation data files</a>', $title{'extra'}, $rel, $coll_dir;
    }

    $table->add_row({
      'species'       => sprintf('<strong><i>%s</i></strong> (%s)', $sp_name, $common),
      'dna'           => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a> (DNA)', $title{'dna'}, $rel, $sp_dir),
      'cdna'          => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a> (DNA)', $title{'cdna'}, $rel, $sp_dir),
      'ncrna'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a> (DNA)', $title{'rna'}, $rel, $sp_dir),
      'protseq'       => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/pep/">FASTA</a> (protein)', $title{'prot'}, $rel, $sp_dir),
      'embl'          => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/embl/%s/">EMBL</a>', $title{'embl'}, $rel, $sp_dir),
      'genbank'       => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/genbank/%s/">GenBank</a>', $title{'genbank'}, $rel, $sp_dir),
      'genes'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/gtf/">GTF</a>', $title{'gtf'}, $rel),
      'mysql'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/mysql/">MySQL</a>', $title{'mysql'}, $rel),
      'var1'          => $emf,
      'var2'          => $variation,
      'funcgen'       => $funcgen,
      'files'         => $extra,
    });
  }

  $html .= $table->render;
  $html .= '</div>';

  return $html;
}

1; 
