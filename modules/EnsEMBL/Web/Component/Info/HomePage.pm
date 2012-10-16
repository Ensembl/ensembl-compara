# $Id$

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;

use base qw(EnsEMBL::Web::Component);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $img_url           = $self->img_url;

  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $sound             = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};

  my $html = '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">
      <div class="species-badge">';

  $html .= qq(<img src="${img_url}species/64/$species.png" alt="" title="$sound" />);
  if ($common_name =~ /\./) {
    $html .= qq(<h1>$display_name</h1>);
  }
  else {
    $html .= qq(<h1>$common_name</h1><p>$display_name</p>);
  }
  
  $html .= '</div>'; #close species-badge

  $html .= EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render;

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding no-right-margin">';

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    $html .= '<div class="round-box info-box unbordered">'.$self->_whatsnew_text.'</div>';  
  }

  $html .= '
    </div>
  </div>
</div>
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_assembly_text.'</div>';

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_compara_text.'</div>';

  if ($hub->database('funcgen')) {
    $html .= '<div class="round-box tinted-box unbordered">'.$self->_funcgen_text.'</div>';
  }

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding no-right-margin">';

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_genebuild_text.'</div>';
 
  $html .= '<div class="round-box tinted-box unbordered">'.$self->_variation_text.'</div>';

  $html .= '
    </div>
  </div>
</div>';

  return $html;  
}

sub _whatsnew_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $news_url        = $hub->url({'action'=>'WhatsNew'});

  my $html = sprintf(qq(<h2><a href="%s" title="More release news"><img src="%s24/announcement.png" style="vertical-align:middle" alt="" /></a> What's New in %s release %s</h2>),
                        $news_url,
                        $self->img_url,
                        $species_defs->SPECIES_COMMON_NAME,
                        $species_defs->ENSEMBL_VERSION,
                    );

  if ($species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    my $params = {'release' => $species_defs->ENSEMBL_VERSION, 'species' => $species, 'limit' => 3};
    my @changes = @{$adaptor->fetch_changelog($params)};

    $html .= '<ul>';

    foreach my $record (@changes) {
      my $record_url = $news_url.'#change_'.$record->{'id'};
      $html .= sprintf('<li><a href="%s" class="nodeco">%s</a></li>', $record_url, $record->{'title'});
    }
    $html .= '</ul>';
  }

  return $html;
}

sub _assembly_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;

  my $current_assembly  = $species_defs->ASSEMBLY_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;
  my %archive           = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies        = %{$species_defs->get_config($species, 'ASSEMBLIES')       || {}};
  my $previous          = $current_assembly;

  my $html = '
<div class="homepage-icon">
  ';

  if (@{$species_defs->ENSEMBL_CHROMOSOMES || []}) {
    $html .= qq(
    <a class="nodeco" href="/$species/Location/Genome"><img src="${img_url}96/karyotype.png" class="bordered" /><span>View karyotype</span></a>
    );
  }

  my $region_text = $sample_data->{'LOCATION_TEXT'};
  my $region_url  = $species_defs->species_path.'/Location/View?r='.$sample_data->{'LOCATION_PARAM'};

  $html .= qq(
    <a class="nodeco _ht" href="$region_url" title="$region_text"><img src="${img_url}96/region.png" class="bordered" /><span>Example region</span></a>
  );

  $html .= '
