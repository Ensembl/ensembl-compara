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

package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $division        = $species_defs->EG_DIVISION || '';

  my $html;

  if ($species_defs->ENSEMBL_MART_ENABLED) {
    $html .= qq(
<div class="info-box embedded-box float-right" style="margin-bottom:1em;">
<h2 class="first">Custom data sets</h2>
<p>If you want to filter or customise your download, please try
<a href="/biomart/martview">Biomart</a>, a web-based querying tool.</p>
</div>
);
  }

  my $ftp = $division ? $species_defs->ENSEMBL_GENOMES_FTP_URL : $species_defs->ENSEMBL_FTP_URL;
  if ($species_defs->HAS_API_DOCS) {
    $html .= qq(
<h2>API Code</h2>

<p>If you do not have access to git, you can obtain our latest API code as a gzipped tarball:</p>

<p><a href="$ftp/ensembl-api.tar.gz">Download complete API for this release</a></p>

<p>Note: the API version needs to be the same as the databases you are accessing, so please
use git to obtain a previous version if querying older databases.</p>
    );
  }

  my $mysql_dir = $division ? "$ftp/current/mysql/" : "$ftp/current_mysql/";
 
  unless ($species_defs->NO_PUBLIC_MYSQL) { 
    $html .= qq(
<h2>Database dumps</h2>
<p>
Entire databases can be downloaded from our FTP site in a
variety of formats. Please be aware that some of these files
can run to many gigabytes of data.
</p>
<p><strong>Looking for <a href="$mysql_dir">MySQL dumps</a> to install databases locally?</strong> See our
<a href="https://www.ensembl.org/info/docs/webcode/mirror/install/ensembl-data.html">web installation instructions</a>
for full details.</p>
);
  }

