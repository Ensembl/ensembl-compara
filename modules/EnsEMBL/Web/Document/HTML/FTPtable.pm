package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;

use HTML::Entities qw(encode_entities);

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
    'cdna'       => 'cDNA sequences for Ensembl or "ab initio" predicted genes',
    'prot'       => 'Protein sequences for Ensembl or "ab initio" predicted genes',
    'rna'        => 'Non-coding RNA gene predictions',
    'embl'       => 'Ensembl database dumps in EMBL nucleotide sequence database format',
    'genbank'    => 'Ensembl database dumps in GenBank nucleotide sequence database format',
    'gtf'        => 'Gene sets for each species. These files include annotations of both coding and non-coding genes',
    'mysql'      => 'All Ensembl MySQL databases are available in text format as are the SQL table definition files',
    'emf'        => 'Alignments of resequencing data from the ensembl_compara database',
    'gvf'        => 'Variation data in GVF format',
    'vep'        => 'Cache files for use with the VEP script',
    'funcgen'    => 'Regulation data in GFF format',
    'coll'       => 'Additional regulation data (not in database)',
    'bed'        => 'Constrained elements calculated using GERP',
    'extra'      => 'Additional release data stored as flat files rather than MySQL for performance reasons',
    'ancestral'  => 'Ancestral Allele data in FASTA format',
    'bam'        => 'Alignments against the genome',
  );
  
  $title{$_} = encode_entities($title{$_}) for keys %title;

  my $EMF = $title{'emf'};
  my $BED = $title{'bed'};
  my $XML = $title{'xml'};
  my $ANC = $title{'ancestral'};

  my $html = qq(
<h3>Multi-species data</h3>
<table class="ss tint" cellpadding="4">
<tr>
<th>Database</th>
<th></th>
<th></th>
<th></th>
<th></th>
<th></th>
</tr>
<tr class="bg1">
<td>Comparative genomics</td>
<td style="text-align:center"><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td style="text-align:center"><a rel="external" title="$EMF" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/emf/ensembl-compara/">EMF</a></td>
<td style="text-align:center"><a rel="external" title="$BED" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/bed/">BED</a></td>
<td style="text-align:center"><a rel="external" title="$XML" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/xml/ensembl-compara/homologies/">XML</a></td>
<td style="text-align:center"><a rel="external" title="$ANC" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/fasta/ancestral_alleles">Ancestral Alleles</a></td>

</tr>
<tr class="bg2">
<td>BioMart</td>
<td style="text-align:center"><a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/).$rel.qq(/mysql/">MySQL</a></td>
<td style="text-align:center">-</td>
<td style="text-align:center">-</td>
<td style="text-align:center">-</td>
<td style="text-align:center">-</td>
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
    { key => 'dna',     title => 'DNA (FASTA)',         align => 'center', width => '10%', sort => 'none' },
    { key => 'cdna',    title => 'cDNA (FASTA)',        align => 'center', width => '10%', sort => 'none' },
    { key => 'ncrna',   title => 'ncRNA (FASTA)',       align => 'center', width => '10%', sort => 'none' },
    { key => 'protseq', title => 'Protein sequence (FASTA)',  align => 'center', width => '10%', sort => 'none' },
    { key => 'embl',    title => 'Annotated sequence (EMBL)', align => 'center', width => '10%', sort => 'none' },
    { key => 'genbank', title => 'Annotated sequence (GenBank)',  align => 'center', width => '10%', sort => 'none' },
    { key => 'genes',   title => 'Gene sets',           align => 'center', width => '10%', sort => 'none' },
    { key => 'mysql',   title => 'Whole databases',     align => 'center', width => '10%', sort => 'none' },
    { key => 'var1',    title => 'Variation (EMF)',     align => 'center', width => '10%', sort => 'html' },
    { key => 'var2',    title => 'Variation (GVF)',     align => 'center', width => '10%', sort => 'html' },
    { key => 'var3',    title => 'Variation (VEP)',     align => 'center', width => '10%', sort => 'html' },
    { key => 'funcgen', title => 'Regulation (GFF)',    align => 'center', width => '10%', sort => 'html' },
    { key => 'files',   title => 'Data files',          align => 'center', width => '10%', sort => 'html' },
    { key => 'bam',     title => 'BAM',                 align => 'center', width => '10%', sort => 'html' },
  );

  my @species = $species_defs->ENSEMBL_DATASETS;
  my $rows;
  
  my $required_lookup = $self->required_types_for_species();
  
  foreach my $spp (sort @{$species_defs->ENSEMBL_DATASETS}) {
    (my $sp_name = $spp) =~ s/_/ /;
    my $sp_dir =lc($spp);
    my $sp_var = lc($spp).'_variation';
    my $common = $species_defs->get_config($spp, 'DISPLAY_NAME');
  
    my $emf   = '-';
    if($required_lookup->{var1}->{$sp_dir}) {
      $emf = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/emf/%s/">EMF</a>', $title{'emf'}, $rel, $sp_var;
    }
    
    my $variation = '-';
    if($required_lookup->{var2}->{$sp_dir}) {
      $variation = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/gvf/%s/">GVF</a>', $title{'gvf'}, $rel, $sp_dir;
    }
    
    my $vep = '-';
    if($required_lookup->{var3}->{$sp_dir}) {
      $vep = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/VEP/%s/">VEP</a>', $title{'vep'}, $rel, $sp_dir;
    }
    
    my $funcgen = '-';
    if($required_lookup->{funcgen}->{$sp_dir}) {
      $funcgen = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/regulation/%s/">Regulation</a> (GFF)', $title{'funcgen'}, $rel, $sp_dir;      
    }
    
    my $extra = '-';
    if($required_lookup->{files}->{$sp_dir}) {
      my $dbs = $species_defs->get_config(ucfirst($sp_dir), 'databases');
      my $coll_dir = $dbs->{'DATABASE_FUNCGEN'}{'NAME'};
      $extra = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/data_files/%s/">Regulation data files</a>', $title{'extra'}, $rel, $coll_dir;
    }
    
    my $bam = '-';
    if($required_lookup->{bam}->{$sp_dir}) {
      $bam = sprintf '<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/bam/%s/">BAM</a>', $title{'bam'}, $rel, $sp_dir;
    }

    $table->add_row({
      'species'       => sprintf('<strong><i>%s</i></strong> (%s)', $sp_name, $common),
      'dna'           => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a>', $title{'dna'}, $rel, $sp_dir),
      'cdna'          => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/cdna/">FASTA</a>', $title{'cdna'}, $rel, $sp_dir),
      'ncrna'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/ncrna/">FASTA</a>', $title{'rna'}, $rel, $sp_dir),
      'protseq'       => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/pep/">FASTA</a>', $title{'prot'}, $rel, $sp_dir),
      'embl'          => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/embl/%s/">EMBL</a>', $title{'embl'}, $rel, $sp_dir),
      'genbank'       => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/genbank/%s/">GenBank</a>', $title{'genbank'}, $rel, $sp_dir),
      'genes'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/gtf/">GTF</a>', $title{'gtf'}, $rel),
      'mysql'         => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/mysql/">MySQL</a>', $title{'mysql'}, $rel),
      'var1'          => $emf,
      'var2'          => $variation,
      'var3'          => $vep,
      'funcgen'       => $funcgen,
      'files'         => $extra,
      'bam'           => $bam,
    });
  }

  $html .= $table->render;
  $html .= '</div>';

  return $html;
}

