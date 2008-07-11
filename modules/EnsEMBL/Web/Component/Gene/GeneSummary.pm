package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self          = shift;
  my $object        = $self->object;
  my $html          = '';
  my $sp            = $object->species_defs->SPECIES_COMMON_NAME;
  my $species       = $object->species;
  my $gene_id       = $object->stable_id;
  my $transcript    = $object->core_objects->transcript;
  my $transcript_id = $transcript->stable_id if $transcript;
  my $location      = sprintf('r=%s:%s-%s', $object->seq_region_name,
                                 $object->seq_region_start, $object->seq_region_end );

## add HGNC synonyms
  my( $display_name, $dbname, $ext_id, $dbname_disp, $info_text ) = $object->display_xref();
  my( $prefix,$name );
  #remove prefix from the URL for Vega External Genes
  if( $species eq 'Homo_sapiens' && $object->source eq 'vega_external' ) {
    ($prefix,$name) = split ':', $display_name;
    $display_name = $name;
  }
  my $linked_display_name = $object->get_ExtURL_link( $display_name, $dbname, $ext_id );
  $linked_display_name = $prefix . ':' . $linked_display_name if $prefix;

  my $site_type = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));
  my ($disp_id_table, $HGNC_table, %syns, %text_info );
  my $disp_syn = 0;
  my $matches = $object->get_database_matches;
  $self->_sort_similarity_links( @$matches );
  my $links = $object->__data->{'links'}{'PRIMARY_DB_SYNONYM'}||[];
  foreach my $link (@$links){
    my ($key, $text)= @$link;
    my $temp = $text;
    $text =~s/\<div\s*class="multicol"\>|\<\/div\>//g;
    $text =~s/<br \/>.*$//gism;
    my @t = split(/\<|\>/, $temp);
    my $id = $t[4];
    my $synonyms = $self->get_synonyms($id, @$matches);
    if( $id =~/$display_name/ ) {
      unless( $synonyms !~/\w/ ) {
        $disp_syn = 1;
        $syns{$id} = $synonyms;
      }
    }
    $text_info{$id} = $text;
    unless( $synonyms !~/\w/ || $id =~/$display_name/ ) {
      $syns{$id} = $synonyms;
    }
  }

  foreach my $k (keys (%text_info)){
    my $syn = $syns{$k};
    my $syn_entry;
    if( $disp_syn ==1 ) {
      my $url = qq(/@{[$object->species]}/Location/Karyotype?db=core;g=$gene_id;$location;id=$display_name;type=Gene);
      $html .= qq( <dt>Synonyms</dt>
      <dd>
      <p>$syn </p></dd><dd><span class="small">To view all $site_type genes linked to the name <a href="$url">click here</a>.</span>
      </dd>);
    }
  }

  warn $linked_display_name; 

## add CCDS info
  if( my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
    my %T = map { $_->primary_id,1 } @CCDS;
     @CCDS = sort keys %T;
     $html .= qq( <dt>CCDS</dt>
      <dd>
      <p> This gene is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }
       </p>
       </dd>);
  }
    

## add prediction method
  my $db = $object->get_db ;
  my $label = ( ($db eq 'vega' or $object->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
  my $text = "No $label defined in database";
  my $o = $object->Obj;
  eval {
  if( $o &&
      $o->can( 'analysis' ) &&
      $o->analysis &&
      $o->analysis->description ) {
    $text = $o->analysis->description;
  } elsif( $object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description ) {
    $text = $object->gene->analysis->description;
  } else {
    my $logic_name = $o->can('analysis') && $o->analysis ? $o->analysis->logic_name : '';
    if( $logic_name ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
      $text = "<strong>FROM CONFIG:</strong> ".$object->species_defs->$confkey;
    }
    if( ! $text ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
      $text   = "<strong>FROM DEFAULT CONFIG:</strong> ".$object->species_defs->$confkey;
    }
  }
  $html .= qq( <dt>$label</dt>
      <dd>
      <p>$text</p>
       </dd>);

  };



 $html .= "</dl>";

 return $html;
}

sub get_synonyms {
  my ( $self, $match_id, @matches ) = @_;
  my $ids;
  foreach my $m (@matches){
    my $dbname = $m->db_display_name;
    my $disp_id = $m->display_id();
    if ( $dbname =~/(HGNC|ZFIN)/ && $disp_id eq $match_id) {
      $ids = "";
      my $synonyms = $m->get_all_synonyms();
      foreach my $syn (@$synonyms){
        $ids = $ids .", " .( ref($syn) eq 'ARRAY' ? "@$syn" : $syn );
      }
    }
  }
  $ids=~s/^\,\s*//;
  my $syns;
  if ($ids =~/^\w/){
    $syns = $ids;
  }
  return $syns;
}


1;