(my $ftp_domain = $ftp) =~ s/\/pub//;

  $html .= qq(<p>
Each directory on <a href="$ftp" rel="external">$ftp_domain</a> contains a
<a href="$ftp/current_README">README</a> file, explaining the directory structure.
</p>
  );

  my $required_lookup = $self->required_types_for_species;
  my ($columns, $rows);
  
  my %title = (
    dna       => 'Masked and unmasked genome sequences associated with the assembly (contigs, chromosomes etc.)',
    cdna      => 'cDNA sequences for both Ensembl and "ab initio" predicted genes',
    cds       => 'Coding sequences for Ensembl or "ab initio" predicted genes',
    prot      => 'Protein sequences for Ensembl or "ab initio" predicted genes',
    rna       => 'Non-coding RNA gene predictions',
    embl      => 'Ensembl database dumps in EMBL nucleotide sequence database format',
    genbank   => 'Ensembl database dumps in GenBank nucleotide sequence database format',
    tsv       => 'External references in TSV format',
    rdf       => 'External references and other annotation data in RDF format',
    json      => 'External references and other annotation data in JSON format',
    gtf       => 'Gene sets for each species. These files include annotations of both coding and non-coding genes',
    gff3      => 'GFF3 provides access to all annotated transcripts which make up an Ensembl gene set',
    mysql     => 'All Ensembl MySQL databases are available in text format as are the SQL table definition files',
    emf       => 'Alignments of resequencing data from the ensembl_compara database',
    gvf       => 'Variation data in GVF format',
    vcf       => 'Variation data in VCF format',
    vep       => 'Cache files for use with the VEP script',
    funcgen   => 'Regulation data in GFF format',
    coll      => 'Additional regulation data (not in the database)',
    bed       => 'Constrained elements calculated using GERP',
    files     => 'Additional release data stored as flat files rather than MySQL for performance reasons',
    ancestral => 'Ancestral Allele data in FASTA format',
    bam       => 'Alignments against the genome',
  );

  $title{$_} = encode_entities($title{$_}) for keys %title;
  my $fave_title = $self->hub->species_defs->FAVOURITES_SYNONYM || 'Favourite';
  
  $columns = [
    { key => 'fave',    title => $fave_title,                    align => 'left',   width => '5%',  sort => 'html',
                        label => '<img src="/i/16/star.png" />'},
    { key => 'species', title => 'Species',                      align => 'left',   width => '10%', sort => 'html' },
    { key => 'dna',     title => 'DNA (FASTA)',                  align => 'center', width => '10%', sort => 'none' },
    { key => 'cdna',    title => 'cDNA (FASTA)',                 align => 'center', width => '10%', sort => 'none' },
    { key => 'cds',     title => 'CDS (FASTA)',                  align => 'center', width => '10%', sort => 'none' },
    { key => 'ncrna',   title => 'ncRNA (FASTA)',                align => 'center', width => '10%', sort => 'none' },
    { key => 'protseq', title => 'Protein sequence (FASTA)',     align => 'center', width => '10%', sort => 'none' },
    { key => 'embl',    title => 'Annotated sequence (EMBL)',    align => 'center', width => '10%', sort => 'none' },
    { key => 'genbank', title => 'Annotated sequence (GenBank)', align => 'center', width => '10%', sort => 'none' },
    { key => 'genes',   title => 'Gene sets',                    align => 'center', width => '10%', sort => 'none' },
    { key => 'xrefs',   title => 'Other annotations',            align => 'center', width => '10%', sort => 'none' },
  ];

  unless ($species_defs->NO_PUBLIC_MYSQL) { 
    push @$columns, 
    { key => 'mysql',   title => 'Whole databases',              align => 'center', width => '10%', sort => 'none' };
  }

  unless ($species_defs->NO_VARIATION) {
    push @$columns, (
    { key => 'var2',    title => 'Variation (GVF)',              align => 'center', width => '10%', sort => 'html' },
    { key => 'var4',    title => 'Variation (VCF)',              align => 'center', width => '10%', sort => 'html' },
    { key => 'var3',    title => 'Variation (VEP)',              align => 'center', width => '10%', sort => 'html' }
    );
  }

  ## No regulation dumps for non-vertebrates
  unless ($species_defs->NO_REGULATION || $species_defs->EG_DIVISION) {
    push @$columns, (
    { key => 'funcgen', title => 'Regulation (GFF)',             align => 'center', width => '10%', sort => 'html' },
    { key => 'files',   title => 'Data files',                   align => 'center', width => '10%', sort => 'html' },
    { key => 'bam',     title => 'BAM/BigWig',                          align => 'center', width => '10%', sort => 'html' },
    );
  }

  ## We want favourite species at the top of the table, 
  ## then everything else alphabetically by display name
  my $all_species = [];
  my %fave_check = map {$_ => 1} @{$hub->get_favourite_species};
  foreach (@{$hub->get_favourite_species}) {
    push @$all_species, {
                          'url'         => $species_defs->get_config($_, 'SPECIES_URL'), 
                          'dir'         => $species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME'), 
                          'display_name' => $species_defs->get_config($_, 'SPECIES_DISPLAY_NAME'),
                          'sci_name'    => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
                          'strain'      => $species_defs->get_config($_, 'SPECIES_STRAIN'),
                          'favourite'   => 1,
                        };
  }

  my @other_species;
  foreach ($species_defs->valid_species) {
    push @other_species, {
                          'url'         => $species_defs->get_config($_, 'SPECIES_URL'), 
                          'dir'         => $species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME'), 
                          'display_name' => $species_defs->get_config($_, 'SPECIES_DISPLAY_NAME'),
                          'sci_name'    => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
                          'strain'      => $species_defs->get_config($_, 'SPECIES_STRAIN'),
                          'favourite'   => 0,
                        }
            unless $fave_check{$_};
  }
  push @$all_species, sort {$a->{'display_name'} cmp $b->{'display_name'}} @other_species;

  my ($ftp_base, $version, $rel) = $self->get_misc_params($ftp, $division);

  foreach my $sp (@$all_species) {
    my $sp_url    = $sp->{'url'};
    my $sp_name   = $sp->{'dir'};

    ## Add collection directory for relevant NV divisions
    my $dataset   = lc($hub->species_defs->get_config($sp_url, 'SPECIES_DATASET'));
    my $sp_dir    = ($dataset && $dataset ne $sp_name) ? $dataset.'_collection/' : '';
    $sp_dir      .= $sp_name;

    ## Vertebrate-specific - append scientific name if display name is common name 
    my $display_name  = $sp->{'display_name'};
    my $sp_link       = sprintf('<b><a href="/%s/">%s</a></b>', $sp_url, $display_name);
    my $sci_name      = $sp->{'sci_name'};
    if ($hub->species_defs->USE_COMMON_NAMES && $display_name !~ /$sci_name/) {
      $sp_link .= "<br /> <i>$sci_name</i>";
    }

    my $sp_var    = $sp_dir. '_variation';
    my $databases = $hub->species_defs->get_config(ucfirst($sp_dir), 'databases');
    my $meta_info = $databases->{'DATABASE_VARIATION'}->{'meta_info'}->{1};
    my $has_vcf  = $meta_info && $meta_info->{'variation_source.vcf'}->[0] ne '1';
    
    push @$rows, {
      fave    => $sp->{'favourite'} ? 'Y' : '',
      species => $sp_link, 
      dna     => sprintf('<a rel="external" title="%s" href="%s/fasta/%s/dna/">FASTA</a>', $title{'dna'},  $ftp_base, $sp_dir),
      cdna    => sprintf('<a rel="external" title="%s" href="%s/fasta/%s/cdna/">FASTA</a>',  $title{'cdna'}, $ftp_base, $sp_dir),
      cds	    => sprintf('<a rel="external" title="%s" href="%s/fasta/%s/cds/">FASTA</a>',   $title{'cds'}, $ftp_base, $sp_dir),
      ncrna   => sprintf('<a rel="external" title="%s" href="%s/fasta/%s/ncrna/">FASTA</a>', $title{'rna'},  $ftp_base, $sp_dir),
      protseq => sprintf('<a rel="external" title="%s" href="%s/fasta/%s/pep/">FASTA</a>',   $title{'prot'}, $ftp_base, $sp_dir),
      embl    => sprintf('<a rel="external" title="%s" href="%s/embl/%s/">EMBL</a>',         $title{'embl'},  $ftp_base, $sp_dir),
      genbank => sprintf('<a rel="external" title="%s" href="%s/genbank/%s/">GenBank</a>',   $title{'genbank'}, $ftp_base, $sp_dir),
      genes   => sprintf('<a rel="external" title="%s" href="%s/gtf/%s">GTF</a> <a rel="external" title="%s" href="%s/gff3/%s">GFF3</a>', $title{'gtf'}, $ftp_base, $sp_dir, $title{'gff3'}, $ftp_base, $sp_dir),
      xrefs   => sprintf('<a rel="external" title="%s" href="%s/tsv/%s">TSV</a> <a rel="external" title="%s" href="%s/rdf/%s">RDF</a> <a rel="external" title="%s" href="%s/json/%s">JSON</a>', $title{'tsv'}, $ftp_base, $sp_dir, $title{'rdf'}, $ftp_base, $sp_dir, $title{'json'}, $ftp_base, $sp_dir),
      mysql   => sprintf('<a rel="external" title="%s" href="%s/mysql/">MySQL</a>',          $title{'mysql'},  $ftp_base),
      var2    => $has_vcf ? sprintf('<a rel="external" title="%s" href="%s/variation/gvf/%s/">GVF</a>', $title{'gvf'}, $ftp_base, $sp_dir) : '-',
      var4    => $has_vcf ? sprintf('<a rel="external" title="%s" href="%s/variation/vcf/%s/">VCF</a>', $title{'vcf'}, $ftp_base, $sp_dir) : '-',
      var3    => sprintf('<a rel="external" title="%s" href="%s/variation/vep/">VEP</a>',    $title{'vep'}, $ftp_base),
      funcgen => $required_lookup->{'funcgen'}{$sp_dir} ? sprintf('<a rel="external" title="%s" href="%s/regulation/%s/">Regulation</a> (GFF)',      $title{'funcgen'}, $ftp_base, $sp_dir) : '-',
      bam     => $databases->{'DATABASE_RNASEQ'}        ? sprintf('<a rel="external" title="%s" href="%s/bamcov/%s/genebuild/">BAM/BigWig</a>',      $title{'bam'},    $ftp_base, $sp_dir) : '-',
      files   => $required_lookup->{'files'}{$sp_dir}   ? sprintf('<a rel="external" title="%s" href="%s/data_files/%s/">Regulation data files</a>', $title{'files'}, $ftp_base, $sp_dir) : '-',
    };

  }

  my $main_table           = EnsEMBL::Web::Document::Table->new($columns, $rows, { data_table => 1, exportable => 0 });
  $main_table->code        = 'FTPtable::'.scalar(@$rows);
  $main_table->{'options'}{'data_table_config'} = {iDisplayLength => 10};
 
  my $multi_table = $self->multi_table($rel, $version, %title);
 
  my $fave_text = '';
  if (scalar @$all_species > 1) {
    $fave_text = $hub->user ? 'Your favourite species are listed first.' 
                  : 'Popular species are listed first. You can customise this list via our <a href="/">home page</a>.'; 
  }

  if ($multi_table) {
    $html .= sprintf('<h3>Multi-species data</h3>%s<h3>Single species data</h3>', $multi_table->render);
  }

  $html .= sprintf(qq{
    <div class="js_panel" id="ftp-table">
      <input type="hidden" class="panel_type" value="Content">
      <p>%s</p>
      %s
    </div>
    %s
    %s
  }, $fave_text, $main_table->render, $self->metadata, $self->add_footnotes);

  return $html;
}


