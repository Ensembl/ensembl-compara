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

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;

use parent qw(EnsEMBL::Web::Component::Info);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub ftp_url {
### Set this via a function, so it can easily be updated (or 
### overridden in a plugin)
  my $self = shift;
  my $ftp_site = $self->hub->species_defs->ENSEMBL_FTP_URL;
  return $ftp_site ? sprintf '%s/release-%s', $ftp_site, $self->hub->species_defs->ENSEMBL_VERSION
                      : undef;
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $common_name  = $species_defs->SPECIES_COMMON_NAME;
  my $sci_name     = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $img_url      = $self->img_url;
  $self->{'icon'}  = qq(<img src="${img_url}24/%s.png" alt="" class="homepage-link" />);

  $self->{'img_link'} = qq(<a class="nodeco _ht _ht_track" href="%s" title="%s"><img src="${img_url}96/%s.png" alt="" class="bordered" />%s</a>);

  ## BIOSCHEMAS MARKUP
  my $datasets = [];

  ## Don't mark up archives - it will only confuse search engine users
  ## if there are e.g. multiple human gene sets in the results!
  unless ($species_defs->ENSEMBL_SUBTYPE eq 'Archive') { 
    my $catalog_id = 'Ensembl_Genomic_Data'; 
    my $sitename = $species_defs->ENSEMBL_SITETYPE;
    my $server = $species_defs->ENSEMBL_SERVERNAME;
    $server = 'http://'.$server unless ($server =~ /^http/);

    ## Assembly
    my $annotation_url = sprintf '%s/%s/Info/Annotation', $server, $hub->species;
    my $ftp_url = sprintf '%s/fasta/%s/dna/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME;
    my $assembly = {
      '@type'                 => 'Dataset',
      'name'                  => sprintf('%s Assembly', $common_name),
      'includedInDataCatalog' => $catalog_id, 
      'version'               => $species_defs->ASSEMBLY_NAME,
      'identifier'            => $species_defs->ASSEMBLY_ACCESSION,
      'url'                   => $annotation_url,
      'distribution'          => [{
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf ('%s %s FASTA files', $sci_name, $species_defs->ASSEMBLY_VERSION), 
                                  'fileFormat'  => 'fasta',
                                  'contentURL'  => $ftp_url,
      }],
    };
    $self->add_species_bioschema($assembly);
    push @$datasets, $assembly; 

    ## Genebuild
    my $gtf_url   = sprintf '%s/gtf/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME; 
    my $gff3_url  = sprintf '%s/gff3/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME; 
    my $genebuild = {
      '@type'                 => 'Dataset',
      'name'                  => sprintf('%s %s Gene Set', $sitename, $common_name),
      'includedInDataCatalog' => $catalog_id, 
      'version'               => $species_defs->GENEBUILD_LATEST || $species_defs->GENEBUILD_RELEASE || '',
      'url'                   => $annotation_url,
      'distribution'          => [
                                  {
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf ('%s %s Gene Set - GTF files', $sci_name, $species_defs->ASSEMBLY_VERSION), 
                                  'fileFormat'  => 'gtf',
                                  'contentURL'  => $gtf_url,
                                  },
                                  {
                                  '@type'       => 'DataDownload',
                                  'name'        => sprintf ('%s %s Gene Set - GFF3 files', $sci_name, $species_defs->ASSEMBLY_VERSION), 
                                  'fileFormat'  => 'gff3',
                                  'contentURL'  => $gff3_url,
                                  },
      ],
    };
    
    if ($species_defs->PROVIDER_NAME) {
      $genebuild->{'creator'} = {
        '@type' => 'Organization',
        'name'  => $species_defs->PROVIDER_NAME,
      };
    }
    $self->add_species_bioschema($genebuild);
    push @$datasets, $genebuild; 

    ## Variation bioschema
    if ($hub->database('variation')) {
      my $gvf_url   = sprintf '%s/variation/gvf/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME; 
      my $variation = {
        '@type'                 => 'Dataset',
        'name'                  => sprintf('%s %s Variation Data', $sitename, $common_name),
        'includedInDataCatalog' => $catalog_id, 
        'url'                   => sprintf('%s/info/genome/variation/species/species_data_types.html#sources', $server),
        'distribution'          => [{
                                    '@type'       => 'DataDownload',
                                    'name'        => sprintf ('%s %s Variants - GVF files', $sci_name, $species_defs->ASSEMBLY_VERSION), 
                                    'fileFormat'  => 'gvf',
                                    'contentURL'  => $gvf_url,
        }],
      };
      $self->add_species_bioschema($variation);
      push @$datasets, $variation; 
    }

    ## Regulation bioschema
    my $sample_data  = $species_defs->SAMPLE_DATA;
    if ($sample_data->{'REGULATION_PARAM'}) {
      my $reg_url   = sprintf '%s/regulation/%s/', $self->ftp_url, $species_defs->SPECIES_PRODUCTION_NAME; 
      my $regulation = {
        '@type'                 => 'Dataset',
        'name'                  => sprintf('%s %s Regulatory Build', $sitename, $common_name),
        'includedInDataCatalog' => $catalog_id, 
        'url'                   => sprintf('%s/info/genome/funcgen/accessing_regulation.html', $server),
        'distribution'          => [{
                                    '@type'       => 'DataDownload',
                                    'name'        => sprintf ('%s %s Regulatory Features', $sci_name, $species_defs->ASSEMBLY_VERSION), 
                                    'fileFormat'  => 'gff',
                                    'contentURL'  => $reg_url,
        }],
        'creator'               => {
                                    '@type' => 'Organization',
                                    'name'  => 'Ensembl', 
        },
      };
      $self->add_species_bioschema($regulation);
      push @$datasets, $regulation; 
    }
  }

  return sprintf('
    <div class="round-box tinted-box unbordered"><h2>Search %s</h2>%s</div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    %s%s',
    $common_name eq $sci_name ? "<i>$sci_name</i>" : sprintf('%s (<i>%s</i>)', $common_name, $sci_name),
    EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render,
    $self->assembly_text,
    $self->genebuild_text,
    $self->compara_text,
    $self->variation_text,
    $hub->database('funcgen') ? '<div class="box-left"><div class="round-box tinted-box unbordered">' . $self->funcgen_text . '</div></div>' : '',
    scalar(@$datasets) ? $self->add_bioschema($datasets) : ''
  );
}

