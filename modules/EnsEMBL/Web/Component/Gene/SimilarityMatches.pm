package EnsEMBL::Web::Component::Gene::SimilarityMatches;

use strict;
use warnings;
use EnsEMBL::Web::Document::SpreadSheet;

no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $matches = $self->_matches('similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC', 'LIT');
  my $no_matches = qq(No external references assigned to this gene. Please see the transcript pages for references attached to this gene's transcript(s) and protein(s));  
  my $html = $matches ? $matches : $no_matches;   
  $html.=$self->matches_to_html('MISC', 'LIT');
  return $html;
}

sub matches_to_html{
  my $self=shift;
  my $object=$self->object;
  my $return_html="";
  my @types = @_;
  my $count_ext_refs =0;
  my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], {  data_table => 1, sorting => [ 'transcriptid asc' ]});
  my @colums = ({ key => 'transcriptid' , title => 'Transcript ID' , align => 'left', sort => 'string', priority =>2147483647, display_id=> '', link_text=>''}); #give transcriptid the highest priority as we want it to be the 1st colum
  my %existing_display_names;
  my @rows;
  foreach (@{$object->gene->get_all_Transcripts()}){
    my %url_params = (type     => 'Transcript', action   => 'Summary' , function => undef );
	my $url = $self->object->_url({ %url_params, t => $_->stable_id });	
	$url="<a href=\"".$url."\">".$_->stable_id."</a>";
    my $row= {transcriptid => $url };
    my @transcript_matches = $self->get_matches_by_transcript($_,@types);
    foreach (@transcript_matches){
      my $show_colum = (($object->param($_->db_display_name) ne "off") ? 1:0 ) || 0;
      if($show_colum){
        my %similarity_links=$self->get_similarity_links_hash($_);
        my $ext_db_entry= $similarity_links{'link'} ? "<a href=\"".$similarity_links{'link'}."\">".$similarity_links{'link_text'}."</a>"  :  $similarity_links{'link_text'};
        $row->{$_->db_display_name} =$ext_db_entry ;
        $count_ext_refs++;
        if(! defined($existing_display_names{$_->db_display_name} ) ){
          my $display_name = $self->format_colum_header($_->db_display_name, $similarity_links{'link_text'});
          my $element = { key => $_->db_display_name , title => $display_name, align => 'left', sort => 'string', priority=> $_->priority, display_id => $_->display_id, link_text=>$similarity_links{'link_text'}};
          push(@colums, $element);
          $existing_display_names{$_->db_display_name}=1;
        }
      }
    }
    push(@rows,$row);
  }
  @colums=sort {$b->{priority} <=> $a->{priority} || $a->{title} cmp $b->{title} ||  $a->{'link_text'} cmp $b->{'link_text'} } @colums;
  @rows =sort {keys %{$b} <=> keys %{$a} } @rows; #show rows with the most information first
  $table->add_columns(@colums);   
  $table->add_rows(@rows);
  if ($count_ext_refs==0){
    $return_html.= "<p><strong>No external database identifiers correspond to Transcripts of this Gene:</strong></p>";
  }else{
    $return_html.= "<p><strong>The following database identifier" . (($count_ext_refs>1)?"s":"") ." correspond". (($count_ext_refs>1)?"":"s") . " to Transcripts of this Gene:</strong></p>";
    $return_html.=$table->render;
  }
  
  return $return_html;
}

sub format_colum_header{
  my $self=shift;
  my $colum_header=shift;
  my $value=shift;
  $colum_header =~ s/\//\/ /; # add a space after a /, which enables the table haeader to split the name into multiple lines if needed.
  my @header_segments = split(/ /, $colum_header);
  foreach (@header_segments){
    if(length($value)< length($_)){
      $_=substr($_,0,length($value)-1) ."- <br/>".$self->format_colum_header(substr($_,length($value)-1,length($_)),$value)
    }
  }
  $colum_header='';
  foreach(@header_segments){
    $colum_header.=$_." ";
  }
  return $colum_header;
}

sub get_matches_by_transcript{
  my $self=shift;
  my $transcript=shift;
  my @types=@_;  
  my %allowed_types;
  foreach(@types){
    $allowed_types{$_}=1;
  }
  my $DBLINKS;
   eval { 
    $DBLINKS = $transcript->get_all_DBLinks;
  };
  my @return_links;
  foreach (@$DBLINKS){
    if(defined($allowed_types{$_->type} )){ 
      $_->{'transcript'}=$transcript;
      push(@return_links,$_);
    }
  }
  return @return_links;
}

sub get_similarity_links_hash {
   my $self = shift;
   my $type = shift ;#@similarity_links = @_;
   my $object = $self->object;
   my $urls = $object->ExtURL;
   my $fv_type  = $object->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
   my %similarity_links;
   my $externalDB = $type->database;
   my $display_id = $type->display_id;
   my $primary_id = $type->primary_id;

   #hack for LRG in e58
   if ( $externalDB eq 'ENS_LRG_gene') {
     $primary_id =~ s/_g\d*$//;
   };
   
   next if $type->status eq 'ORTH';                            # remove all orthologs
   next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
   next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
   next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
   next if $externalDB eq 'Vega_transcript';
   next if $externalDB eq 'Vega_translation';
   next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs   
     
   my $text = $display_id;

   (my $A = $externalDB) =~ s/_predicted//;
   $similarity_links{'link'}=$urls->get_url($A, $primary_id) if ($urls and $urls->is_linked($A));
   $similarity_links{'link_text'}=$A eq 'MARKERSYMBOL'?" ($primary_id)":$display_id;

   if ($object->species_defs->ENSEMBL_PFETCH_SERVER
   && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i) {
     my $seq_arg = $display_id;
     $seq_arg = "LL_$seq_arg" if $externalDB eq 'LocusLink';
     my $url= $self->hub->url({
     type => 'Transcript',
     action => 'Similarity/Align',
     sequence => $seq_arg,
     extdb    => lc($externalDB),
     });
     $similarity_links{'align_url'}=$url;
   }
   $similarity_links{'search_go_link'}=$urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;     
  
    # add link to featureview
    ## FIXME - another LRG hack! 
    my $all_locations_url;
    if ($externalDB eq 'ENS_LRG_gene') {
      $all_locations_url = $self->hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });
    }else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type : "${fv_type}_$externalDB";
      $all_locations_url = $self->hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
    }
    $similarity_links{'all_locations_url'}=$all_locations_url;
    return %similarity_links;
}
1;