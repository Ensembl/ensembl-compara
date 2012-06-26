# $Id$

package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::Table;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self            = shift;
  my $species_defs    = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $rel             = 'release-' . $species_defs->ENSEMBL_VERSION; # Always set to use the release number rather than current to get around the delay in FTP site links updating
  my $required_lookup = $self->required_types_for_species;
  my $table           = new EnsEMBL::Web::Document::Table([], [], { data_table => 1, exportable => 0 });
  my $rows;
  
  my %title = (
    dna       => 'Masked and unmasked genome sequences associated with the assembly (contigs, chromosomes etc.)',
    cdna      => 'cDNA sequences for Ensembl or "ab initio" predicted genes',
    prot      => 'Protein sequences for Ensembl or "ab initio" predicted genes',
    rna       => 'Non-coding RNA gene predictions',
    embl      => 'Ensembl database dumps in EMBL nucleotide sequence database format',
    genbank   => 'Ensembl database dumps in GenBank nucleotide sequence database format',
    gtf       => 'Gene sets for each species. These files include annotations of both coding and non-coding genes',
    mysql     => 'All Ensembl MySQL databases are available in text format as are the SQL table definition files',
    emf       => 'Alignments of resequencing data from the ensembl_compara database',
    gvf       => 'Variation data in GVF format',
    vep       => 'Cache files for use with the VEP script',
    funcgen   => 'Regulation data in GFF format',
    coll      => 'Additional regulation data (not in database)',
    bed       => 'Constrained elements calculated using GERP',
    files     => 'Additional release data stored as flat files rather than MySQL for performance reasons',
    ancestral => 'Ancestral Allele data in FASTA format',
    bam       => 'Alignments against the genome',
  );
  
  $title{$_} = encode_entities($title{$_}) for keys %title;
  
  $table->add_columns(
    { key => 'species', title => 'Species',                      align => 'left',   width => '10%', sort => 'html' },
    { key => 'dna',     title => 'DNA (FASTA)',                  align => 'center', width => '10%', sort => 'none' },
    { key => 'cdna',    title => 'cDNA (FASTA)',                 align => 'center', width => '10%', sort => 'none' },
    { key => 'ncrna',   title => 'ncRNA (FASTA)',                align => 'center', width => '10%', sort => 'none' },
    { key => 'protseq', title => 'Protein sequence (FASTA)',     align => 'center', width => '10%', sort => 'none' },
    { key => 'embl',    title => 'Annotated sequence (EMBL)',    align => 'center', width => '10%', sort => 'none' },
    { key => 'genbank', title => 'Annotated sequence (GenBank)', align => 'center', width => '10%', sort => 'none' },
    { key => 'genes',   title => 'Gene sets',                    align => 'center', width => '10%', sort => 'none' },
    { key => 'mysql',   title => 'Whole databases',              align => 'center', width => '10%', sort => 'none' },
    { key => 'var1',    title => 'Variation (EMF)',              align => 'center', width => '10%', sort => 'html' },
    { key => 'var2',    title => 'Variation (GVF)',              align => 'center', width => '10%', sort => 'html' },
    { key => 'var3',    title => 'Variation (VEP)',              align => 'center', width => '10%', sort => 'html' },
    { key => 'funcgen', title => 'Regulation (GFF)',             align => 'center', width => '10%', sort => 'html' },
    { key => 'files',   title => 'Data files',                   align => 'center', width => '10%', sort => 'html' },
    { key => 'bam',     title => 'BAM',                          align => 'center', width => '10%', sort => 'html' },
  );
  
  foreach my $spp (sort @{$species_defs->ENSEMBL_DATASETS}) {
    (my $sp_name  = $spp) =~ s/_/ /;
    my $sp_dir    = lc $spp;
    my $sp_var    = lc $spp . '_variation';

    $table->add_row({
      species => sprintf('<strong><i>%s</i></strong> (%s)', $sp_name, $species_defs->get_config($spp, 'DISPLAY_NAME')),
      dna     => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/dna/">FASTA</a>',   $title{'dna'},     $rel, $sp_dir),
      cdna    => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/cdna/">FASTA</a>',  $title{'cdna'},    $rel, $sp_dir),
      ncrna   => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/ncrna/">FASTA</a>', $title{'rna'},     $rel, $sp_dir),
      protseq => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/fasta/%s/pep/">FASTA</a>',   $title{'prot'},    $rel, $sp_dir),
      embl    => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/embl/%s/">EMBL</a>',         $title{'embl'},    $rel, $sp_dir),
      genbank => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/genbank/%s/">GenBank</a>',   $title{'genbank'}, $rel, $sp_dir),
      genes   => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/gtf/">GTF</a>',              $title{'gtf'},     $rel),
      mysql   => sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/mysql/">MySQL</a>',          $title{'mysql'},   $rel),
      var1    => $required_lookup->{'var1'}{$sp_dir}    ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/emf/%s/">EMF</a>',                          $title{'emf'},     $rel, $sp_var)    : '-',
      var2    => $required_lookup->{'var2'}{$sp_dir}    ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/gvf/%s/">GVF</a>',                $title{'gvf'},     $rel, $sp_dir)    : '-',
      var3    => $required_lookup->{'var3'}{$sp_dir}    ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/variation/VEP/">VEP</a>',                $title{'vep'},     $rel )    : '-',
      funcgen => $required_lookup->{'funcgen'}{$sp_dir} ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/regulation/%s/">Regulation</a> (GFF)',      $title{'funcgen'}, $rel, $sp_dir)    : '-',
      bam     => $required_lookup->{'bam'}{$sp_dir}     ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/bam/%s/">BAM</a>',                          $title{'bam'},     $rel, $sp_dir)    : '-',
      files   => $required_lookup->{'files'}{$sp_dir}   ? sprintf('<a rel="external" title="%s" href="ftp://ftp.ensembl.org/pub/%s/data_files/%s/">Regulation data files</a>', $title{'files'},   $rel, $sp_dir) : '-',
    });
  }
  
  return sprintf(qq{
    <h3>Multi-species data</h3>
    %s
    <div class="js_panel" id="ftp-table">
      <input type="hidden" class="panel_type" value="Content">
      <h3>Single species data</h3>
      %s
    </div>
  }, new EnsEMBL::Web::Document::Table([
    { key => 'database',  title => 'Database' },
    { key => 'mysql',     title => '', align => 'center' },
    { key => 'emf',       title => '', align => 'center' },
    { key => 'bed',       title => '', align => 'center' },
    { key => 'xml',       title => '', align => 'center' },
    { key => 'ancestral', title => '', align => 'center' }
  ], [{
    database  => 'Comparative genomics',
    mysql     => qq{<a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/$rel/mysql/">MySQL</a>},
    emf       => qq{<a rel="external" title="$title{'emf'}" href="ftp://ftp.ensembl.org/pub/$rel/emf/ensembl-compara/">EMF</a>},
    bed       => qq{<a rel="external" title="$title{'bed'}" href="ftp://ftp.ensembl.org/pub/$rel/bed/">BED</a>},
    xml       => qq{<a rel="external" title="$title{'xml'}" href="ftp://ftp.ensembl.org/pub/$rel/xml/ensembl-compara/homologies/">XML</a>},
    ancestral => qq{<a rel="external" title="$title{'ancestral'}" href="ftp://ftp.ensembl.org/pub/$rel/fasta/ancestral_alleles">Ancestral Alleles</a>},
  }, {
    database  => 'BioMart',
    mysql     => qq{<a rel="external" title="$title{'mysql'}" href="ftp://ftp.ensembl.org/pub/$rel/mysql/">MySQL</a>},
    emf       => '-',
    bed       => '-',
    xml       => '-',
    ancestral => '-',
  }], { cellpadding => 4, cellspacing => 2, id => 'ftp-table1' })->render, $table->render);
}

