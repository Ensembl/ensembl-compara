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

  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;

  my $html = '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';

  $html .= qq(<img src="/i/species/64/$species.png" class="species-img float-left" style="width:64px;height:64px" alt="" />);
  if ($common_name =~ /\./) {
    $html .= qq(<h1>$display_name</h1>);
  }
  else {
    $html .= qq(<h1 style="font-size:2em;margin-bottom:0;">$common_name</h1><p><i>$display_name</i></p>);
  }
  $html .= '<p style="height:1px;clear:both">&nbsp;</p>';
  my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new($hub);
  $html .= $search->render;

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_assembly_text.'</div>';

  $html .= '<p style="height:1px;clear:both">&nbsp;</p>';

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_compara_text.'</div>';  

  $html .= '<p style="height:1px;clear:both">&nbsp;</p>';

  ## Only show regulation box if we have a full regulatory build 
  ## (most funcgen dbs only contain oligoprobe data) 
  my $sample_data = $species_defs->SAMPLE_DATA;
  if ($sample_data->{'REGULATION_PARAM'}) {
    $html .= '<div class="round-box tinted-box unbordered">'.$self->_funcgen_text.'</div>';
  }

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding">';

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) { 
    $html .= '<div class="round-box tinted-box unbordered">'.$self->_whatsnew_text.'</div>';  
    $html .= '<p style="height:1px;clear:both">&nbsp;</p>';
  }

  $html .= '<div class="round-box tinted-box unbordered">'.$self->_genebuild_text.'</div>';  
 
  $html .= '<p style="height:1px;clear:both">&nbsp;</p>';

  if ($hub->database('variation')) {
    $html .= '<div class="round-box tinted-box unbordered">'.$self->_variation_text.'</div>';
  }

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
  my $adaptor         = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);

  my $html = sprintf(qq(<h2><img src="/i/32/announcement.png" style="vertical-align:middle" alt="" /> What's New in %s release %s</h2>),
                        $species_defs->SPECIES_COMMON_NAME,
                        $species_defs->ENSEMBL_VERSION,
                    );

  if ($adaptor) {
    my $params = {'release' => $species_defs->ENSEMBL_VERSION, 'species' => $species, 'limit' => 3};
    my @changes = @{$adaptor->fetch_changelog($params)};

    $html .= '<ul>';

    my $news_url = $hub->url({'action'=>'WhatsNew'});

    foreach my $record (@changes) {
      my $record_url = $news_url.'#change_'.$record->{'id'};
      $html .= sprintf('<li><a href="%s">%s</a></li>', $record_url, $record->{'title'});
    }
    $html .= qq(</ul><p class="right"><a href="$news_url">More release news &gt;&gt;</a></p>);
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
  <div class="center">
  ';

  if (@{$species_defs->ENSEMBL_CHROMOSOMES || []}) {
    $html .= qq(
    <a href="/$species/Location/Genome"><img src="$img_url/96/karyotype.png" class="bordered" /></a>
    <p><a href="/$species/Location/Genome" class="nodeco">View karyotype</a></p>
    );
  }

  my $region_text = $sample_data->{'LOCATION_TEXT'};
  my $region_url  = $species_defs->species_path.'/Location/View?r='.$sample_data->{'LOCATION_PARAM'};

  $html .= qq{
    <a href="$region_url"><img src="$img_url/96/region.png" class="bordered" /></a>
    <p><a href="$region_url" class="nodeco">Example region<br />($region_text)</a></p>
  };

  $html .= '
  </div>
</div>
';

  my $assembly = $species_defs->ASSEMBLY_NAME;
  $html .= '<h2>Genome</h2><ul>';
  $html .= "<li><b>Assembly name</b>: $assembly</li>";

  $html .= sprintf '<li><b>%s</b>: %s</li>', $source_type, $hub->get_ExtURL_link($accession, "ASSEMBLY_ACCESSION_SOURCE_$source", $accession) if $accession; ## Add in GCA link

  $html .= qq(<li><a href="/$species/Info/Annotation/#assembly">More information and statistics</a></li>);
  $html .= '</ul>';
  
  ## Link to FTP site
  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/fasta/%s/dna/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
       $html   .= qq{
<p><a href=$ftp_url"><img src="/i/32/download.png" alt="" style="vertical-align:middle" /></a> <a href="$ftp_url">Download DNA sequence</a> (FASTA)</p>};
  }
  ## Link to assembly mapper
  my $mappings = $species_defs->ASSEMBLY_MAPPINGS;
  if ($mappings && ref($mappings) eq 'ARRAY') {
    my $am_url = $hub->url({'type'=>'UserData','action'=>'SelectFeatures'});
    $html .= qq(<p><a href="$am_url" class="modal_link"><img src="/i/32/tool.png" style="vertical-align:middle" /></a> <a href="$am_url" class="modal_link">Convert your data to $assembly coordinates</a></p>);
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

  if (@old_archives) {
    $html .= sprintf('
      <h3 style="color:#808080">Previous assemblies</h3>
      <ul>%s</ul>
    ', join '', map qq{<li><a href="$_->{'url'}">$_->{'assembly'}</a> $_->{'release'}</li>}, @old_archives);
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

  my $html = '
<div class="homepage-icon">
  <div class="center">
  ';

  my $gene_text = $sample_data->{'GENE_TEXT'}; 
  my $gene_url  = $species_defs->species_path.'/Gene/Summary?g='.$sample_data->{'GENE_PARAM'};
  $html .= qq{
    <a href="$gene_url"><img src="$img_url/96/gene.png" class="bordered" /></a>
    <p><a href="$gene_url" class="nodeco">Example gene<br />($gene_text)</a></p>
  };

  my $trans_text = $sample_data->{'TRANSCRIPT_TEXT'}; 
  my $trans_url  = $species_defs->species_path.'/Transcript/Summary?g='.$sample_data->{'TRANSCRIPT_PARAM'};
  $html .= qq{
    <a href="$trans_url"><img src="$img_url/96/transcript.png" class="bordered" /></a>
    <p><a href="$trans_url" class="nodeco">Example transcript<br />($trans_text)</a></p>
  };

  $html .= '
  </div>
</div>
';

  $html .= '<h2>Gene annotation</h2>';
  $html .= '<p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>';

  $html .= qq(<p><strong>Learn more</strong> about <a href="/$species/Info/Annotation/#genebuild">this genebuild</p>);

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/fasta/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    $html   .= qq{
<p><a href=$ftp_url"><img src="/i/32/download.png" alt="" style="vertical-align:middle" /></a> <a href="$ftp_url">Download genes, cDNAs, ncRNA, proteins</a> (FASTA)</p>};
  }
  my $im_url = $hub->url({'type'=>'UserData','action'=>'UploadStableIDs'});
  $html .= qq(<p><a href="$im_url" class="modal_link"><img src="/i/32/tool.png" style="vertical-align:middle" /></a> <a href="$im_url" class="modal_link">Update your old Ensembl IDs</a></p>);

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
  <div class="center">
  ';
  my $tree_text = $sample_data->{'GENE_TEXT'}; 
  my $tree_url  = $species_defs->species_path.'/Gene/Compara_Tree?g='.$sample_data->{'GENE_PARAM'};
  $html .= qq{
    <a href="$tree_url"><img src="$img_url/96/compara.png" class="bordered" /></a>
    <p><a href="$tree_url" class="nodeco">Example gene tree<br />($tree_text)</a></p>
  };
  $html .= '
  </div>
</div>
';

  $html .= '<h2>Comparative genomics</h2>';
  $html .= '<p><strong>What can I find?</strong>  Homologues, gene trees, and whole genome alignments across multiple species.</p>';
  $html .= '<p><strong>Learn more</strong> about <a href="/info/docs/compara/">comparative analysis</a></li>'; 

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/emf/ensembl-compara/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version;
    $html   .= qq{
<p><a href=$ftp_url"><img src="/i/32/download.png" alt="" style="vertical-align:middle" /></a> <a href="$ftp_url">Download alignments</a> (EMF)</p>};
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

  my $html = '
<div class="homepage-icon">
  <div class="center">
    ';

  my $var_url  = $species_defs->species_path.'/Variation/Explore?v='.$sample_data->{'VARIATION_PARAM'};
  $html .= qq{
    <a href="$var_url"><img src="$img_url/96/variation.png" class="bordered" /></a>
    <p><a href="$var_url" class="nodeco">Example variant</a></p>
  };

  if ($sample_data->{'PHENOTYPE_PARAM'}) {
    my $phen_text = $sample_data->{'PHENOTYPE_TEXT'}; 
    my $phen_url  = $species_defs->species_path.'/Phenotype/Locations?ph='.$sample_data->{'PHENOTYPE_PARAM'};
    $html .= qq{
      <a href="$phen_url"><img src="$img_url/96/phenotype.png" class="bordered" /></a>
      <p><a href="$phen_url" class="nodeco">Example phenotype<br />($phen_text)</a></p>
    };
  }

  $html .= '
  </div>
</div>
';

  $html .= '<h2>Variation</h2>';
  $html .= '<p><strong>What can I find?</strong> Short sequence variants, such as SNPs from dbSNP, mutations from the COSMIC project, longer structural variants from dGVA.  Population frequencies from the 1000 Genomes project, disease and phenotypes associated with variants.</p>';

  my $site = $species_defs->ENSEMBL_SITETYPE;
  $html .= qq(<p><strong>Learn more</strong> about <a href="/info/docs/variation/">variation in $site</p>);

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/variation/gvf/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    $html   .= qq{
<p><a href=$ftp_url"><img src="/i/32/download.png" alt="" style="vertical-align:middle" /></a> <a href="$ftp_url">Download all variants</a> (GVF)</p>};
  }
  my $vep_url = $hub->url({'type'=>'UserData','action'=>'UploadVariations'});
  $html .= qq(<p><a href="$vep_url" class="modal_link"><img src="$img_url/32/tool.png" style="vertical-align:middle" /></a> <a href="$vep_url" class="modal_link">Variant Effect Predictor</a> <a href="$vep_url" class="modal_link"><img src="$img_url/vep_logo_sm.png" style="vertical-align:middle" /></a></p>);

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

  my $html = '
<div class="homepage-icon">
  <div class="center">
  ';
  my $reg_url  = $species_defs->species_path.'/Regulation/Cell_line?db=funcgen;rf='.$sample_data->{'REGULATION_PARAM'};
  $html .= qq{
    <a href="$reg_url"><img src="$img_url/96/regulation.png" class="bordered" /></a>
    <p><a href="$reg_url" class="nodeco">Example regulatory feature</a></p>
  };
  $html .= '
  </div>
</div>
';

  $html .= '<h2>Regulation</h2>';
  $html .= '<p><strong>What can I find?</strong> DNA methylation, Transcription Factor binding sites, Histone modifications, and Regulatory Features based on ENCODE data. Segmentation tracks show regions of the genome implicated as promoters, enhancers, repressors, transcribed regions, etc.</p>';

  my $site = $species_defs->ENSEMBL_SITETYPE;
  $html .= qq(<p><strong>Learn more</strong> about the <a href="/info/docs/funcgen/">$site regulatory build</li>);

  $html .= '</ul>';

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/regulation/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    $html   .= qq{
<p><a href=$ftp_url"><img src="/i/32/download.png" alt="" style="vertical-align:middle" /></a> <a href="$ftp_url">Download all regulatory features</a> (GFF)</p>};
  } 
  return $html;
}

1;
