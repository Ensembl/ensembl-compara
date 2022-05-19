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

package EnsEMBL::Web::Component::Info;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
use EnsEMBL::Web::Utils::Bioschemas qw(create_bioschema add_species_bioschema);

use parent qw(EnsEMBL::Web::Component);

sub ftp_url {
### Set this via a function, so it can easily be updated (or 
### overridden in a plugin)
  my $self = shift;
  my $ftp_site = $self->hub->species_defs->ENSEMBL_FTP_URL;
  return $ftp_site ? sprintf '%s/release-%s', $ftp_site, $self->hub->species_defs->ENSEMBL_VERSION
                      : undef;
}

sub assembly_dropdown {
  my $self              = shift;
  my $hub               = $self->hub;
  my $adaptor           = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my $species           = $hub->species;
  my $archives          = $adaptor->fetch_archives_by_species($species);
  my $species_defs      = $hub->species_defs;
  my $pre_species       = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  my $done_assemblies   = { map { $_ => 1 } $species_defs->ASSEMBLY_NAME, $species_defs->ASSEMBLY_VERSION };

  my @assemblies;

  foreach my $version (reverse sort {$a <=> $b} keys %$archives) {

    my $archive           = $archives->{$version};
    my $archive_assembly  = $archive->{'version'};

    if (!$done_assemblies->{$archive_assembly}) {

      my $desc      = $archive->{'description'} || sprintf '(%s release %s)', $species_defs->ENSEMBL_SITETYPE, $version;
      my $subdomain = ((lc $archive->{'archive'}) =~ /^[a-z]{3}[0-9]{4}$/) ? lc $archive->{'archive'}.'.archive' : lc $archive->{'archive'};

      push @assemblies, {
        url      => sprintf('//%s.ensembl.org/%s/', $subdomain, $species),
        assembly => $archive_assembly,
        release  => $desc,
      };

      $done_assemblies->{$archive_assembly} = 1;
    }
  }

  ## Don't link to pre site on archives, as it changes too often
  push @assemblies, { url => "//pre.ensembl.org/$species/", assembly => $pre_species->{$species}[1], release => '(Ensembl pre)' } if ($pre_species->{$species} && $species_defs->ENSEMBL_SITETYPE !~ /archive/i);

  my $html = '';

  if (scalar @assemblies) {
    if (scalar @assemblies > 1) {
      $html .= qq(<form action="#" method="get" class="_redirect"><select name="url">);
      $html .= qq(<option value="$_->{'url'}">$_->{'assembly'} $_->{'release'}</option>) for @assemblies;
      $html .= '</select> <input type="submit" name="submit" class="fbutton" value="Go" /></form>';
    } else {
      $html .= qq(<ul><li><a href="$assemblies[0]{'url'}" class="nodeco">$assemblies[0]{'assembly'}</a> $assemblies[0]{'release'}</li></ul>);
    }
  }

  return $html;
}