#Lookup for the types we need for species
sub required_types_for_species {
  my ($self) = @_;
  my %required_lookup;
  
  #EMF
  $required_lookup{var1} = { map { $_ => 1} qw/
    homo_sapiens mus_musculus rattus_norvegicus
  / };
  
  #GVF
  $required_lookup{var2} = { map { $_ => 1 } qw/
    bos_taurus canis_familiaris danio_rerio drosophila_melanogaster 
    equus_caballus felis_catus gallus_gallus homo_sapiens 
    saccharomyces_cerevisiae monodelphis_domestica mus_musculus 
    ornithorhynchus_anatinus pan_troglodytes pongo_pygmaeus 
    rattus_norvegicus sus_scrofa taeniopygia_guttata tetraodon_nigroviridis 
    pongo_abelii
  / };
  
  #VEP
  $required_lookup{var3} = { map { $_ => 1 } qw/
    bos_taurus danio_rerio homo_sapiens mus_musculus rattus_norvegicus
  / };
  
  #Funcgen
  $required_lookup{funcgen} = { map { $_ => 1 } qw/
    homo_sapiens mus_musculus
  / };
  
  #Funcgen files
  $required_lookup{files} = { map { $_ => 1 } qw/
    homo_sapiens mus_musculus
  / };
  
  #BAM
  $required_lookup{bam} = { map { $_ => 1 } qw/
    pan_troglodytes
  / };
  
  return \%required_lookup;
}

1; 
