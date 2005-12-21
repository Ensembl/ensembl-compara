package EnsEMBL::Web::Component::Transcript;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub tn_external {
  my( $panel, $object ) = @_;
  my $DO = $object->Obj;
  my $data_type;
  my $URL_KEY;
  my $type      = $DO->analysis->logic_name;
  if( $type eq 'GID' ) {
    $data_type = 'GeneID';
    $URL_KEY   = 'TETRAODON_ABINITIO';
  } elsif( $type eq 'GSC' ) {
    $data_type = 'Genscan';
    $URL_KEY   = 'TETRAODON_ABINITIO';
  } else {
    $data_type = 'Genewise';
    $URL_KEY   = 'TETRAODON_GENEWISE';
  }
  $panel->add_row( 'External links',
    qq(<p><strong>$data_type:</strong> @{[$object->get_ExtURL_link( $DO->stable_id, $URL_KEY, $DO->stable_id )]}</p>)
  );
  return 1;
}
sub information {
  my( $panel, $object ) = @_;
  my $label = "Transcript information";
  my $exons     = @{ $object->Obj->get_all_Exons }; 
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;
   
  my $HTML = "<p><strong>Exons:</strong> $exons <strong>Transcript length:</strong> $basepairs bps";
     $HTML .= " <strong>Translation length:</strong> $residues residues" if $residues;
     $HTML .="</p>\n";
  if( $object->gene ) {
     my $gene_id   = $object->gene->stable_id;
     $HTML .= qq(<p>This transcript is a product of gene: <a href="/@{[$object->species]}/geneview?gene=$gene_id;db=@{[$object->get_db]}">$gene_id</a></p>\n);
  }
  $panel->add_row( $label, $HTML );
  return 1;
}

sub additional_info {
  my( $panel, $object ) = @_;
  my $label = "Transcript information";
  my $exons     = @{ $object->Obj->get_all_Exons };
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;
  my $gene_id   = $object->gene->stable_id;

  my $HTML = "<p><strong>Exons:</strong> $exons <strong>Transcript length:</strong> $basepairs bps";
     $HTML .= " <strong>Protein length:</strong> $residues residues" if $residues;
     $HTML .="</p>\n";
  my $species = $object->species();
  my $query_string = "transcript=@{[$object->stable_id]};db=@{[$object->get_db]}";
     $HTML .=qq(<p>[<a href="/$species/transview?$query_string">Further Transcript info</a>] [<a href="/$species/exonview?$query_string">Exon information</a>]);
  if( $residues ) {
     $HTML .=qq( [<a href="/$species/protview?$query_string">Protein information</a>]);
  }
     $HTML .=qq(</p>);
  $panel->add_row( $label, $HTML );
  return 1;
}


sub gkb {
  my( $panel, $transcript ) = @_;
  my $label = 'Genome KnowledgeBase';
  unless ($transcript->__data->{'GKB_links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($transcript->Obj)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }
  return unless $transcript->__data->{'GKB_links'};
  my $GKB_hash = $transcript->__data->{'GKB_links'};

  my $html =  qq( <strong>The following identifiers have been mapped to this entry via Genome KnowledgeBase:</strong><br />);

  my $urls = $transcript->ExtURL;
  $html .= qq(<table cellpadding="4">);
  foreach my $db (sort keys %{$GKB_hash}){
    $html .= qq(<tr><th>$db</th><td><table>);
    foreach my $GKB (@{$GKB_hash->{$db}}){
      my $primary_id = $GKB->primary_id;
      my ($t, $display_id) = split ':', $primary_id ;
      my $description = $GKB->description;
      $html .= '<tr><td>'.$transcript->get_ExtURL_link( $display_id, 'GKB', $primary_id) .'</td>
        <td>'.$description.'</td>
      </tr>';
    }
    $html .= qq(</table></td></tr>)
  }
  $html .= qq(</table>);
  $panel->add_row( $label, $html );
}

sub go {
  my( $panel, $object ) = @_;
  my $label = 'GO';
  unless ($object->__data->{'go_links'}){
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    return unless (@similarity_links);
    _sort_similarity_links($object, @similarity_links);
  }
  return unless $object->__data->{'go_links'};
  my $databases = $object->DBConnection;
  my $goview    = $object->database('go') ? 1 : 0;

  my $go_hash  = $object->get_go_list();
  my $GOIDURL  = "/@{[$object->species]}/goview?acc=";
  my $QUERYURL = "/@{[$object->species]}/goview?depth=2;query=";
  my $URLS     = $object->ExtURL;

  return unless ($go_hash);
  my $html =  qq(<dl>
  <dt><strong>The following GO terms have been mapped to this entry via UniProt:</strong></dt>);

  foreach my $go (sort keys %{$go_hash}){
    my @go_data = @{$go_hash->{$go}||[]};
    my( $evidence, $description ) = @go_data;
    my $link_name = $description;
    $link_name =~ s/ /\+/g;

    my $goidurl  = qq(<a href="$GOIDURL$go">$go</a>);
    my $queryurl = qq(<a href="$QUERYURL$link_name">$description</a>);
    unless( $goview ){
      $goidurl  = $object->get_ExtURL_link($go,'GO',$go);
      $queryurl = $object->get_ExtURL_link($description,'GOTERMNAME', $link_name);
    }
    $html .= qq(<dd>$goidurl [$queryurl] <code>$evidence</code></dd>\n);
  }
  $html .= qq(</dl>);
  $panel->add_row( $label, $html );
}

sub similarity_matches {
  my( $panel, $transcript ) = @_;
  my $label = $transcript->species_defs->translate( 'Similarity Matches' );# shift || 'Similarity Matches';
  my $trans = $transcript->transcript;
  # Check cache
  unless ($transcript->__data->{'similarity_links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($trans)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }

  my @links = @{$transcript->__data->{'similarity_links'}};
  return unless @links;

  my $db = $transcript->get_db();
  my $entry = $transcript->gene_type || 'Ensembl';

    # add table call here
  my $html;
  unless ($transcript->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  }
  $html .= qq(<table cellpadding="4">);
  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }    
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);
  $panel->add_row( $label, $html );
}

sub _sort_similarity_links{
  my $object = shift;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;
  # @ice names    
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name || 
    $a->display_id      cmp $b->display_id
  } @similarity_links ) { 
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs   
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    if( $externalDB eq "GO" ){ #&& $object->database('go')){
      push @{$object->__data->{'go_links'}} , $display_id;
      next;   
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'GKB_links'}->{$key}} , $type ;
      next;
    }
   my $text = $display_id;
    if( $urls and $urls->is_linked( $externalDB ) ) {
      my $link;
      $link = $urls->get_url( $externalDB, $primary_id );
      my $word = $display_id;
      if( $externalDB eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';            
      $join_links = 1;    
    }
    if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) && 
      ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {  
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
      $text .= sprintf( ' [<a href="/%s/alignview?transcript=%s;sequence=%s;db=%s">align</a>] ',
                  $object->species, $object->stable_id, $seq_arg, $db );
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link            
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $join_links  ) {
      $text = qq(\n  <div>$text</div>); 
    } else {
      $text = qq(\n  <div class="multicol">$text</div>); 
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      $text = "\n".'  <div class="multicol"><a href="' .$urls->get_url('AFFY_FASTAVIEW', $display_id) .'">'. $display_id. '</a></div>';
    }
    push @links, [ $type->db_display_name, $text ] ;
  }
  $object->__data->{'similarity_links'} = \@links ;
  return $object->__data->{'similarity_links'};
}

