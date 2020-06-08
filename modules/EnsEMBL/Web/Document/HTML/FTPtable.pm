=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
  my $version         = $species_defs->ORIGINAL_VERSION || $species_defs->ENSEMBL_VERSION;
  my $rel             = "release-$version"; # Always set to use the release number rather than current to get around the delay in FTP site links updating

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

  if ($species_defs->HAS_API_DOCS) {
    $html .= qq(
<h2>API Code</h2>

<p>If you do not have access to git, you can obtain our latest API code as a gzipped tarball:</p>

<p><a href="ftp://ftp.ensembl.org/pub/ensembl-api.tar.gz">Download complete API for this release</a></p>

<p>Note: the API version needs to be the same as the databases you are accessing, so please
use git to obtain a previous version if querying older databases.</p>
    );
  }

  my $ftp = $species_defs->ENSEMBL_FTP_URL;
  (my $ftp_domain = $ftp) =~ s/\/pub//;
 
  unless ($species_defs->NO_PUBLIC_MYSQL) { 
    $html .= qq(
<h2>Database dumps</h2>
<p>
Entire databases can be downloaded from our FTP site in a
variety of formats. Please be aware that some of these files
can run to many gigabytes of data.
</p>
<p><strong>Looking for <a href="$ftp/current_mysql/">MySQL dumps</a> to install databases locally?</strong> See our
<a href="https://www.ensembl.org/info/docs/webcode/mirror/install/ensembl-data.html">web installation instructions</a>
for full details.</p>
);
  }

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
  
  $columns = [
    { key => 'fave',    title => 'Favourite',                    align => 'left',   width => '5%',  sort => 'html',
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


  unless ($species_defs->NO_REGULATION) {
    push @$columns, (
    { key => 'funcgen', title => 'Regulation (GFF)',             align => 'center', width => '10%', sort => 'html' },
    { key => 'files',   title => 'Data files',                   align => 'center', width => '10%', sort => 'html' },
    { key => 'bam',     title => 'BAM/BigWig',                          align => 'center', width => '10%', sort => 'html' },
    );
  }

  ## We want favourite species at the top of the table, 
  ## then everything else alphabetically by common name
  my $all_species = [];
  my %fave_check = map {$_ => 1} @{$hub->get_favourite_species};
  foreach (@{$hub->get_favourite_species}) {
    push @$all_species, {
                          'url'         => $species_defs->get_config($_, 'SPECIES_URL'), 
                          'dir'         => $species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME'), 
                          'common_name' => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
                          'sci_name'    => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
                          'favourite'   => 1,
                        };
  }

  my @other_species;
  foreach ($species_defs->valid_species) {
    push @other_species, {
                          'url'         => $species_defs->get_config($_, 'SPECIES_URL'), 
                          'dir'         => $species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME'), 
                          'common_name' => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
                          'sci_name'    => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
                          'favourite'   => 0,
                        }
            unless $fave_check{$_};
  }
  push @$all_species, sort {$a->{'common_name'} cmp $b->{'common_name'}} @other_species;

  my $ftp_base = $ftp;
  unless ($ftp_base =~ /rapid/) {
    $ftp_base .= "/$rel";
  }

  foreach my $sp (@$all_species) {
    my $sp_url    = $sp->{'url'};
    my $sp_dir    = $sp->{'dir'};
    my $sp_var    = $sp_dir. '_variation';
    my $databases = $hub->species_defs->get_config(ucfirst($sp_dir), 'databases');
    my $variation_source_vcf  = $databases->{'DATABASE_VARIATION'}->{'meta_info'}->{0}->{'variation_source.vcf'}->[0];
    
    push @$rows, {
      fave    => $sp->{'favourite'} ? 'Y' : '',
      species => sprintf('<b><a href="/%s/">%s</a></b><br /><i>%s</i>', $sp_url, $sp->{'common_name'}, $sp->{'sci_name'}),
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
      var2    => $databases->{'DATABASE_VARIATION'} && $variation_source_vcf != '1' ? sprintf('<a rel="external" title="%s" href="%s/variation/gvf/%s/">GVF</a>', $title{'gvf'}, $ftp_base, $sp_dir) : '-',
      var4    => $databases->{'DATABASE_VARIATION'} && $variation_source_vcf != '1' ? sprintf('<a rel="external" title="%s" href="%s/variation/vcf/%s/">VCF</a>', $title{'vcf'}, $ftp_base, $sp_dir) : '-',
      var3    => sprintf('<a rel="external" title="%s" href="%s/variation/vep/">VEP</a>',    $title{'vep'},  $ftp_base),
      funcgen => $required_lookup->{'funcgen'}{$sp_dir} ? sprintf('<a rel="external" title="%s" href="%s/regulation/%s/">Regulation</a> (GFF)',      $title{'funcgen'}, $ftp_base, $sp_dir) : '-',
      bam     => $databases->{'DATABASE_RNASEQ'}        ? sprintf('<a rel="external" title="%s" href="%s/bamcov/%s/genebuild/">BAM/BigWig</a>',      $title{'bam'},    $ftp_base, $sp_dir) : '-',
      files   => $required_lookup->{'files'}{$sp_dir}   ? sprintf('<a rel="external" title="%s" href="%s/data_files/%s/">Regulation data files</a>', $title{'files'}, $ftp_base, $sp_dir) : '-',
    };

  }


  my $main_table           = EnsEMBL::Web::Document::Table->new($columns, $rows, { data_table => 1, exportable => 0 });
  $main_table->code        = 'FTPtable::'.scalar(@$rows);
  $main_table->{'options'}{'data_table_config'} = {iDisplayLength => 10};
 
  my $multi_table;
  unless ($species_defs->NO_COMPARA) {
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
      mysql     => qq(<a rel="external" title="$title{'mysql'}" href="/$rel/mysql/">MySQL</a>),
      emf       => qq(<a rel="external" title="$title{'emf'}" href="/$rel/emf/ensembl-compara/">EMF</a>),
      maf       => qq(<a rel="external" title="$title{'maf'}" href="/$rel/maf/ensembl-compara/">MAF</a>),
      bed       => qq(<a rel="external" title="$title{'bed'}" href="/$rel/bed/">BED</a>),
      xml       => qq(<a rel="external" title="$title{'xml'}" href="/$rel/xml/ensembl-compara/homologies/">XML</a>),
      ancestral => qq(<a rel="external" title="$title{'ancestral'}" href="/$rel/fasta/ancestral_alleles">Ancestral Alleles</a>),
    }, {
      database  => 'BioMart',
      mysql     => qq(<a rel="external" title="$title{'mysql'}" href="/$rel/mysql/">MySQL</a>),
      emf       => '-',
      maf       => '-',
      bed       => '-',
      xml       => '-',
      ancestral => '-',
    }, {
      database  => 'Stable ids',
      mysql     => qq(<a rel="external" title="$title{'mysql'}" href="/$rel/mysql/ensembl_stable_ids_$version/">MySQL</a>),
      emf       => '-',
      maf       => '-',
      bed       => '-',
      xml       => '-',
      ancestral => '-',
    }], { cellpadding => 4, cellspacing => 2, id => 'ftp-table1' });
  }
 
  my $fave_text = $hub->user ? 'Your favourite species are listed first.' 
                  : 'Popular species are listed first. You can customise this list via our <a href="/">home page</a>.'; 

  if ($multi_table) {
    $html .= sprintf('<h3>Multi-species data</h3>%s<h3>Single species data</h3>', $multi_table->render);
  }

  $html .= sprintf(qq{
    <div class="js_panel" id="ftp-table">
      <input type="hidden" class="panel_type" value="Content">
      <p>%s</p>
      %s
    </div>
  }, $fave_text, $main_table->render);

  return $html;
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

1; 