sub assembly_text {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $species_prod_name = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
  my $sample_data       = $species_defs->SAMPLE_DATA;
  my $ftp               = $self->ftp_url;
  my $assembly          = $species_defs->ASSEMBLY_NAME;
  my $assembly_version  = $species_defs->ASSEMBLY_VERSION;
  my $mappings          = $species_defs->ASSEMBLY_MAPPINGS;
  my $gca               = $species_defs->ASSEMBLY_ACCESSION;
 
  my $ac_link;
  if ($species_defs->ENSEMBL_AC_ENABLED) {
    $ac_link = sprintf('<a href="%s" class="nodeco">', $hub->url({'type' => 'Tools', 'action' => 'AssemblyConverter'}));
  }
  else {
    $ac_link = sprintf('<a href="%s" class="modal_link nodeco" rel="modal_user_data">', $hub->url({'type' => 'UserData', 'action' => 'SelectFeatures', __clear => 1}));
  }

  my $html = sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>Genome assembly: %s%s</h2>
    <p><a href="%s" class="nodeco">%sMore information and statistics</a></p>
    %s
    %s
    <p><a href="%s" class="modal_link nodeco" rel="modal_user_data">%sDisplay your data in %s</a></p>',
    
    scalar @{$species_defs->ENSEMBL_CHROMOSOMES || []} ? sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Location', action => 'Genome', __clear => 1 }),
      'Go to ' . $species_defs->SPECIES_COMMON_NAME . ' karyotype', 'karyotype', 'View karyotype'
    ) : '',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Location', action => 'View', r => $sample_data->{'LOCATION_PARAM'}, __clear => 1 }),
      "Go to $sample_data->{'LOCATION_TEXT'}", 'region', 'Example region'
    ),
    
    $assembly, $gca ? " <small>($gca)</small>" : '',
    $hub->url({ action => 'Annotation', __clear => 1 }), sprintf($self->{'icon'}, 'info'),
    
    $ftp ? sprintf(
      '<p><a href="%s/fasta/%s/dna/" class="nodeco">%sDownload DNA sequence</a> (FASTA)</p>', ## Link to FTP site
      $ftp, $species_prod_name, sprintf($self->{'icon'}, 'download')
    ) : '',
    
    $mappings && ref $mappings eq 'ARRAY' ? sprintf(
      '<p>%s%sConvert your data to %s coordinates</a></p>', ## Link to assembly mapper
      $ac_link, sprintf($self->{'icon'}, 'tool'), $assembly_version
    ) : '',
    
    $hub->url({ type => 'UserData', action => 'SelectFile', __clear => 1 }), sprintf($self->{'icon'}, 'page-user'), $species_defs->ENSEMBL_SITETYPE
  );
 
  my $strains = $species_defs->ALL_STRAINS;

  ## Insert dropdown list of other assemblies
  if (my $assembly_dropdown = $self->assembly_dropdown) {
    my $ref_text = $strains ? 'reference' : '';
    $html .= sprintf '<h3 class="light top-margin">Other %s assemblies</h3>%s', $ref_text, $assembly_dropdown;
  }

  ## Insert link to strains page 
  if ($strains) {
    $html .= sprintf '<h3 class="light top-margin">Other strains</h3><p>This species has data on %s additional strains. <a href="%s">View list of strains</a></p>', 
                            scalar @$strains,
                            $hub->url({'action' => 'Strains'}), 
  }
  
  ## Also look for strains on closely-related species
  my $related_taxon = $species_defs->RELATED_TAXON;
  if ($related_taxon) {

    ## Loop through all species, looking for others in this taxon
    my @related_species;
    foreach $_ ($species_defs->valid_species) {
      next if $_ eq $self->hub->species; ## Skip if current species
      next unless $species_defs->get_config($_, 'ALL_STRAINS'); ## Skip if it doesn't have strains
      next if $species_defs->get_config($_, 'SPECIES_STRAIN'); ## Skip if it _is_ a strain
      ## Finally, check taxonomy
      my $taxonomy = $species_defs->get_config($_, 'TAXONOMY');
      next unless ($taxonomy && ref $taxonomy eq 'ARRAY'); 
      next unless grep { $_ eq $related_taxon } @$taxonomy;
      push @related_species, $_;
    }
  
    if (scalar @related_species) {
      $html .= '<h3 class="light top-margin">Related strains</h3><p>Strain data is now available on the following closely-related species:</p><ul>';
      foreach (@related_species) {
        $html .= sprintf '<li><a href="%s">%s (%s)</a></li>', 
                  $hub->url({'species' => $_, 'action' => 'Strains'}), 
                  $species_defs->get_config($_, 'SPECIES_BIO_NAME'),
                  $species_defs->get_config($_, 'SPECIES_COMMON_NAME');
      }
      $html .= '</ul>';
    }
  }

  return $html;
}