sub family {
  my( $panel, $object ) = @_;
  my $pepdata  = $object->translation_object;
  return unless $pepdata;
  my $families = $pepdata->get_family_links($pepdata);
  return unless %$families;

  my $label = 'Protein Family';
  my $html;
  foreach my $family_id (keys %$families) {
    my $family_url   = "/@{[$object->species]}/familyview?family=$family_id";
    my $family_count = $families->{$family_id}{'count'};
    my $family_desc  = $families->{$family_id}{'description'};
    $html .= qq(<p>
      <a href="$family_url">$family_id</a> : $family_desc<br />
            This cluster contains $family_count Ensembl gene member(s)</p>);
  }
  $panel->add_row( $label, $html );
}

sub interpro {
  my( $panel, $object ) = @_;
  my $trans         = $object->transcript;
  my $pepdata       = $object->translation_object;
  return unless $pepdata;
  my $interpro_hash = $pepdata->get_interpro_links( $trans );
  return unless (%$interpro_hash);
  my $label = 'InterPro';
# add table call here
  my $html = qq(<table cellpadding="4">);
  for my $accession (keys %$interpro_hash){
    my $interpro_link = $object->get_ExtURL_link( $accession, 'INTERPRO',$accession);
    my $desc = $interpro_hash->{$accession};
    $html .= qq(
  <tr>
    <td>$interpro_link</td>
    <td>$desc - [<a href="/@{[$object->species]}/domainview?domainentry=$accession">View other genes with this domain</a>]</td>
  </tr>);
  }
  $html .= qq( </table> );
  $panel->add_row( $label, $html );
}

sub transcript_structure {
  my( $panel, $transcript ) = @_;
  my $label    = 'Transcript structure';
  my $transcript_slice = $transcript->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!

  my $wuc = $transcript->get_userconfig( 'geneview' );
     $wuc->{'_draw_single_Transcript'} = $transcript->Obj->stable_id;
     $wuc->{'_no_label'} = 'true';
     $wuc->set( 'ruler', 'str', $transcript->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $transcript->default_track_by_gene,'on','on');

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
}

sub transcript_neighbourhood {
  my( $panel, $transcript ) = @_;
  my $label    = 'Transcript neigbourhood';
  my $transcript_slice = $transcript->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!
     $transcript_slice = $transcript_slice->expand( 10e3, 10e3 );
  my $wuc = $transcript->get_userconfig( 'transview' );
     $wuc->{'_no_label'} = 'true';
     $wuc->{'_add_labels'} = 'true';
     $wuc->set( 'ruler', 'str', $transcript->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $transcript->default_track_by_gene,'on','on');

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
     $image->imagemap = 'yes';
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
}