sub include_bioschema_datasets {
  my $self = shift;
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;
  my $catalog_id = $species_defs->BIOSCHEMAS_DATACATALOG;
  return unless $catalog_id;

  my $datasets = [];

  my $sitename = $species_defs->ENSEMBL_SITETYPE;
  my $server = $species_defs->ENSEMBL_SERVERNAME;
  $server = 'https://'.$server unless ($server =~ /^http/);

  my $display_name = $species_defs->SPECIES_DISPLAY_NAME;
  my $sci_name     = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $accession    = $species_defs->ASSEMBLY_ACCESSION;

  ## IMPORTANT: description must be at least 50 characters, so make species name as long as possible 
  my $long_name = sprintf '%s (%s)', $sci_name, $accession; 

  ## License must be an object or URL
  my $license = 'https://www.apache.org/licenses/LICENSE-2.0';

  ## Assembly
  my $annotation_url = sprintf '%s/%s/Info/Annotation', $server, $hub->species;
  my $ftp_url = sprintf '%s/fasta/%s/dna/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
  my $assembly = {
      '@type'                 => 'Dataset',
      'name'                  => sprintf('%s Assembly', $display_name),
      'includedInDataCatalog' => $catalog_id,
      'version'               => $species_defs->ASSEMBLY_NAME,
      'identifier'            => $species_defs->ASSEMBLY_ACCESSION,
      'description'           => "Current Ensembl genome assembly for $long_name",
      'keywords'              => 'dna, sequence',
      'url'                   => $annotation_url,
      'distribution'          => [{
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf('%s %s FASTA files', $sci_name, $species_defs->ASSEMBLY_VERSION),
                                  'description' => sprintf('Downloads of %s sequence in FASTA format', $long_name),
                                  'fileFormat'  => 'fasta',
                                  'encodingFormat' => 'text/plain',
                                  'contentURL'  => $ftp_url,
      }],
      'license'               => $license, 
  };
  add_species_bioschema($species_defs, $assembly);
  push @$datasets, $assembly;

  ## Genebuild
  my $gtf_url   = sprintf '%s/gtf/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
  my $gff3_url  = sprintf '%s/gff3/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
  my $genebuild = {
      '@type'                 => 'Dataset',
      '@id'                   => sprintf('%s/%s/Info/Index#gene-set', $server, $hub->species), 
      'http://purl.org/dc/terms/conformsTo' => {
          '@id'   => "https://bioschemas.org/profiles/Dataset/0.3-RELEASE-2019_06_14/",
          '@type' => "CreativeWork"
      },
      'name'                  => sprintf('%s %s Gene Set', $sitename, $display_name),
      'includedInDataCatalog' => $catalog_id,
      'version'               => $species_defs->GENEBUILD_LATEST || $species_defs->GENEBUILD_RELEASE || '',
      'description'           => sprintf('Automated and manual annotation of genes on the %s %s assembly', $species_defs->SPECIES_DISPLAY_NAME, $species_defs->ASSEMBLY_VERSION),
      'keywords'              => 'genebuild, transcripts, transcription, alignment, loci',
      'url'                   => $annotation_url,
      'distribution'          => [
                                  {
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf ('%s %s Gene Set - GTF files', $sci_name, $species_defs->ASSEMBLY_VERSION),
                                  'description' => sprintf('Downloads of %s gene annotation in GTF format', $long_name),
                                  'fileFormat'  => 'gtf',
                                  'encodingFormat' => 'text/plain',
                                  'contentURL'  => $gtf_url,
                                  },
                                  {
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf ('%s %s Gene Set - GFF3 files', $sci_name, $species_defs->ASSEMBLY_VERSION),
                                  'description' => sprintf('Downloads of %s gene annotation in GFF3 format', $long_name),
                                  'fileFormat'  => 'gff3',
                                  'encodingFormat' => 'text/plain',
                                  'contentURL'  => $gff3_url,
                                  },
      ],
      'license'               => $license, 
  };

  if ($species_defs->ANNOTATION_PROVIDER_NAME) {
    $genebuild->{'creator'} = {
      '@type' => 'Organization',
      'name'  => $species_defs->ANNOTATION_PROVIDER_NAME,
    };
  }
  add_species_bioschema($species_defs, $genebuild);
  push @$datasets, $genebuild;

 ## Variation bioschema
  if ($hub->database('variation')) {
    my $gvf_url   = sprintf '%s/variation/gvf/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
    my $variation = {
        '@type'                 => 'Dataset',
        'name'                  => sprintf('%s %s Variation Data', $sitename, $display_name),
        'includedInDataCatalog' => $catalog_id,
        'url'                   => sprintf('%s/info/genome/variation/species/species_data_types.html#sources', $server),
        'description'           => sprintf('Annotation of %s sequence variants from a variety of sources', $display_name),
        'keywords'              => 'SNP, polymorphism, insertion, deletion, CNV, copy number variant',
        'distribution'          => [{
                                    '@type'       => 'DataDownload',
                                    'name'        => sprintf ('%s %s Variants - GVF files', $sci_name, $species_defs->ASSEMBLY_VERSION),
                                    'description' => sprintf('Downloads of %s variation annotation in GVF format', $long_name),
                                    'fileFormat'  => 'gvf',
                                    'encodingFormat' => 'text/plain',
                                    'contentURL'  => $gvf_url,
        }],
        'license'               => $license, 
    };
    add_species_bioschema($species_defs, $variation);
    push @$datasets, $variation;
  }

  ## Regulation bioschema
  my $sample_data  = $species_defs->SAMPLE_DATA;
  if ($sample_data->{'REGULATION_PARAM'}) {
    my $reg_url   = sprintf '%s/regulation/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
    my $regulation = {
        '@type'                 => 'Dataset',
        'name'                  => sprintf('%s %s Regulatory Build', $sitename, $display_name),
        'includedInDataCatalog' => $catalog_id,
        'url'                   => sprintf('%s/info/genome/funcgen/accessing_regulation.html', $server),
        'description'           => sprintf('Annotation of regulatory regions on the %s genome', $long_name),
        'keywords'              => 'expression, epigenomics, enhancer, promoter',
        'distribution'          => [{
                                    '@type'       => 'DataDownload',
                                    'name'        => sprintf ('%s %s Regulatory Features', $sci_name, $species_defs->ASSEMBLY_VERSION),
                                    'description' => sprintf('Downloads of %s regulation annotation in GFF format', $long_name),
                                    'fileFormat'  => 'gff',
                                    'encodingFormat' => 'text/plain',
                                    'contentURL'  => $reg_url,
        }],
        'license'               => $license, 
        'creator'               => {
                                    '@type' => 'Organization',
                                    'name'  => 'Ensembl',
        },
    };
    add_species_bioschema($species_defs, $regulation);
    push @$datasets, $regulation;
  }

  return  scalar(@$datasets) ? create_bioschema($datasets) : '';
}

sub include_more_annotations {
  return '';
}

1;