sub genebuild_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $sp_prod_name = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ftp          = $self->ftp_url;
  my $vega         = $species_defs->SUBTYPE !~ /Archive|Pre/ && $species_defs->get_config('MULTI', 'ENSEMBL_VEGA') || {};
  my $idm_link     = $species_defs->ENSEMBL_IDM_ENABLED
    ? sprintf('<p><a href="%s" class="nodeco">%sUpdate your old Ensembl IDs</a></p>', $hub->url({ type => 'Tools', action => 'IDMapper', __clear => 1 }), sprintf($self->{'icon'}, 'tool'))
    : '';

  return sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>Gene annotation</h2>
    <p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>
    <p><a href="%s" class="nodeco">%sMore about this genebuild</a></p>
    %s
    %s
    %s',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Gene', action => 'Summary', g => $sample_data->{'GENE_PARAM'}, __clear => 1 }),
      "Go to gene $sample_data->{'GENE_TEXT'}", 'gene', 'Example gene'
    ),
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Transcript', action => 'Summary', t => $sample_data->{'TRANSCRIPT_PARAM'} }),
      "Go to transcript $sample_data->{'TRANSCRIPT_TEXT'}", 'transcript', 'Example transcript'
    ),
    
    $hub->url({ action => 'Annotation', __clear => 1 }), sprintf($self->{'icon'}, 'info'),
    
    $ftp ? sprintf(
      '<p><a href="%s/fasta/%s/" class="nodeco">%sDownload FASTA</a> files for genes, cDNAs, ncRNA, proteins</p>', ## Link to FTP site
      $ftp, $sp_prod_name, sprintf($self->{'icon'}, 'download')
    ) : '',
    
    $ftp ? sprintf(
      '<p><a href="%s/gtf/%s/" class="nodeco">%sDownload GTF</a> or <a href="%s/gff3/%s/" class="nodeco">GFF3</a> files for genes, cDNAs, ncRNA, proteins</p>', ## Link to FTP site
      $ftp, $sp_prod_name, sprintf($self->{'icon'}, 'download'), $ftp, $sp_prod_name
    ) : '',
    
    $idm_link
  );
}

sub compara_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ftp          = $self->ftp_url;
  
  return sprintf('
    <div class="homepage-icon">
      %s
    </div>
    <h2>Comparative genomics</h2>
    <p><strong>What can I find?</strong>  Homologues, gene trees, and whole genome alignments across multiple species.</p>
    <p><a href="/info/genome/compara/" class="nodeco">%sMore about comparative analysis</a></p>
    %s',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Gene', action => 'Compara_Tree', g => $sample_data->{'GENE_PARAM'}, __clear => 1 }),
      "Go to gene tree for $sample_data->{'GENE_TEXT'}", 'compara', 'Example gene tree'
    ),
    
    sprintf($self->{'icon'}, 'info'),
    
    $ftp ? sprintf(
      '<p><a href="%s/emf/ensembl-compara/" class="nodeco">%sDownload alignments</a> (EMF)</p>', ## Link to FTP site
      $ftp, sprintf($self->{'icon'}, 'download')
    ) : ''
  );
}