</div>
';

  my $assembly = $species_defs->ASSEMBLY_NAME;
  $html .= "<h2>Genome assembly: $assembly</h2>";

  $html .= qq(<p><a href="/$species/Info/Annotation/#assembly" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More information and statistics</a></p>);
  
  ## Link to FTP site
  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/fasta/%s/dna/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
       $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download DNA sequence</a> (FASTA)</p>);
  }
  ## Link to assembly mapper
  my $mappings = $species_defs->ASSEMBLY_MAPPINGS;
  if ($mappings && ref($mappings) eq 'ARRAY') {
    my $am_url = $hub->url({'type'=>'UserData','action'=>'SelectFeatures'});
    $html .= qq(<p><a href="$am_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Convert your data to $assembly coordinates</a></p>);
  }

  ## PREVIOUS ASSEMBLIES
  my @old_archives;
  ## Insert dropdown list of old assemblies
  foreach my $release (reverse sort keys %archive) {
    next if $release == $ensembl_version;
    next if $assemblies{$release} eq $previous;
    
    push @old_archives, {
      url  => sprintf('http://%s.archive.ensembl.org/%s/', lc $archive{$release}, $species),
      assembly => "$assemblies{$release}",
      release  => (sprintf '(%s release %s)',$species_defs->ENSEMBL_SITETYPE, $release),
    };
    
    $previous = $assemblies{$release};
  }

  ## Combine archives and pre
  my $other_assemblies;
  if (@old_archives) {
    $other_assemblies .= join '', map qq(<li><a href="$_->{'url'}" class="nodeco">$_->{'assembly'}</a> $_->{'release'}</li>), @old_archives;
  }

  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species->{$species}) {
    $other_assemblies .= sprintf('<li><a href="http://pre.ensembl.org/%s/" class="nodeco">%s</a> (Ensembl pre)</li>', $species, $pre_species->{$species}[1]);
  }

  if ($other_assemblies) {
    $html .= qq(
      <h3 style="color:#808080;padding-top:8px">Other assemblies</h3>
      <ul>$other_assemblies</ul>
      );
  }

  return $html;
}

sub _genebuild_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;
  my $vega            = $species_defs->get_config('MULTI', 'ENSEMBL_VEGA');
  my $has_vega        = $vega->{$species};

  my $html = '
<div class="homepage-icon">
  ';

  my $gene_text = $sample_data->{'GENE_TEXT'}; 
  my $gene_url  = $species_defs->species_path.'/Gene/Summary?g='.$sample_data->{'GENE_PARAM'};
  $html .= qq(
    <a class="nodeco _ht" href="$gene_url" title="$gene_text"><img src="${img_url}96/gene.png" class="bordered" /><span>Example gene</span></a>
  );

  my $trans_text = $sample_data->{'TRANSCRIPT_TEXT'}; 
  my $trans_url  = $species_defs->species_path.'/Transcript/Summary?t='.$sample_data->{'TRANSCRIPT_PARAM'};
  $html .= qq(
    <a class="nodeco _ht" href="$trans_url" title="$trans_text"><img src="${img_url}96/transcript.png" class="bordered" /><span>Example transcript</span></a>
  );

  $html .= '
</div>
';

  $html .= '<h2>Gene annotation</h2>
<p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>';

  $html .= qq(<p><a href="/$species/Info/Annotation/#genebuild" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about this genebuild</a></p>);

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/fasta/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download genes, cDNAs, ncRNA, proteins</a> (FASTA)</p>);
  }
  my $im_url = $hub->url({'type'=>'UserData','action'=>'UploadStableIDs'});
  $html .= qq(<p><a href="$im_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Update your old Ensembl IDs</a></p>);

  if ($has_vega) {
    $html .= qq(
  <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">
  <img src="/img/vega_small.gif" alt="Vega logo" style="float:left;margin-right:8px;width:83px;height:30px;vertical-align:center" title="Vega - Vertebrate Genome Annotation database" /></a>
<p>
  Additional manual annotation can be found in <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">Vega</a>
</p>);
  }

  return $html;
}

sub _compara_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;

  my $html = '
<div class="homepage-icon">
  ';
  my $tree_text = $sample_data->{'GENE_TEXT'}; 
  my $tree_url  = $species_defs->species_path.'/Gene/Compara_Tree?g='.$sample_data->{'GENE_PARAM'};
  $html .= qq(
    <a class="nodeco _ht" href="$tree_url" title="$tree_text"><img src="${img_url}96/compara.png" class="bordered" /><span>Example gene tree</span></a>
  );
  $html .= '
</div>
';

  $html .= '<h2>Comparative genomics</h2>
