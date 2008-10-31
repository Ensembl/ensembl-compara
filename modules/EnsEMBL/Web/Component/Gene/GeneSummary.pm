package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self          = shift;
  my $object        = $self->object;
  my $table         = new EnsEMBL::Web::Document::HTML::TwoCol;

  my $sp            = $object->species_defs->SPECIES_COMMON_NAME;
  my $species       = $object->species;
  my $gene_id       = $object->stable_id;
  my $transcript    = $object->core_objects->transcript;
  my $transcript_id = $transcript->stable_id if $transcript;
  my $location      = sprintf('r=%s:%s-%s', $object->seq_region_name,
                                 $object->seq_region_start, $object->seq_region_end );
    ##add display name
  my( $display_name, $dbname, $ext_id, $dbname_disp, $info_text ) = $object->display_xref();
  my( $prefix,$name );

    #remove prefix from the URL for Vega External Genes
  if( $species eq 'Mus_musculus' && $object->source eq 'vega_external' ) {
    ($prefix,$name) = split ':', $display_name;
    $display_name = $name;
  }
  my $linked_display_name = $object->get_ExtURL_link( $display_name, $dbname, $ext_id );
  $linked_display_name = $prefix . ':' . $linked_display_name if $prefix;

    #add link to source page for projected gene
    #(not sure why this code is here, never seem's to have been used other than to remove hyperlink!)
  if ($dbname_disp =~/^Projected/) {
    $linked_display_name = $display_name; # i.e. don't have a hyperlink
#      if ($info_text) {
#          $info_text =~ /from (.+) gene (.+)/;
#          my ($species, $gene) = ($1, $2);
#          $info_text =~ s|$species|<i>$species</i>| if $species =~ /\w+ \w+/;
#          $species =~ s/ /_/;
#          $info_text =~s|($gene)|<a href="/$species/geneview?gene=$gene">$gene</a> |;
#      }
  }
  $info_text = '';
  if ($linked_display_name) {
    $table->add_row(
      'Name',
      "<p>$linked_display_name ($dbname_disp) $info_text</p>",
      1
    );
  }

    ##add gene name synonyms
  my $site_type = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));
  my ($disp_id_table, $HGNC_table, %syns, %text_info );
  my $disp_syn = 0;
  my $matches = $object->get_database_matches;
  $self->_sort_similarity_links( @$matches );
  my $links = $object->__data->{'links'}{'PRIMARY_DB_SYNONYM'}||[];
  my $show_display_xref = 1;
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
  my $syns;
  foreach my $k (keys (%text_info)){
    my $syn = $syns{$k};
    my $syn_entry;
    if( $disp_syn ==1 ) {
      my $url = qq(/@{[$object->species]}/Location/Genome?db=core;g=$gene_id;$location;id=$display_name;ftype=Gene);
      $syns  .= qq(<p>$syn [<span class="small">To view all $site_type genes linked to the name <a href="$url">click here</a>.</span>]</p></dd>);
    }
}
  if ($syns) {
    $table->add_row(
      'Synonyms',
      "$syns",
      1
    );
  }

  ##add CCDS info
  if( my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
      my %T = map { $_->primary_id,1 } @CCDS;
      @CCDS = sort keys %T;
      $table->add_row('CCDS',
                  "<p>This gene is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }</p>",
                  1);
  }

  my $db = $object->get_db;
  ## add some Vega info
  if( $db eq 'vega' ) {
      # class
      my $type = $object->gene_type;
      $table->add_row('Gene type',
                  qq(<p>$type [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>),
                  1);
      # date
      my $version = $object->version;
      my $c_date = $object->created_date;
      my $m_date = $object->mod_date;
      $table->add_row('Version & date',
                  qq(<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>),
                  1);
      # author
      my $auth  = $object->get_author_name;
      $table->add_row('Author',
                  "This transcript was annotated by $auth");
  }
  else {
    #add gene type
    my $type = $object->gene_type;
    $table->add_row('Gene type',$type) if $type;
  }

  ## add prediction method
    my $label = ( ($db eq 'vega' or $object->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
    my $text = "<p>No $label defined in database</p>";
    my $o = $object->Obj;
    eval {
      if( $o 
          && $o->can( 'analysis' )
            && $o->analysis 
            && $o->analysis->description ) {
          $text = $o->analysis->description;
      } elsif( $object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description ) {
          $text = $object->gene->analysis->description;
      }
      $table->add_row($label,
                  "<p>$text</p>",
                  1);
      };
    return $table->render;
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
