package EnsEMBL::Web::Component::Variation::ExternalData;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';

  ## first check we have uniquely determined variation
  unless ($object->core_objects->{'parameters'}{'vf'} ){
    $html = "<p>You must select a location from the panel above to see this information</p>";
    return $self->_info(
    'A unique location can not be determined for this Variation',
    $html
    );
  }

  my @data = @{$object->get_external_data};
  unless (scalar @data >= 1) { return "We do not have any external data for this variation";}
  
  my $table_rows = table_data($object, \@data);

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px', });
  $table->add_columns (
    { 'key' => 'disease','title' => 'Disease/Trait', 'align' => 'left'},  
    { 'key' => 'source', 'title' => 'Source', 'align' => 'left'},
    { 'key' => 'study', 'title' => 'Study','align' => 'left'},
    { 'key' => 'genes', 'title' => 'Associated Gene(s)', 'align' => 'left'},
    { 'key' => 'allele', 'title' => 'Strongest risk allele', 'align' => 'left'},
    { 'key' => 'variant', 'title' => 'Associated variant', 'align' => 'left'},
    { 'key' => 'pvalue', 'title' => 'P value', 'align' => 'left'},
  );
 
  foreach my $row (values %$table_rows){
    foreach ( @$row) {
      $table->add_row($_);
    }
  }

  $html .=  $table->render; 
  return $html;
  

};

sub table_data { 
  my ($object, $external_data) = @_;
  my %rows;
  foreach my $va (@$external_data){ 
    my @data_row;
    my $disorder = $va->phenotype_description;
    if (exists $rows{lc ($disorder)}) { 
      @data_row = @{ $rows{lc ($disorder)} };
      $disorder = "";
    }

    my $code = $va->phenotype_name;
    my $disease;
    if ($disorder =~/^\w+/){  $disease = "<dt>$disorder ($code)</dt>"; } 
    my $source = source_link($object, $va, $code);
    my $study = study_link($va->study);
    my $gene = gene_links($object, $va->associated_gene);
    my $allele = $va->associated_variant_risk_allele;
    my $variant_link = variation_link($object, $va->variation->name);
    my $pval = $va->p_value;

    my $row = {
      'disease'     => $disease,
      'source'      => $source,
      'study'       => $study, 
      'genes'       => $gene,
      'allele'      => $allele,
      'variant'     => $variant_link,
      'pvalue'      => $pval,
    };
    push @data_row, $row;
    $rows{lc ($va->phenotype_description)} = \@data_row;
  } 

  return \%rows;
}

sub gene_links {
  my ($object, $data) = @_;
  return unless $data;
  my @genes = split (/,/, $data);
  my @links;
  foreach my $g (@genes){
    if ($g =~/Intergenic/) { push (@links, $g); }
    else { 
      my $url = $object->_url({ 'type' => 'Gene', 'action' => 'Summary', 'g' => $g });
      my $link = "<a href=" .$url.">$g</a>"; 
      push (@links, $link);   
    }
  }
  my $gene_links = join (',', @links); 
  return $gene_links;
}

sub source_link {
  my ($object, $va, $code) = @_;
  my $source = $va->source_name;

  my $url = $object->species_defs->ENSEMBL_EXTERNAL_URLS->{$source};
  if ($url =~/ega/){
    my $ext_id = $va->local_stable_id;
    $url =~s/###ID###/$ext_id/;
    $url =~s/###D###/$code/;
  } elsif ($url =~/gwastudies/){
    my $pubmed_id = $va->study;
    $pubmed_id =~s/pubmed\///; 
    $url =~s/###ID###/$pubmed_id/;       
  }
  my $link = "<a href=".$url.">[$source]</a>";
  return $link;
}

sub study_link {
  my ($study) = @_;
  unless ($study =~/pubmed/){ return; }
  my $link = "<a href=http://www.ncbi.nlm.nih.gov/".$study.">$study</a>";
  return $link;
}

sub variation_link {
  my ($object, $v) = @_;
  my $url = $object->_url({ 'type' => 'Variation', 'action' => 'Summary', 'v' => $v });
  my $link = "<a href=" .$url.">$v</a>";
  return $link;
}

1;