sub variation_text {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species_prod_name = $species_defs->get_config($hub->species, 'SPECIES_PRODUCTION_NAME');
  my $html;

  if ($hub->database('variation')) {
    my $sample_data  = $species_defs->SAMPLE_DATA;
    my $ftp          = $self->ftp_url;
       $html         = sprintf('
      <div class="homepage-icon">
        %s
        %s
        %s
      </div>
      <h2>Variation</h2>
      <p><strong>What can I find?</strong> Short sequence variants%s%s</p>
      <p><a href="/info/genome/variation/" class="nodeco">%sMore about variation in %s</a></p>
      %s',
      
      $sample_data->{'VARIATION_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Variation', action => 'Explore', v => $sample_data->{'VARIATION_PARAM'}, __clear => 1 }),
        "Go to variant $sample_data->{'VARIATION_TEXT'}", 'variation', 'Example variant'
      ) : '',
      
      $sample_data->{'PHENOTYPE_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Phenotype', action => 'Locations', ph => $sample_data->{'PHENOTYPE_PARAM'}, __clear => 1 }),
        "Go to phenotype $sample_data->{'PHENOTYPE_TEXT'}", 'phenotype', 'Example phenotype'
      ) : '',
      
      $sample_data->{'STRUCTURAL_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'StructuralVariation', action => 'Explore', sv => $sample_data->{'STRUCTURAL_PARAM'}, __clear => 1 }),
        "Go to structural variant $sample_data->{'STRUCTURAL_TEXT'}", 'struct_var', 'Example structural variant'
      ) : '',
      
      $species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'} ? ' and longer structural variants' : '', $sample_data->{'PHENOTYPE_PARAM'} ? '; disease and other phenotypes' : '',
      
      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE,
      
      $ftp ? sprintf(
        '<p><a href="%s/variation/gvf/%s/" class="nodeco">%sDownload all variants</a> (GVF)</p>', ## Link to FTP site
        $ftp, $species_prod_name, sprintf($self->{'icon'}, 'download')
      ) : ''
    );
  } else {
    $html .= '
      <h2>Variation</h2>
      <p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>
    ';
  }

  if ($species_defs->ENSEMBL_VEP_ENABLED) {
    $html .= sprintf(
      qq(<p><a href="%s" class="nodeco">$self->{'icon'}Variant Effect Predictor<img src="%svep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>),
      $hub->url({'__clear' => 1, qw(type Tools action VEP)}),
      'tool',
      $self->img_url
    );
  }

  return $html;
}

sub funcgen_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  
  if ($sample_data->{'REGULATION_PARAM'}) {
    my $species           = $hub->species;
    my $species_prod_name = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
    my $ftp               = $self->ftp_url;
    
    return sprintf('
      <div class="homepage-icon">
        %s
        %s
      </div>
      <h2>Regulation</h2>
      <p><strong>What can I find?</strong> DNA methylation, transcription factor binding sites, histone modifications, and regulatory features such as enhancers and repressors, and microarray annotations.</p>
      <p><a href="/info/genome/funcgen/" class="nodeco">%sMore about the %s regulatory build</a> and <a href="/info/genome/microarray_probe_set_mapping.html" class="nodeco">microarray annotation</a></p>
      <p><a href="%s" class="nodeco">%sExperimental data sources</a></p>
      %s %s',
      
      sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Regulation', action => 'Summary', db => 'funcgen', rf => $sample_data->{'REGULATION_PARAM'}, __clear => 1 }),
        "Go to regulatory feature $sample_data->{'REGULATION_TEXT'}", 'regulation', 'Example regulatory feature'
      ),
      
      $species eq 'Homo_sapiens' ? '
        <a class="nodeco _ht _ht_track" href="/info/website/tutorials/encode.html" title="Find out about ENCODE data"><img src="/img/ENCODE_logo.jpg" class="bordered" /><span>ENCODE data in Ensembl</span></a>
      ' : '',

      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE,
      
      $hub->url({'type' => 'Experiment', 'action' => 'Sources', 'ex' => 'all'}), sprintf($self->{'icon'}, 'info'), 

      $ftp ? sprintf(
        '<p><a href="%s/regulation/%s/" class="nodeco">%sDownload all regulatory features</a> (GFF)</p>', ## Link to FTP site
        $ftp, $species_prod_name, sprintf($self->{'icon'}, 'download')
      ) : '',
    );
  } else {
    return sprintf('
      <h2>Regulation</h2>
      <p><strong>What can I find?</strong> Microarray annotations.</p>
      <p><a href="/info/genome/microarray_probe_set_mapping.html" class="nodeco">%sMore about the %s microarray annotation strategy</a></p>',
      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE
    );
  }
}

1;