sub protein_features_geneview {
  protein_features( @_, 'nosnps' );
}
sub protein_features {
  my( $panel, $transcript, $snps ) = @_;
  my $label    = 'Protein features';
  my $translation = $transcript->translation_object;
  return undef unless $translation;
  $translation->Obj->{'image_snps'}   = $translation->pep_snps unless $snps eq 'nosnps';
  $translation->Obj->{'image_splice'} = $translation->pep_splice_site( $translation->Obj );
  $panel->_prof( "Got snps and slices for protein_feature....", 1 );

  my $wuc = $transcript->get_userconfig( 'protview' );
  $wuc->container_width( $translation->Obj->length );
  my $image    = $transcript->new_image( $translation->Obj, $wuc, [], 1 );
     $image->imagemap = 'yes';
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
  return 1;
}

sub exonview_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'exonview_options', "/@{[$object->species]}/exonview", 'get' );

  # make array of hashes for dropdown options
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',   'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'exon', 'value' => $object->param('exon') );
  $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->stable_id );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'no',
    'label' => "Flanking sequence at either end of transcript",  'name' => 'flanking',
    'value' => $object->param('flanking')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'no',
    'label' => "Intron base pairs to show at splice sites",  'name' => 'sscon',
    'value' => $object->param('sscon')
  );
  $form->add_element(
    'type' => 'CheckBox',
    'label' => "Show full intronic sequence",  'name' => 'fullseq',
    'value' => 'yes', 'checked' => $object->param('fullseq') eq 'yes'
  );
  $form->add_element(
    'type' => 'CheckBox',
    'label' => "Show exons only",  'name' => 'oexon',
    'value' => 'yes', 'checked' => $object->param('oexon') eq 'yes'
  );
  $form->add_element( 'type' => 'Submit', 'value' => 'Go', 'spanning' => 'center' );
  return $form ;
}

sub exonview_options {
  my ( $panel, $object ) = @_;
  my $label = 'Rendering options';
  my $html = qq(
   <div>
     @{[ $panel->form( 'exonview_options' )->render() ]}
  </div>);

  $panel->add_row( $label, $html );
  return 1;
}