sub get_misc_params {
  my ($self, $ftp, $division) = @_;
  my $species_defs = $self->hub->species_defs;
  my $version;

  if ($division) {
    $version = $species_defs->SITE_RELEASE_VERSION;
  }
  else {
    $version = $species_defs->ORIGINAL_VERSION || $species_defs->ENSEMBL_VERSION;
  }
  my $rel = "release-$version"; # Always set to use the release number rather than current to get around the delay in FTP site links updating

  my $ftp_base = $ftp;
  $ftp_base .= "/$rel";
  $ftp_base .= "/$division" if $division;

  return ($ftp_base, $version, $rel);
}

# Lookup for the types we need for species
sub required_types_for_species {
  my $self = shift;
  my %required_lookup;
  
  # Regulatory build
  $required_lookup{'funcgen'} = { map { $_ => 1 } qw(
    homo_sapiens mus_musculus
  )};
  
  # Funcgen files
  $required_lookup{'files'} = { map { $_ => 1 } qw(
    homo_sapiens mus_musculus
  )};
  
  return \%required_lookup;
}

sub multi_table {
  my ($self, $rel, $version, %title) = @_;
  my $hub = $self->hub;
  my $sd = $hub->species_defs;

  my $ftp_base = $sd->ENSEMBL_FTP_URL;
  unless ($ftp_base =~ /rapid/) {
    $ftp_base .= "/$rel";
  }

  my $multi_table;

  unless ($sd->NO_COMPARA) {
    $multi_table = EnsEMBL::Web::Document::Table->new([
      { key => 'database',  title => 'Database' },
      { key => 'mysql',     title => '', align => 'center' },
      { key => 'emf',       title => '', align => 'center' },
      { key => 'maf',       title => '', align => 'center' },
      { key => 'bed',       title => '', align => 'center' },
      { key => 'xml',       title => '', align => 'center' },
      { key => 'ancestral', title => '', align => 'center' }
    ], [{
      database  => 'Comparative genomics',
      mysql     => sprintf('<a rel="external" title="%s" href="%s/mysql/">MySQL</a>', $title{'mysql'}, $ftp_base),
      emf       => sprintf('<a rel="external" title="%s" href="%s/emf/ensembl-compara/">EMF</a>', $title{'emf'}, $ftp_base),
      maf       => sprintf('<a rel="external" title="%s" href="%s/maf/ensembl-compara/">MAF</a>',$title{'maf'}, $ftp_base),
      bed       => sprintf('<a rel="external" title="%s" href="%s/bed/">BED</a>', $title{'bed'}, $ftp_base),
      xml       => sprintf('<a rel="external" title="%s" href="%s/xml/ensembl-compara/homologies/">XML</a>', $title{'xml'}, $ftp_base),
      ancestral => sprintf('<a rel="external" title="%s" href="%s/fasta/ancestral_alleles">Ancestral Alleles</a>',$title{'ancestral'}, $ftp_base),
    }, {
      database  => 'BioMart',
      mysql     => sprintf('<a rel="external" title="%s" href="%s/mysql/">MySQL</a>',$title{'mysql'}, $ftp_base),
      emf       => '-',
      maf       => '-',
      bed       => '-',
      xml       => '-',
      ancestral => '-',
    }, {
      database  => 'Stable ids',
      mysql     => sprintf('<a rel="external" title="%s" href="%s/mysql/ensembl_stable_ids_%s/">MySQL</a>', $title{'mysql'}, $ftp_base, $version ),
      emf       => '-',
      maf       => '-',
      bed       => '-',
      xml       => '-',
      ancestral => '-',
    }], { cellpadding => 4, cellspacing => 2, id => 'ftp-table1' });
  }

  return $multi_table;
}