<p><strong>What can I find?</strong>  Homologues, gene trees, and whole genome alignments across multiple species.</p>';
  $html .= qq(<p><a href="/info/docs/compara/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about comparative analysis</a></p>); 

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/emf/ensembl-compara/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version;
    $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download alignments</a> (EMF)</p>);
  }
  return $html;
}

sub _variation_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;

  my $html;

  if ($hub->database('variation')) {
    $html .= '
<div class="homepage-icon">
    ';

    my $var_url  = $species_defs->species_path.'/Variation/Explore?v='.$sample_data->{'VARIATION_PARAM'};
    $html .= qq(
      <a class="nodeco" href="$var_url"><img src="${img_url}96/variation.png" class="bordered" /><span>Example variant</span></a>
    );

    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      my $phen_text = $sample_data->{'PHENOTYPE_TEXT'}; 
      my $phen_url  = $species_defs->species_path.'/Phenotype/Locations?ph='.$sample_data->{'PHENOTYPE_PARAM'};
      $html .= qq(
        <a class="nodeco _ht" href="$phen_url" title="$phen_text"><img src="${img_url}96/phenotype.png" class="bordered" /><span>Example phenotype</span></a>
    );
  }

    $html .= '
</div>
';

    $html .= '<h2>Variation</h2>
<p><strong>What can I find?</strong> Short sequence variants';

    #my $dbsnp = $species_defs->databases->{'DATABASE_VARIATION'}{'dbSNP_VERSION'};
    #if ($dbsnp) {
    #  $html .= " (e.g. from dbSNP $dbsnp)";
    #}

    if ($species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'}) {
      $html .= ' and longer structural variants';
    }
    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      $html .= '; disease and other phenotypes';
    }
    $html .= '.</p>';

    my $site = $species_defs->ENSEMBL_SITETYPE;
    $html .= qq(<p><a href="/info/docs/variation/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about variation in $site</a></p>);

    if ($species_defs->ENSEMBL_FTP_URL) {
      my $ftp_url = sprintf '%s/release-%s/variation/gvf/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
      $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download all variants</a> (GVF)</p>);
    }
  }
  else {
    $html .= '<h2>Variation</h2>
<p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>';
  }

   my $vep_url = $hub->url({'type'=>'UserData','action'=>'UploadVariations'});
    $html .= qq(<p><a href="$vep_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Variant Effect Predictor<img src="${img_url}vep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>);

  return $html;
}

sub _funcgen_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;
  my $site            = $species_defs->ENSEMBL_SITETYPE;
  my $html;

  my $sample_data = $species_defs->SAMPLE_DATA;
  if ($sample_data->{'REGULATION_PARAM'}) {
    $html = '
<div class="homepage-icon">
  ';

    my $reg_url  = $species_defs->species_path.'/Regulation/Cell_line?db=funcgen;rf='.$sample_data->{'REGULATION_PARAM'};
    $html .= qq(
    <a class="nodeco" href="$reg_url"><img src="${img_url}96/regulation.png" class="bordered" /><span>Example regulatory feature</span></a>
  );

    $html .= '
</div>
';

    $html .= '<h2>Regulation</h2>
<p><strong>What can I find?</strong> DNA methylation, transcription factor binding sites, histone modifications, and regulatory features such as enhancers and repressors, and microarray annotations.</p>';

    $html .= qq(<p><a href="/info/docs/funcgen/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site regulatory build</a> and <a href="/info/docs/microarray_probe_set_mapping.html" class="nodeco">microarray annotation</a></p>);

    if ($species_defs->ENSEMBL_FTP_URL) {
      my $ftp_url = sprintf '%s/release-%s/regulation/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
      $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download all regulatory features</a> (GFF)</p>);
    } 
  }
  else {
    $html .= '<h2>Regulation</h2>
<p><strong>What can I find?</strong> Microarray annotations.</p>';
    $html .= qq(<p><a href="/info/docs/microarray_probe_set_mapping.html" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site microarray annotation strategy</a></p>);
  }

  return $html;
}

1;