# Lookup for the types we need for species
sub required_types_for_species {
  my $self = shift;
  my %required_lookup;
  
  # EMF
  $required_lookup{'var1'} = { map { $_ => 1 } qw(
    homo_sapiens mus_musculus rattus_norvegicus
  )};
  
  # GVF
  $required_lookup{'var2'} = { map { $_ => 1 } qw(
    bos_taurus canis_familiaris danio_rerio drosophila_melanogaster 
    equus_caballus felis_catus gallus_gallus homo_sapiens 
    saccharomyces_cerevisiae monodelphis_domestica mus_musculus 
    ornithorhynchus_anatinus pan_troglodytes pongo_pygmaeus 
    rattus_norvegicus sus_scrofa taeniopygia_guttata tetraodon_nigroviridis 
    pongo_abelii macaca_mulatta
  )};
  
  # VEP
  $required_lookup{'var3'} = { map { $_ => 1 } qw(
    bos_taurus danio_rerio homo_sapiens mus_musculus rattus_norvegicus
  )};
  
  # Funcgen
  $required_lookup{'funcgen'} = { map { $_ => 1 } qw(
    homo_sapiens mus_musculus
  )};
  
  # Funcgen files
  $required_lookup{'files'} = { map { $_ => 1 } qw(
    homo_sapiens mus_musculus
  )};
  
  # BAM
  $required_lookup{'bam'} = { map { $_ => 1 } qw(
    pan_troglodytes sus_scrofa oreochromis_niloticus
  )};
  
  return \%required_lookup;
}

1; 