sub metadata {}

sub add_footnotes {
  my $self = shift;
  my $hub = $self->hub;
  my $sd = $hub->species_defs;

  my $html = qq(
    <p>
To facilitate storage and download all databases are
<a href="http://directory.fsf.org/project/gzip/" rel="external">GNU
Zip</a> (gzip, *.gz) compressed.
</p>

<h2>About the data</h2>

<p>
The following types of data dumps are available on the FTP site.
</p>

<dl class="twocol striped">
<dt class="bg2">FASTA</dt>
<dd class="bg2">FASTA sequence databases of Ensembl gene, transcript and protein
model predictions. Since the
<a href="http://www.bioperl.org/wiki/FASTA_sequence_format"
rel="external">FASTA format</a> does not permit sequence annotation,
these database files are mainly intended for use with local sequence
similarity search algorithms. Each directory has a README file with a
detailed description of the header line format and the file naming
conventions.
<dl>
  <dt>DNA</dt>
  <dd><a href="http://www.repeatmasker.org/" rel="external">Masked</a>
  and unmasked genome sequences associated with the assembly (contigs,
  chromosomes etc.).</dd>
  <dd>The header line in an FASTA dump files containing DNA sequence
  consists of the following attributes :
  coord_system:version:name:start:end:strand
  This coordinate-system string is used in the Ensembl API to retrieve
  slices with the SliceAdaptor.</dd>

  <dt>CDS</dt>
  <dd>Coding sequences for Ensembl or <i>ab
  initio</i> <a href="https://www.ensembl.org/info/genome/genebuild/">predicted
  genes</a>.</dd>

  <dt>cDNA</dt>
  <dd>cDNA sequences for Ensembl or <i>ab
  initio</i> <a href="https://www.ensembl.org/info/genome/genebuild/">predicted
  genes</a>.</dd>

  <dt>Peptides</dt>
  <dd>Protein sequences for Ensembl or <i>ab
  initio</i> <a href="https://www.ensembl.org/info/genome/genebuild/">predicted
  genes</a>.</dd>


  <dt>RNA</dt>
  <dd>Non-coding RNA gene predictions.</dd>

</dl>

</dd>

<dt class="bg1">Annotated sequence</dt>
<dd class="bg1">Flat files allow more extensive sequence annotation by means of
feature tables and contain thus the genome sequence as annotated by
the automated Ensembl
<a href="https://www.ensembl.org/info/genome/genebuild/">genome
annotation pipeline</a>. Each nucleotide sequence record in a flat
file represents a 1Mb slice of the genome sequence. Flat files are
broken into chunks of 1000 sequence records for easier downloading.
  <dl>

  <dt>EMBL</dt>
  <dd>Ensembl database dumps in <a href="http://www.ebi.ac.uk/ena/about/sequence_format"
  rel="external">EMBL</a> nucleotide
  sequence <a href="http://ftp.ebi.ac.uk/pub/databases/embl/doc/usrman.txt"
  rel="external">database format</a></dd>

  <dt>GenBank</dt>
  <dd>Ensembl database dumps
  in <a href="http://www.ncbi.nlm.nih.gov/genbank/"
  rel="external">GenBank</a> nucleotide sequence
  <a href="http://www.ncbi.nlm.nih.gov/Sitemap/samplerecord.html"
  rel="external">database format</a></dd>

  </dl>

</dd>

<dt class="bg2">MySQL</dt>
<dd class="bg2">All Ensembl <a href="http://www.mysql.com/"
rel="external">MySQL</a> databases are available in text format as are
the SQL table definition files. These can be imported into any SQL
database for a local
<a href="https://www.ensembl.org/info/docs/webcode/mirror/install/">installation</a> of a mirror
site. Generally, the FTP directory tree contains one directory per
database. For more information about these databases and their
Application Programming Interfaces (or APIs) see the
<a href="https://www.ensembl.org/info/docs/api/">API</a> section.</dd>

<dt class="bg1">GTF</dt>
<dd class="bg1">Gene sets for each species. These files include annotations of
both coding and non-coding genes. This file format is
described <a href="http://www.gencodegenes.org/pages/data_format.html">here</a>.
</dd>

<dt class="bg1">GFF3</dt>
<dd class="bg1">GFF3 provides access to all annotated transcripts which make
up an Ensembl gene set. This file format is
described <a href="http://www.sequenceontology.org/gff3.shtml">here</a>.
</dd>

  );

  unless ($sd->NO_COMPARA) {
    $html .= qq(
<dt class="bg2">EMF flatfile dumps (comparative data)</dt>
<dd class="bg2">
<p>
Alignments of resequencing data are available for several species as
Ensembl Multi Format (EMF) flatfile dumps. The accompanying README
file describes the file format.
</p>

<p>
Also, the same format is used to dump whole-genome multiple alignments
as well as gene-based multiple alignments and phylogentic trees used
to infer Ensembl orthologues and paralogues. These files are available
in the ensembl_compara database which will be found in
the <a href="[[SPECIESDEFS::ENSEMBL_FTP_URL]]/current_mysql/">mysql
directory</a>.
</p>
</dd>

<dt class="bg2">MAF (comparative data)</dt>
<dd class="bg2">
<p>
MAF files are provided for all pairwise alignments containing human
(GRCh38), and all multiple alignments.
The MAF file format is described <a href="http://genome.ucsc.edu/FAQ/FAQformat.html#format5">here</a>.
</p>
</dd>
      );
  }

  unless ($sd->NO_VARIATION) {
    $html .= qq(
<dt class="bg1">GVF (variation data)</dt>
<dd class="bg1">GVF (Genome Variation Format) is a simple tab-delimited format derived
from GFF3 for variation positions across the genome.
There are GVF files for different types of variation data (e.g.
somatic variants, structural variants etc). For more information see
the "README" files in the GVF directory.</dd>

<dt class="bg2">VCF (variation data)</dt>
<dd class="bg2">VCF (Variant Call Format) is a text file format containing meta-information lines, a header
line, and then data lines each containing information about a position in the genome. This file format can also contain genotype information on samples for each position.
More details about the format and its specifications are available <a href="http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-41">here</a>.</dd>


<dt class="bg1">VEP (variation data)</dt>
<dd class="bg1">Compressed text files (called "cache files") used by the <a href="/VEP">Variant Effect Predictor</a> tool. More information about these files is available <a href="https://www.ensembl.org/info/docs/tools/vep/script/vep_cache.html">here</a>.</dd>

<dt class="bg2">BED format files (comparative data)</dt>
<dd class="bg2">
<p>
Constrained elements calculated using GERP are available in BED
format. For more information see the accompanying README file.
</p>

<p>
BED format is a simple line-based format. The first 3 mandatory columns
are:
</p>

<ul>
<li>chromosome name (may start with 'chr' for compliance with UCSC)</li>
<li>start position. This is a 0-based position</li>
<li>end position.</li>
</ul>

<p>
<a href="/info/website/upload/bed.html">More information on the BED file format</a>...
</p>
</dd>
      );
  }

  if ($sd->HAS_API_DOCS) {
    $html .= qq(
<dt class="bg1">Tarball</dt>
<dd class="bg1">
<p>
The entire Ensembl API is gzipped and concatenated into a single TAR file. This is updated daily.</p>
</dd>
      );
  }

  $html .= '</dl>';

  return $html;
}

1; 