sub spreadsheet_exons {
  my( $panel, $object ) = @_;
  $panel->add_columns(
    {'key' => 'Number', 'title' => 'No.', 'width' => '5%', 'align' => 'center' },
    {'key' => 'exint',  'title' => 'Exon / Intron', 'width' => '20%', 'align' => 'center' },
    {'key' => 'Chr', 'title' => 'Chr', 'width' => '10%', 'align' => 'center' },
    {'key' => 'Strand',     'title' => 'Strand', 'width' => '10%', 'align' => 'center' },
    {'key' => 'Start', 'title' => 'Start', 'width' => '15%', 'align' => 'right' },
    {'key' => 'End', 'title' => 'End', 'width' => '15%', 'align' => 'right' },
    {'key' => 'StartPhase', 'title' => 'Start Phase', 'width' => '15%', 'align' => 'center' },
    {'key' => 'EndPhase', 'title' => 'End Phase', 'width' => '15%', 'align' => 'center' },
    {'key' => 'Length', 'title' => 'Length', 'width' => '10%', 'align' => 'right' },
    {'key' => 'Sequence', 'title' => 'Sequence', 'width' => '20%', 'align' => 'left' } 
  );
  
  my $sscon      = $object->param('sscon') ;            # no of bp to show either side of a splice site
  my $flanking   = $object->param('flanking') || 50;    # no of bp up/down stream of transcript
  my $full_seq   = $object->param('fullseq') eq 'yes';  # flag to display full sequence (introns and exons)
  my $only_exon  = $object->param('oexon')   eq 'yes';
  my $entry_exon = $object->param('exon');

  # display only exons flag
  my $trans = $object->Obj;
  my $coding_start = $trans->coding_region_start;
  my $coding_end = $trans->coding_region_end;
  my @el = @{$trans->get_all_Exons};
  my $strand   = $el[0]->strand;
  my $chr_name = $el[0]->slice->seq_region_name;
  my @exon_col = qw(blue black);
  my @back_col = qw(background1 background3);
  my $background = 'background1';
  my( $exonA, $exonB, $j, $upstream, $exon_info,$intron_info );
    $sscon = 25 unless $sscon >= 1;
# works out length needed to join intron ends with dots
  my $sscon_dot_length = 60-2*($sscon %30);
  my $flanking_dot_length = 60-($flanking%60);
# upstream flanking seq
  if( $flanking && !$only_exon ){
    my $exon = $el[0];
    if( $strand == 1 ){
      $upstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    } else {
      $upstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    }
    $upstream =  lc(('.'x $flanking_dot_length).$upstream);
    $upstream =~ s/([\.\w]{60})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(5\' upstream sequence),
                   'Sequence' => qq(<font face="courier" color="green">$upstream</font>) };
    $panel->add_row( $exon_info );
  }
  # Loop over each exon
  for( $j=1; $j<= scalar(@el); $j++ ) {
    my( $intron_start, $intron_end, $intron_len, $intron_seq );
    my $col = $exon_col[$j%2];                    #choose exon text colour
    $exonA = $el[$j-1];
    $exonB = $el[$j];

    my $intron_id = "Intron $j-".($j+1)  ;
    my $dots = '.'x $sscon_dot_length;
    my $seq       = uc($exonA->seq()->seq());
    my $seqlen    = length($seq);
    my $exonA_ID  = $exonA->stable_id;
    my $exonA_start   = $exonA->start;
    my $exonA_end     = $exonA->end;
    my $exonB_start   = $exonB->start if $exonB ;
    my $exonB_end     = $exonB->end if $exonB ;
    my $utrspan_start = qq(<span style="color: #9400d3">);  ##set colour of UTR
    my $count = 0;
    my $k = 0;

    # Is this exon entirely UTR?
    if( $coding_end < $exonA_start || $coding_start > $exonA_end ){
      $seq   =~ s/([\.\w]{60})/$1<\/span><br \/>$utrspan_start/g ;
      $seq   .= qq(</span>);
      $seq = "$utrspan_start"."$seq";
    } elsif( $strand eq '-1' ) {
    # Handle reverse strand transcripts.  Yes, this means we have a bunch of
    # duplicated code to handle forward strand.
      my @exon_nt  = split '', $seq;
      my $coding_len =  ($exonA_end) - $coding_start + 1 ;
      my $utr_len =  $exonA_end - $coding_end   ;

      # CDS is within this exon, and we have UTR start and end
      if( $coding_start > $exonA_start &&  $coding_end < $exonA_end ) {
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if( $count == 60 && ($k < $coding_len && $k > $utr_len) ){
            $seq .= "<br />";
            $count =0;
          } elsif( $count == 60 && ($k > $coding_len || $k < $utr_len) ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if( $count == 60 ) {
              $seq .= "<br />";
              $count = 0;
            }
          } elsif( $k == $coding_len ) {
            $seq .= "$utrspan_start";
            if( $count == 60 ) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ) { # exon starts with UTR
        $seq = "";
        for( @exon_nt ){
          if ($count == 60 && ($k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($count == 60 && $k < $coding_len){
            $seq .= "<br />";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ) { # exon ends with UTR
        $seq = $utrspan_start;
        for( @exon_nt ){
          if ($count == 60 && $utr_len > $k ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($count == 60 && $k > $utr_len){
            $seq .= "<br />";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= qq(</span>);
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else{ # entirely coding exon
        $seq =~ s/([\.\w]{60})/$1<br \/>/g ;
      }
    } else { # Handle forward strand transcripts
      my @exon_nt  = split '', $seq;
      my $utr_len =  $coding_start - $exonA_start ;
      my $coding_len =  $seqlen - ($exonA_end - $coding_end)  ;

      # CDS is within this exon, and we have UTR start and end
      if ($coding_start > $exonA_start &&  $coding_end < $exonA_end){
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == 60 && ($k > $utr_len && $k < $coding_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == 60 && ($k < $utr_len || $k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          } elsif ($k == $coding_len) {
            $seq .= "$utrspan_start";
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ){# exon starts with UTR 
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == 60 && ($k > $utr_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == 60 && $k < $utr_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len){
            $seq .= "</span>";
            if( $count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ){ # exon ends with UTR
        $seq = '';
        for (@exon_nt){
          if ($count == 60 && $coding_len > $k ){
            $seq .= "<br />";
            $count =0;
          }elsif ($count == 60 && $k > $coding_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else { # Entirely coding exon.
        $seq =~ s/([\.\w]{60})/$1<br \/>/g ;
      }
    }
    if ($entry_exon && $entry_exon eq $exonA_ID){
      $exonA_ID = "<b>$exonA_ID</b>" ;
    }
    $exon_info = {      'Number'    => $j,
                        'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$exonA_start-$exonA_end;context=100">$exonA_ID</a>),
                        'Chr'       => $chr_name,
                        'Strand'    => $strand,
                        'Start'     => $object->thousandify( $exonA_start ),
                        'End'       => $object->thousandify( $exonA_end ),
                        'StartPhase' => $exonA->phase    >= 0 ? $exonA->phase     : '-',
                        'EndPhase'  => $exonA->end_phase >= 0 ? $exonA->end_phase : '-',
                        'Length'    => $object->thousandify( $seqlen ),
                        'Sequence'  => qq(<font face="courier" color="black">$seq</font>) };
    $panel->add_row( $exon_info );
    if( !$only_exon && $exonB ) {
      eval{
        if($strand == 1 ) { # ...on the forward strand
          $intron_start = $exonA_end+1;
          $intron_end = $exonB_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_start_sscon = $exonA->slice()->subseq( ($intron_start),   ($intron_start)+($sscon-1),  $strand);
            my $seq_end_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        } else { # ...on the reverse strand
          $intron_start = $exonB_end+1;
          $intron_end = $exonA_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_end_sscon = $exonA->slice()->subseq( ($intron_start), ($intron_start)+($sscon-1), $strand);
            my $seq_start_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        }
      }; # end of eval
      $intron_seq =  lc($intron_seq);
      $intron_seq =~ s/([\.\w]{60})/$1<br \/>/g;

      $intron_info = {   'Number'    => "&nbsp;",
                         'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$intron_start-$intron_end;context=100">$intron_id</a>),
                         'Chr'       => $chr_name,
                         'Strand'    => $strand,
                         'Start'     => $object->thousandify( $intron_start ),
                         'End'       => $object->thousandify( $intron_end ),
                         'Length'    => $object->thousandify( $intron_len ),
                         'Sequence'  => qq(<font face="courier" color="blue">$intron_seq</font>)};
      $panel->add_row( $intron_info );
    }
  }     #finished foreach loop
  if( $flanking && !$only_exon ){
    my $exon = $exonB ? $exonB : $exonA;
    my $downstream;
    if( $strand == 1 ){
      $downstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    } else {
      $downstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    }
    $downstream =  lc($downstream). ('.'x $flanking_dot_length);
    $downstream =~ s/([\.\w]{60})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(3\' downstream sequence),
                   'Sequence' => qq(<font face="courier" color="green">$downstream</font>) };
    $panel->add_row( $exon_info );
  }
  return 1;

}


sub marked_up_seq_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'marked_up_seq', "/@{[$object->species]}/transview", 'get' );
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',         'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->stable_id );
  my $show = [
    { 'value' => 'plain',   'name' => 'Exons' },
    { 'value' => 'codons',  'name' => 'Exons and Codons' },
    { 'value' => 'peptide', 'name' => 'Exons, Codons and Translation'}
  ];
  if( $object->species_defs->databases->{'ENSEMBL_VARIATION'} ||
      $object->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
    push @$show, { 'value' => 'snps', 'name' => 'Exons, Codons, Translations and SNPs' };
  }
  push @$show, { 'value'=>'rna', 'name' => 'Exons, RNA information' } if $object->Obj->biotype =~ /RNA/;
  $form->add_element(
    'type' => 'DropDown', 'name' => 'show', 'value' => $object->param('show') || 'plain',
    'values' => $show, 'label' => 'Show the following features:', 'select' => 'select'
  );
  my $number = [{ 'value' => 'on', 'name' => 'Yes' }, {'value'=>'off', 'name'=>'No' }];
  $form->add_element(
    'type' => 'DropDown', 'name' => 'number', 'value' => $object->param('number') || 'off',
    'values' => $number, 'label' => 'Number residues:', 'select' => 'select'
  );
  $form->add_element( 'type' => 'Submit', value => 'Refresh' );
  return $form;
}

sub marked_up_seq {
  my( $panel, $object ) = @_;
  my $label = "Transcript sequence";
  my $HTML = "<pre>@{[ do_markedup_pep_seq( $object ) ]}</pre>";
  my $db        = $object->get_db() ;
  my $stable_id = $object->stable_id;
  my $trans_id  = $object->transcript->stable_id;
  my $show      = $object->param('show');

  my $image_key;
  if( $object->param('show_vega_markup') ) {
    if( $show eq 'codons'){
      $HTML .= qq(<img src="/img/help/transview-key1.png" height="200" width="200" alt="[Key]" border="0" />);
    } elsif( $show eq 'peptide' ) {
      $HTML .= qq(<img src="/img/help/transview-key2.png" height="200" width="200" alt="[Key]" border="0" />);
    } elsif( $show eq 'snps' ){
      $HTML .= qq(<img src="/img/help/transview-key3.png" height="350" width="300" alt="[Key]" border="0" />); 
    }
  } else {
    if( $show eq 'codons' ) {
      $HTML .= qq(<img src="/img/help/transview-key1.gif" height="200" width="200" alt="[Key]" border="0" />);
    } elsif( $show eq 'peptide' ) { 
      $HTML .= qq(<img src="/img/help/transview-key2.gif" height="200" width="200" alt="[Key]" border="0" />);
    } elsif( $show eq 'snps' ) {
      $HTML .= qq(<img src="/img/help/transview-key3.gif" height="350" width="300" alt="[Key]" border="0" />);
    }
  }
  $HTML .= "<div>@{[ $panel->form( 'markup_up_seq' )->render ]}</div>";
  $panel->add_row( $label, $HTML );
  return 1;
}

sub do_markedup_pep_seq {
  my $object = shift;
  my $show = $object->param('show');
  my $number = $object->param('number');
  if( $show eq 'plain' ) {
    my $fasta = $object->get_trans_seq;
    $fasta =~ s/([acgtn\*]+)/'<span style="color: blue">'.uc($1).'<\/span>'/eg;
    return $fasta;
  } elsif( $show eq 'rna' ) {
    my @strings = $object->rna_notation;
    my @extra_array;
    foreach( @strings ) {
      s/(.{60})/$1\n/g;
      my @extra = split /\n/;
      if( $number eq 'on' ) {
        @extra = map { "       $_\n" } @extra;
      } else {
        @extra = map { "$_\n" } @extra;
      }
      push @extra_array, \@extra;
    }

    my @fasta = split /\n/, $object->get_trans_seq;
    my $out = '';
    foreach( @fasta ) {
      $out .= "$_\n";
      foreach my $array_ref (@extra_array) {
        $out .= shift @$array_ref; 
      }
    }
    return $out; 
  }
  my( $cd_start, $cd_end, $trans_strand, $bps ) = $object->get_markedup_trans_seq;
  my $trans  = $object->transcript;
  my $wrap = 60;
  my $count = 0;
  my ($pep_previous, $ambiguities, $previous, $output, $fasta, $peptide)  = '';
  my $pos = 1;
  my $SPACER = $number eq 'on' ? '       ' : '';
  my %bg_color = (  # move to constant MARKUP_COLOUR
    'utr'      => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND0'},
    'c0'       => 'ffffff',
    'c1'       => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND3'},
    'c99'      => 'ffcc99',
    'synutr'   => '00cc00',
    'sync0'    => '99ff99',
    'sync1'    => '99ff96',
    'indelutr' => '9999ff',
    'indelc0'  => '99ccff',
    'indelc1'  => '99ccff',
    'snputr'   => '00cc00',
    'snpc0'    => 'ff9999',
    'snpc1'    => 'ff9999',
  );
  foreach(@$bps) {
    if($count == $wrap) {
      my( $NUMBER, $PEPNUM ) = ('','');
      if($number eq 'on') {
        $NUMBER = sprintf("%6d ",$pos);
        $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start+3)/3) ) : $SPACER ;
        $pos += $wrap;
      }
      $output .= ($show eq 'snps' ? "$SPACER$ambiguities\n" : '' ).
      $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n".
        ( ( $show eq 'snps' || $show eq 'peptide' ) ?
          "$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" : '' );
      $previous='';
      $pep_previous='';
      $count=0;
      $peptide = '';
      $ambiguities = '';
      $fasta ='';
    }
    my $bg = $bg_color{"$_->{'snp'}$_->{'bg'}"};
    my $style = qq(style="color: $_->{'fg'};). ( $bg ? qq( background-color: #$bg;) : '' ) .qq(");
    my $pep_style = '';
    if( $show eq 'snps') {
      if($_->{'snp'} ne '') {
        if( $trans_strand == -1 ) {
          $_->{'alleles'}=~tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
          $_->{'ambigcode'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        }
        $style .= qq( title="Alleles: $_->{'alleles'}");
      }
      if($_->{'aminoacids'} ne '') {
        $pep_style = qq(style="color: #ff0000" title="$_->{'aminoacids'}");
      }
      $ambiguities.=$_->{'ambigcode'};
    }
    if($style ne $previous) {
      $fasta.=qq(</span>) unless $previous eq '';
      $fasta.=qq(<span $style>) unless $style eq '';
      $previous = $style;
    }
    if($pep_style ne $pep_previous) {
      $peptide.=qq(</span>) unless $pep_previous eq '';
      $peptide.=qq(<span $pep_style>) unless $pep_style eq '';
      $pep_previous = $pep_style;
    }
    $count++;
    $fasta.=$_->{'letter'};
    $peptide.=$_->{'peptide'};
  }
  my( $NUMBER, $PEPNUM ) = ('','');
  if($number eq 'on') {
    $NUMBER = sprintf("%6d ",$pos);
    $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start-1)/3 +1) ) : $SPACER ;
    $pos += $wrap;
  }
  $output .= ($show eq 'snps' ? "$SPACER$ambiguities\n" : '' ).
             $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n".
             ( ( $show eq 'snps' || $show eq 'peptide' ) ?
             "$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" : '' );
  return $output;
}

sub supporting_evidence_image {
  my( $panel, $object ) = @_;
  $panel->print( '
    <p>
      The supporting evidence below consists of the sequence matches
      on which the exon predictions were based and are sorted by alignment score.
    </p>' );
  my $evidence   = $object->get_supporting_evidence;
  my $show       = $object->param('showall');
  my $exon_count = $evidence->{ 'transcript' }{'exon_count'};
  my $hits       = scalar(keys %{$evidence->{ 'hits' }});
  if( $exon_count > 100 && !$show ) {
    $panel->print( qq(
    <p>
      The supporting evidence image may take a while to load, please
      <a href="/@{[$object->species]}/exonview?transcript=@{[$object->stable_id]};db=@{[$object->get_db]};showall=1">click here
      to view supporting evidence<a/>.
    </p>) );
    return 1;
  }
  if( $hits > 10 && !$show ){
    $panel->print( qq(
    <p>
      There are a large number of supporting evidence hits for this transcript. Only the
      top ten 10 hits have been shown.
      <a href="/@{[$object->species]}/exonview?transcript=@{[$object->stable_id]};db=@{[$object->get_db]};showall=1">Click to view all $hits
      supporting evidence hits<a/>.
    </p>) );
    my @T = sort keys %{$evidence->{ 'hits' }};
    for(my $i=10;$i<$hits;$i++) {
      delete $evidence->{'hits'}{$T[$i]};
    }  
  }

  my $wuc = $object->get_userconfig( 'exonview' );
    $wuc->container_width( 1200 );
    $wuc->set( 'supporting_evidence', 'hide_hits', 'yes') if $object->param('showall');
    $wuc->set( '_settings', 'width', $object->param('image_width') );
  my $image    = $object->new_image( $evidence, $wuc );
  $image->imagemap = 'yes';

  my $T = $image->render;
  $panel->print( $T );
  return 1;
}

sub spreadsheet_variationTable {
  my( $panel, $object ) = @_;
  my %snps = %{$object->__data->{'transformed'}{'snps'}||[]};
  my @gene_snps = @{$object->__data->{'transformed'}{'gene_snps'}||[]};
  my $tr_start = $object->__data->{'transformed'}{'start'};
  my $tr_end   = $object->__data->{'transformed'}{'end'};
  my $extent   = $object->__data->{'transformed'}{'extent'};
  my $coding_start = $object->__data->{'transformed'}{'coding_start'};
  return unless %snps;
  $panel->add_columns(
    { 'key' => 'ID', 'align' => 'center' },
    { 'key' => 'class', 'align' => 'center' },
    { 'key' => 'alleles', 'align' => 'center' },
    { 'key' => 'ambiguity', 'align' => 'center' },
    { 'key' => 'status', 'align' => 'center' },
    { 'key' => 'chr' , 'align' => 'center' },
    { 'key' => 'pos' , 'align' => 'center' },
    { 'key' => 'snptype', 'title' => 'SNP type', 'align' => 'center' },
    { 'key' => 'aachange', 'title' => 'AA change', 'align' => 'center' },
    { 'key' => 'aacoord',  'title' => 'AA co-ordinate', 'align' => 'center' }
  );
  foreach my $gs ( @gene_snps ) {
    my $raw_id = $gs->[2]->dbID;
    my $ts     = $snps{$raw_id};
    my @validation =  @{ $gs->[2]->get_all_validation_states || [] };
    if( $ts && $gs->[5] >= $tr_start-$extent && $gs->[4] <= $tr_end+$extent ) {
      my $ROW = {
        'ID'        =>  qq(<a href="/@{[$object->species]}/snpview?snp=@{[$gs->[2]->variation_name]};source=@{[$gs->[2]->source]};chr=$gs->[3];vc_start=$gs->[4]">@{[$gs->[2]->variation_name]}</a>),
        'class'     => $gs->[2]->var_class() eq 'in-del' ? ( $gs->[4] > $gs->[5] ? 'insertion' : 'deletion' ) : $gs->[2]->var_class(),
        'alleles'   => $gs->[2]->allele_string(),
        'ambiguity' => $gs->[2]->ambig_code(),
        'status'    => (join( ', ',  @validation ) || "-"),
        'chr'       => $gs->[3],
        'pos'       => $gs->[4]==$gs->[5] ? $gs->[4] :  "$gs->[4]-$gs->[5]",
        'snptype'   => $ts->consequence_type,
        $ts->translation_start ? (
           'aachange' => $ts->pep_allele_string,
           'aacoord'   => $ts->translation_start.' ('.(($ts->cdna_start-$coding_start)%3+1).')'
        ) : ( 'aachange' => '-', 'aacoord' => '-' )
      };
      $panel->add_row( $ROW );
    }
  }
  return 1;
}

# Transcript Strain View ###################
sub transcriptstrainview { 
  my( $panel, $object, $do_not_render ) = @_;
  my $trans_stable_id = $object->stable_id;

  # Get 4 configs (one for each section) set width to width of context config
  my $image_width  = $object->param( 'image_width' );
  my $wuc          = $object->user_config_hash( 'TSV_transcript' );
  $wuc->{'_draw_single_Transcript'} = $trans_stable_id;

  my $Configs;
  foreach (qw(context transcript transcripts_bottom transcripts_top ) ) {
    $Configs->{$_} = $object->user_config_hash( "TSV_$_" );
    $Configs->{$_}->set( '_settings', 'width',  $image_width );
    $Configs->{$_}->{'id'} = $trans_stable_id;
  }

    $Configs->{"snps"} = $object->user_config_hash( "genesnpview_snps" );
    $Configs->{"snps"}->set( '_settings', 'width',  $image_width );

  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $context      = $object->param( 'context' );
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  foreach my $slice (
    [ 'context',           'normal', '500%'  ],
    [ 'transcript',        'normal', '133%'  ],
    [ 'straintranscripts', 'munged', $extent ],
  ) {
    $object->__data->{'slices'}{ $slice->[0] } =  $object->get_transcript_slices( $wuc, $slice ) || warn "Couldn't get slice";
  }


  my $transcript_slice = $object->__data->{'slices'}{'straintranscripts'}[1];
  my $sub_slices       = $object->__data->{'slices'}{'straintranscripts'}[2];
  my $fake_length      = $object->__data->{'slices'}{'straintranscripts'}[3];


  my %valids = ();    ## Now we have to create the snp filter....
  foreach( $object->param() ) {
    $valids{$_} = 1 if $_=~/opt_/ && $object->param( $_ ) eq 'on';
  }

  my $pop_adaptor = $object->Obj->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my @strains = map {$_->name} @{ $pop_adaptor->fetch_all_strains() };
  my @containers_and_configs = (); ## array of containers and configs

  #my $strain_information = {};

  foreach my $strain ( $object->param('strain') || @strains ) { #e.g. DBA/2J
    my $strain_slice = $transcript_slice->get_by_strain( $strain );
    $object->__data->{'slices'}{ $strain }= [ 'munged', $strain_slice , $sub_slices, $fake_length ];

    ## Initialize content...
    my $CONFIG = $object->get_userconfig( "TSV_straintranscript" );
    $CONFIG->{'id'}         = $object->stable_id;
    $CONFIG->{'subslices'}  = $sub_slices;
    $CONFIG->{'extent'}     = $extent;
    #$CONFIG->{'snps'}     = $snps;

    ## Now we need to map the transcript...

################################# THIS IS THE SAME TRANSCRIPT SO SIMPLIFY!!! ##
    foreach my $transcript ( @{$strain_slice->get_all_Transcripts} ) {
      if( $transcript->stable_id eq $trans_stable_id ) { ## This is our transcripts...
        my $raw_coding_start = defined( $transcript->coding_region_start ) ? $transcript->coding_region_start : $transcript->start;
        my $raw_coding_end   = defined( $transcript->coding_region_end )   ? $transcript->coding_region_end : $transcript->end;
        my $coding_start = $raw_coding_start + $object->munge_gaps( 'straintranscripts', $raw_coding_start );
        my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'straintranscripts', $raw_coding_end );
        my $raw_start = $transcript->start;
        my $raw_end   = $transcript->end  ;
        my @exons = ();
        foreach my $exon (@{$transcript->get_all_Exons()}) {
          my $es = $exon->start;
          my $offset = $object->munge_gaps( 'straintranscripts', $es );
          push @exons, [ $es + $offset, $exon->end + $offset, $exon ];
        }
        #$strain_information->{$strain}->{'exons'}        = \@exons;
        #$strain_information->{$strain}->{'coding_start'} = $coding_start;
        #$strain_information->{$strain}->{'coding_end'}   = $coding_end;
        #$strain_information->{$strain}->{'start'}        = $raw_start;
        #$strain_information->{$strain}->{'end'}          = $raw_end;

	my $allele_info = $object->getAllelesOnSlice("straintranscripts", \%valids, $strain_slice);

	my $consequences = $object->transcript_alleles(\%valids, $allele_info);
	$CONFIG->{'transcript'} = {
	  'strain'       => $strain,
          'exons'        => \@exons,  
          'coding_start' => $coding_start,
          'coding_end'   => $coding_end,
          'transcript'   => $transcript,
          'allele_info'  => $allele_info,
	  'consequences' => $consequences,
				  };
        $CONFIG->container_width( $fake_length );
        last;
      }
      ## Finally the variation features (and associated transcript_variation_features )...  Not sure exactly which call to make on here to get 
    }
    ## Now push onto config hash...
    if( $object->seq_region_strand < 0 ) {

      push @containers_and_configs,    $strain_slice, $CONFIG;
    } else { ## If forward strand we have to draw these in reverse order (as forced on -ve strand)
      unshift @containers_and_configs, $strain_slice, $CONFIG;
    }
  }

  #$Configs->{'context'}->{'transcriptid2'} = $trans_stable_id;     ## Only skip background stripes...
  #$Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
 # $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");

  ## Transcript block in normal co-ordinates....
  #$Configs->{'transcript'}->{'transcriptid'}      = $trans_stable_id;
  #$Configs->{'transcript'}->container_width( $object->__data->{'slices'}{'transcript'}[1]->length() );


  # Taken out domains (prosite, pfam)

  ## -- Tweak the configurations for the five sub images ------------------ 
  ## Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  my @ens_exons;
  foreach my $exon (@{ $object->Obj->get_all_Exons() }) {
    my $offset = $transcript_slice->start -1;
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps( 'straintranscripts', $es );
    push @ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }


  # -- Map SNPs for the last SNP display to fake even spaced co-ordinates
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $snp_fake_length = -1; ## end of last drawn snp on bottom display...
  my $snps = $object->getVariationsOnSlice( "straintranscripts", \%valids, $transcript_slice );

  # @snps: array of arrays containing [fake_start, fake_end, B:E:Variation obj]
  my @snps2;
  @snps2 = map {
    $snp_fake_length +=$SNP_REL+1;
    [ $snp_fake_length - $SNP_REL+1, $snp_fake_length, $_->[2], $transcript_slice->seq_region_name,
      $transcript_slice->strand > 0 ?
      ( $transcript_slice->start + $_->[2]->start - 1,
	$transcript_slice->start + $_->[2]->end   - 1 ) :
      ( $transcript_slice->end - $_->[2]->end     + 1,
	$transcript_slice->end - $_->[2]->start   + 1 )
    ]
  } sort { $a->[0] <=> $b->[0] } @$snps;

  ## Cache data so that it can be retrieved later...
  #     foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
  #       $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
  #     }


  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'transid'}     = $trans_stable_id;
    $Configs->{$_}->{'transcripts'} = [{ 'exons' => \@ens_exons }];
    $Configs->{$_}->{'snps'}        = $snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->container_width( $fake_length );
  }


  # Gene context block;
  #   my $gene_stable_id = $object->stable_id;
  #   $Configs->{'context'}->{'geneid2'} = $gene_stable_id; ## Only skip background stripes...
  $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  # ## Transcript block
  #   $Configs->{'gene'}->{'geneid'}      = $gene_stable_id;
  #   $Configs->{'gene'}->container_width( $object->__data->{'slices'}{'gene'}[1]->length() );

  $Configs->{'snps'}->{'fakeslice'}   = 1;
  $Configs->{'snps'}->{'snps'}        = \@snps2;
  $Configs->{'snps'}->container_width(   $snp_fake_length   );
  return if $do_not_render;

  ## -- Render image ----------------------------------------------------- ##
  # Send the image pairs of slices and configurations
  my $image    = $object->new_image(
    [
     $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
     $object->__data->{'slices'}{'transcript'}[1],  $Configs->{'transcript'},
     $transcript_slice, $Configs->{'transcripts_top'},
     @containers_and_configs,
     $transcript_slice, $Configs->{'transcripts_bottom'},
     $transcript_slice, $Configs->{'snps'},
    ],
    [ $object->stable_id ]
  );
  $image->set_extra( $object );
  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );
  return 0;
}


1;
