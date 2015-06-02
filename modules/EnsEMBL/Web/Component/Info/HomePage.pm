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

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;

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
  my $img_url      = $self->img_url;
  my $common_name  = $species_defs->SPECIES_COMMON_NAME;
  my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
  
  $self->{'icon'}     = qq(<img src="${img_url}24/%s.png" alt="" class="homepage-link" />);
  $self->{'img_link'} = qq(<a class="nodeco _ht _ht_track" href="%s" title="%s"><img src="${img_url}96/%s.png" alt="" class="bordered" />%s</a>);
  
  return sprintf('
    <div class="column-wrapper">  
      <div class="box-left">
        <div class="species-badge">
          <img src="%sspecies/64/%s.png" alt="" title="%s" />
          %s
        </div>
        %s
      </div>
      %s
    </div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    %s',
    $img_url, $hub->species, $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'},
    $common_name =~ /\./ ? "<h1>$display_name</h1>" : "<h1>$common_name</h1><p>$display_name</p>",
    EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render,
    $species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'} ? '<div class="box-right"><div class="round-box info-box unbordered">' . $self->whats_new_text . '</div></div>' : '',
    $self->assembly_text,
    $self->genebuild_text,
    $self->compara_text,
    $self->variation_text,
    $hub->database('funcgen') ? '<div class="box-left"><div class="round-box tinted-box unbordered">' . $self->funcgen_text . '</div></div>' : ''
  );
}

sub whats_new_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $news_url     = $hub->url({ action => 'WhatsNew' });

  my $html = sprintf(
    q{<h2><a href="%s" title="More release news"><img src="%s24/announcement.png" style="vertical-align:middle" alt="" /></a> What's New in %s release %s</h2>},
    $news_url,
    $self->img_url,
    $species_defs->SPECIES_COMMON_NAME,
    $species_defs->ENSEMBL_VERSION,
  );

  if ($species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    my $changes = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub)->fetch_changelog({ release => $species_defs->ENSEMBL_VERSION, species => $hub->species, limit => 3 });
    
    $html .= '<ul>';
    $html .= qq(<li><a href="$news_url#change_$_->{'id'}" class="nodeco">$_->{'title'}</a></li>) for @$changes;
    $html .= '</ul>';
    $html .= qq(<div style="text-align:right;margin-top:-1em;padding-bottom:8px"><a href="$news_url" class="nodeco">More news</a>...</div>);
  }

  return $html;
}

sub assembly_text {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
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
      $ftp, lc $species, sprintf($self->{'icon'}, 'download')
    ) : '',
    
    $mappings && ref $mappings eq 'ARRAY' ? sprintf(
      '<p>%s%sConvert your data to %s coordinates</a></p>', ## Link to assembly mapper
      $ac_link, sprintf($self->{'icon'}, 'tool'), $assembly_version
    ) : '',
    
    $hub->url({ type => 'UserData', action => 'SelectFile', __clear => 1 }), sprintf($self->{'icon'}, 'page-user'), $species_defs->ENSEMBL_SITETYPE
  );
  
  ## Insert dropdown list of other assemblies
  if (my $assembly_dropdown = $self->assembly_dropdown) {
    $html .= '<h3 class="light top-margin">Other assemblies</h3>'.$assembly_dropdown;
  }

  return $html;
}

sub genebuild_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ftp          = $self->ftp_url;
  my $vega         = $species_defs->SUBTYPE !~ /Archive|Pre/ && $species_defs->get_config('MULTI', 'ENSEMBL_VEGA') || {};

  return sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>Gene annotation</h2>
    <p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>
    <p><a href="%s" class="nodeco">%sMore about this genebuild</a>%s</p>
    %s
    <p><a href="%s" class="modal_link nodeco" rel="modal_user_data">%sUpdate your old Ensembl IDs</a></p>
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
    
    $hub->database('rnaseq') ? sprintf(', including <a href="%s" class="nodeco">RNASeq gene expression models</a>', $hub->url({'action' => 'Expression'})) : '',

    $ftp ? sprintf(
      '<p><a href="%s/fasta/%s/" class="nodeco">%sDownload genes, cDNAs, ncRNA, proteins</a> (FASTA)</p>', ## Link to FTP site
      $ftp, lc $species, sprintf($self->{'icon'}, 'download')
    ) : '',
    
    $hub->url({ type => 'UserData', action => 'UploadStableIDs', __clear => 1 }), sprintf($self->{'icon'}, 'tool'),
    
    $vega->{$species} ? qq(
      <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">
      <img src="/img/vega_small.gif" alt="Vega logo" style="float:left;margin-right:8px;margin-bottom:1em;width:83px;height:30px;vertical-align:center" title="Vega - Vertebrate Genome Annotation database" /></a>
      <p>Additional manual annotation can be found in <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">Vega</a></p>
    ) : ''
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
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
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
        $ftp, lc $hub->species, sprintf($self->{'icon'}, 'download')
      ) : ''
    );
  } else {
    $html .= '
      <h2>Variation</h2>
      <p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>
    ';
  }

  my $new_vep = $species_defs->ENSEMBL_VEP_ENABLED;
  $html .= sprintf(
    qq(<p><a href="%s" class="%snodeco">$self->{'icon'}Variant Effect Predictor<img src="%svep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>),
    $hub->url({'__clear' => 1, $new_vep ? qw(type Tools action VEP) : qw(type UserData action UploadVariations)}),
    $new_vep ? '' : 'modal_link ',
    'tool',
    $self->img_url
  );

  return $html;
}

sub funcgen_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  
  if ($sample_data->{'REGULATION_PARAM'}) {
    my $species = $hub->species;
    my $ftp     = $self->ftp_url;
    
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
        $ftp, lc $species, sprintf($self->{'icon'}, 'download')
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
