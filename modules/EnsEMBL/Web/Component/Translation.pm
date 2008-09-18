package EnsEMBL::Web::Component::Translation;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use Data::Dumper;
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities;
use HTML::Parser;
use EnsEMBL::Web::Form;

sub _flip_URL {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $object->species, $object->script, $object->transcript->stable_id, $object->get_db, $code;
}

sub _flip_URL_gene {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?gene=%s;db=%s;%s', $object->species, $object->script, $object->stable_id, $object->get_db, $code;
}

sub das {
 my( $panel, $object ) = @_;
  my $status   = 'status_das_sources';
  my $URL = $object->__objecttype eq 'Gene' ? _flip_URL_gene( $object, $status ) :_flip_URL( $object, $status );
# Get parameters to be passed to dasconfview script
# Now display the annotation from the selected sources
  my $link_tmpl = qq(<a href="%s" target="%s">%s</a>);

# Template for annotations is :
# TYPE (TYPE ID) FEATURE (FEATURE ID) METHOD (METHOD ID) NOTE SCORE
#
# TYPE ID, FEATURE ID and METHOD ID appear only if present and different from
#
# TYPE, FEATURE and METHOD respectively
#
# NOTE and SCORE appear only if there are values present

  my $row_tmpl = qq(
  <tr valign="top">
    <td>%s %s</td>
    <td><strong>%s %s</strong></td>
    <td>%s %s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
  </tr>);

# For displaying the chromosome based features
  my %FLabels = (
    0 => 'Feature contained by gene',
    1 => 'Feature overlaps gene',
    2 => 'Feature overlaps gene',
    3 => 'Feature contains gene',
    4 => 'Feature colocated with gene'
  );


  my $script  = $object->script;
  my $species  = $object->species;
# Get the DAS configuration
  my $das_collection     = $object->get_DASCollection;
  my @das_objs = @{$das_collection->Obj || []} ;

# Use Bio::EnsEMBL::Gene / Translation - so all the features are retrieved by the same function
  my $obj = $object->[1]->{_object};

  my ($featref, $styleref) = $obj->get_all_DAS_Features();

 foreach my $das ( grep {$_->adaptor->active} @das_objs ){
    my $source = $das->adaptor;
    my $source_nm = $source->name;

    my $source_label = $source->label || $source->name;
    my $label = "<a name=$source_nm></a>$source_label";
    if (defined (my $error = $source->verify)) {
      my $msg = qq{Error retrieving features : $error};
      $panel->add_row( $label, qq(<p>$msg</p>) );
#     next; Temp thing to test ArrayExpress images from their dummy source
      next unless ($source_label =~ /aewTest/);
    }

    my $location_features = 0;
    my @rhs_rows = ();
# in protview we display features with location in the image, in geneview there is no image - so we put text
# really need to rethink it !

    if( $source->type =~ /^ensembl_location/ && $obj->isa('Bio::EnsEMBL::Gene') ) {
      my $slice = $object->get_Slice();
      my $slice_length = $slice->end - $slice->start;

# Filter out features that we are not interested in
      my @features = grep { $_->das_type_id() !~ /^(contig|component|karyotype)$/i && $_->das_type_id() !~ /^(contig|component|karyotype):/i } @{$featref->{$source_nm} || []};

      my (%uhash) = (); # to filter out duplicates
      my (@filtered_features) = ();

      foreach my $feature (@features) {
        my $id = $feature->das_feature_id;
        if( defined($uhash{$id}) ) {
          $uhash{$id}->{start}  = $feature->das_start if ($uhash{$id}->{start} > $feature->das_start);
          $uhash{$id}->{end}    = $feature->das_end   if ($uhash{$id}->{end} < $feature->das_end);
          $uhash{$id}->{merged} = 1;
        } else {
          $uhash{$id}->{start}  = $feature->das_start;
          $uhash{$id}->{end}    = $feature->das_end;
          $uhash{$id}->{type_label}  = $feature->das_type;
          if ($feature->das_type ne $feature->das_type_id) {
            $uhash{$id}->{type_id}     = $feature->das_type_id;
          }
          $uhash{$id}->{method_label}  = $feature->das_method;
          if ($feature->das_method ne $feature->das_method_id) {
            $uhash{$id}->{method_id}     = $feature->das_method_id;
          }
          $uhash{$id}->{feature_label} = $feature->das_feature_label;
          if ($feature->das_feature_id ne $feature->das_feature_label) {
            $uhash{$id}->{feature_id}     = $feature->das_feature_id;
          }
 
          $uhash{$id}->{score}  = $feature->das_score;

          my $segment = $feature->das_segment->ref;

          if (my $flink = $feature->das_link) {
            my $href = $flink->{'href'};
            $uhash{$id}->{label} = sprintf( $link_tmpl, $href, $segment, $feature->das_feature_label );
          } else {
            $uhash{$id}->{label} = $feature->das_feature_label;
          }

          if( my $note = $feature->das_note ){
            if (ref $note eq 'ARRAY') {
		$note = join('<br/>', @$note);
	    }
            $uhash{$id}->{note} = parseHTML(decode_entities($note));
          }
        }
      }
      foreach my $feature (@features) {
        my $id = $feature->das_feature_id;
# Build up the type of feature location    : see FLabels hash few lines above for location types
        my $ftype = 0;
        if( $uhash{$id}->{start} == $slice->start ) {
          if( $uhash{$id}->{end} == $slice_length ) {
            # special case - feature fits the gene exactly
            $ftype = 4;
          }
        } else {
          if ($uhash{$id}->{start} < 0) {
            # feature starts before gene starts
            $ftype |= 2;
          }
          if ($uhash{$id}->{end} > $slice_length) {
            # feature ends after gene ends
            $ftype |= 1;
          }
        }
        my $score = ($uhash{$id}->{score} > 0) ? sprintf("%.02f", $uhash{$id}->{score}) : "&nbsp;";

        my $fnote = sprintf("%s%s", (defined($uhash{$id}->{merged})) ? "Merged " : "", $FLabels{$ftype});
        push( @rhs_rows, sprintf( $row_tmpl,
          $uhash{$id}->{type_label}   || '&nbsp;',
          $uhash{$id}->{type_id}       ? qq{($uhash{$id}->{type_id})} : '&nbsp;',
          $uhash{$id}->{label}        || "&nbsp",
          $uhash{$id}->{feature_id}    ? qq{($uhash{$id}->{feature_id})} : '&nbsp;',
          $uhash{$id}->{method_label} || '&nbsp;',
          $uhash{$id}->{method_id}     ? qq{($uhash{$id}->{method_id})} : '&nbsp;',
          $fnote                      || "&nbsp",
          $uhash{$id}->{note}  ?  '<small>'.$uhash{$id}->{note}.'</small>' : '&nbsp;',
          $score,
        ) );
      }
    } else {
      my $fhash = {} ;
      
      my @features = ();
      @features = @{$featref->{$source_nm}} if ref($featref->{$source_nm})=~/ARRAY/;

      foreach my $feature (@features) {
        next if ($feature->das_type_id() =~ /^(contig|component|karyotype|INIT_MET)$/i ||
                 $feature->das_type_id() =~ /^(contig|component|karyotype|INIT_MET):/i);
        if ($feature->start && $feature->end) {
          $location_features ++;
          next;
        }
my $fid = $feature->das_feature_id;
next if (exists $fhash->{$fid});
$fhash->{$fid} = 1;
        my $segment = $feature->das_segment->ref;
        my $label = $feature->das_feature_label;
        if (my $flink = $feature->das_link) {
          my $href = $flink->{'href'};
          $label = sprintf( $link_tmpl, $href, $segment, $label );
        }

        my $score  = ($feature->das_score > 0) ? sprintf("%.02f",$feature->das_score) : '&nbsp;';
        my $note;

        if( $note = $feature->das_note) {
          if (ref $note eq 'ARRAY') {
                $note = join('<br/>', @$note);
          }
        }
        if ($source->conftype eq 'internal') {
          $note = decode_entities($note);
        } else {
#          $note = decode_entities($note);
	}

# Special case : if the feature is of type NOTE than we display just a note - across all columns 
        if ($feature->das_type_id eq 'NOTE') {
  	  push @rhs_rows, qq{<tr><td colspan="10">$note</td></tr>};
	} else {
          push( @rhs_rows, sprintf( $row_tmpl,
          $feature->das_type                                       || '&nbsp;',
          ($feature->das_type_id eq $feature->das_type)             ? '&nbsp;'
                                                                    : "(".$feature->das_type_id.")",
          $label                                                   || '&nbsp;',
          ($feature->das_feature_id eq $feature->das_feature_label) ? '&nbsp;'
                                                                    : "(".$feature->das_feature_id.")",
          $feature->das_method,
          ($feature->das_method_id eq $feature->das_method)         ? '&nbsp;'
                                                                    : "(".$feature->das_method_id.")",
          $note                                                    || '&nbsp;',
          $score,
          '&nbsp;'
        ) );
}
      }
    }

  if( scalar( @rhs_rows ) == 0 ){
      my $msg = "No annotation";
      if ($location_features > 0) {
        $msg = "There are $location_features location based features that are not displayed here. See Protein Features panel";
      }
      $panel->add_row( $label, qq(<p>$msg</p>) );
    } else {
      $panel->add_row($label, qq(
<table class="hidden">
  @rhs_rows
</table>)
      );
    }

 }

 ###### Collapse/expand switch for the DAS sources panel
  my $label = 'DAS Sources';
  if( ($object->param( $status ) || ' ' ) eq 'off' ) {
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

  my $form = EnsEMBL::Web::Form->new( 'dasForm', "/$species/$script", 'GET');

  my $params ='';
  my @cparams = qw ( db gene transcript peptide );

  foreach my $param (@cparams) {
    if( defined(my $v = $object->param($param)) ) {
      $params .= ";$param=$v";
    }
  }

  foreach my $src ($object->param('das_sources')) {
    $params .=";das_sources=$src";
  }

  foreach my $param (@cparams) {
    if( defined(my $v = $object->param($param)) ) {
      $form->add_element(
        'type'  => 'Hidden',
        'name'  => $param,
        'value' => $object->param($param)
      );
    }
  }

  my %selected_sources = map {$_ => 1} $object->param('das_sources');

  my @mvalues;

  foreach my $das ( grep { $_->adaptor->conftype  ne 'url' } @das_objs ){
    my $source = $das->adaptor;
    my $name = $source->name;
    my $source_label = $source->label || $source->name;
    my $label = $source->authority ? qq(<a href=").$source->authority.qq(" target="_blank">$source_label</a>) : $source_label;
    $label         .= " (".$source->description.")" if $source->description;
    push @mvalues, { "value" => $name, "name"=>$label, 'checked' => $selected_sources{$name} ? 1 : 0 };
  }


  $form->add_element(
    'type'     => 'MultiSelect',
    'class'    => 'radiocheck1col',
    'noescape' => 1,
    'name'     =>'das_sources',
    'label'    =>'',
    'values'   => \@mvalues,
    'layout'   => 'spanning',
  );
  $form->add_element(
    'type'     => 'Submit', 'value' => 'Update', 'name' => 'Update', 'layout' => 'spanning'
  );

  $panel->add_row( $label, $form->render(), "$URL=off" );

  ###### End of the sources selector form


}

my @htext;

sub parseHTML {
  my ($html) = @_;

  @htext = ();

  sub start_handler {
    my ($self, $tag, $text) = @_;

# HTML tags that we allow go in here - rest will be encoded
    if( $tag eq 'span' || $tag eq 'a' || $tag eq 'img' || $tag eq 'br' || $tag eq 'br/' ) {
      if( $tag eq 'a' ) { # Make all das links open in a new window
        $text =~ s/\>$/ target="external"\>/;
      }
      push @htext, $text;
    } else {
      push @htext, encode_entities( $text );
    }
#   warn "+ $tag : $text\n";
    $self->handler(text => sub { my $tt = shift; push @htext, encode_entities ($tt) }, "dtext");
  }
  sub end_handler {
    my ($self, $tag, $text) = @_;
#   warn "- $tag : $text\n";
    if ($tag eq 'span' || $tag eq 'a') {
      push @htext, $text;
    } else {
      push @htext, encode_entities ($text);
    }
  }

  my $p = HTML::Parser->new(api_version => 3);
  $p->handler( start => \&start_handler, "self,tagname,text", );
  $p->handler( end =>   \&end_handler,   "self,tagname,text", );
  $p->parse("<span>$html</span>");
  $p->eof;
  return join '', @htext;
}

sub pep_stats {
  my( $panel, $object ) = @_;
  my $pepstats = $object->get_pepstats();
  return unless %{$pepstats||{}};
  my $label = "Peptide stats";
  my $HTML = qq(<table>@{[ map { sprintf(
    '<tr><th>%s:</th><td style="text-align: right">%s</td></tr>',
    $_, $object->thousandify($pepstats->{$_})
  )} sort keys %$pepstats ]}</table>);
  $panel->add_row( $label, $HTML );
  return 1;
}

sub information {
  my( $panel, $object ) = @_;
  my $label = "Translation information";
  my $transcript_id = $object->transcript->stable_id;
  my $HTML = qq(<p>This protein is a translation of transcript <a href="/@{[$object->species]}/transview?transcript=$transcript_id;db=@{[$object->get_db]}">$transcript_id</a>);
  if( $object->gene ) {
    my $gene_id   = $object->gene->stable_id;
    if( $gene_id ) {
      $HTML .= qq(, which is a product of gene <a href="/@{[$object->species]}/geneview?gene=$gene_id;db=@{[$object->get_db]}">$gene_id</a>);
    }
  }
  $HTML .= '.</p>';
  $panel->add_row( $label, $HTML );
  return 1;
}

sub version {
  my( $panel, $object ) = @_;
  $panel->add_row( 'Version', "<p>@{[ $object->version ]}</p>" );
  return 1;
}

sub author {
  my( $panel, $object ) = @_;
  my $author = $object->get_author_name;
  return unless $author;
  my $label = "Author";
  my $email = $object->get_author_email;
     $email = sprintf ' <a href="mailto:%s">%s</a>', CGI::escapeHTML($email), CGI::escapeHTML($email) if $email;
  my $HTML = sprintf '<p>This locus was annotated by %s%s</p>', CGI::escapeHTML($author), $email;
  $panel->add_row( $label, $HTML );
  return 1;
}

=head2 protview_peptide_image

 Arg[1]      : none
 Example     : $pepdata->renderer->protview_peptide_image
 Description : wrapper to print peptide image in two_col_table format for protview
 Return type : Key / value pair - label and HTML

=cut


sub image {
  my( $panel, $object ) = @_;
  my $label = 'Protein Features';
  my $peptideid = $object->stable_id;
  my $db        = $object->get_db ;
  my $wuc       = $object->get_imageconfig( 'protview' );
  $wuc->container_width( $object->Obj->length );
  $wuc->{_object} = $object;
  my $image_width = $wuc->get('_settings', 'width');

  my $das_collection = $object->get_DASCollection();
  foreach my $das( @{$das_collection->Obj} ){
    next unless $das->adaptor->active;
   $das->adaptor->maxbins($image_width) if ($image_width);
    my $source = $das->adaptor->name();
    my $color  = $das->adaptor->color() || 'black';
    my $src_label  = $das->adaptor->label() || $source;
    $wuc->das_sources( { "genedas_$source" => { on=>'on', col=>$color, label=> $src_label, manager=>'Pprotdas' } } );
  }

  $object->Obj->{'image_snps'}   = $object->pep_snps;
  $object->Obj->{'image_splice'} = $object->pep_splice_site( $object->Obj );

  my $image                      = $object->new_image( $object->Obj, $wuc, [], 1 ) ;
     $image->imagemap            = 'yes';
  $panel->add_row( $label, $image->render );
  1;
}

#----------------------------------------------------------------------

=head2 print_fasta_seq

 Arg[1]      : none
 Example     : $pepdata->renderer->print_fasta_seq
 Description : prints markedup peptide fasta sequence
 Return type : String - HTML

=cut

sub marked_up_seq_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'marked_up_seq', "/@{[$object->species]}/protview", 'get' );
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',      'value' => $object->get_db    );
  if ($object->stable_id) {
    $form->add_element( 'type' => 'Hidden', 'name' => 'peptide', 'value' => $object->stable_id );
  } else {
    $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->transcript->stable_id);
  }
  my $show = [{ 'value' => 'plain', 'name' => 'None' }, {'value'=>'exons', 'name'=>'Exons'} ];
  if( $object->species_defs->databases->{'ENSEMBL_VARIATION'}||$object->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
    push @$show, { 'value' => 'snps', 'name' => 'Exons and SNPs' };
  }
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
  my $label = "Protein Sequence";
  my $HTML = "<pre>@{[ do_markedup_pep_seq( $object ) ]}</pre>";
  my $db        = $object->get_db() ;
  my $stable_id = $object->stable_id;
  my $trans_id  = $object->transcript->stable_id;
  my $show      = $object->param('show');
  
  my $image_key;
  if( $show eq 'exons' || $show eq 'snps' ) {
    $HTML .= qq(<img src="/img/help/protview_key1.gif" alt="[Key]" border="0" />);
  }
  $HTML .= "<div>@{[ $panel->form( 'markup_up_seq' )->render ]}</div>";
  $panel->add_row( $label, $HTML );
  return 1;
}

#----------------------------------------------------------------------

=head2 do_markedup_pep_seq

 Arg[1]           : none
 Example     : $pep_seq = $pepdata->do_markedup_pep_seq
 Description : returns the the peptide sequence  with markup
 Return type : a string

=cut


sub do_markedup_pep_seq {
  my $object     = shift;
  my $number     = $object->param('number');
  my $show       = $object->param('show');
  my $peptide    = $object->Obj;
  my $trans      = $object->transcript;
  my $pep_splice = $object->pep_splice_site($peptide);
  my $pep_snps   = $object->pep_snps;
  my $wrap       = 60;
  my $db         = $object->get_db;
  my $pep_id     = $object->stable_id;
  my $pep_seq    = $peptide->seq;
  my @exon_colours = qw(black blue red);
  my %bg_color = (
    'c0'      => '#ffffff',
    'syn'     => '#76ee00',
    'insert'  => '#99ccff',
    'delete'  => '#99ccff',
    'snp'     => '#ffd700',
  );
  my @aas = map {{'aa' => $_ }} split //, uc($pep_seq) ; # store peptide seq in hash
  my ($output, $fasta, $previous) = '';
  my ($count, $flip, $i) = 0;
  my $pos = 1;
  my $SPACER = $number eq 'on' ? '       ' : '';
  foreach (@aas) {                        # build markup
    if($count == $wrap) {
      my $NUMBER = '';
      if($number eq 'on') {
        $NUMBER = sprintf("%6d ",$pos);
        $pos += $wrap;
      }
      $output .= ($show eq 'snps' ? "\n$SPACER" : '' ).
        $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n" ;
      $previous=''; $count=0; $fasta ='';
    }
    if ( $pep_splice->{$i}{'exon'} ){ $flip = 1 - $flip }
       my $fg = $pep_splice->{$i}{'overlap'} ? $exon_colours[2] : $exon_colours[$flip];
    my $bg = $bg_color{$pep_snps->[$i]{'type'}};
    my $style = qq(style="color:$fg;");
    my $type = $pep_snps->[$i]{'type'};
    if( $show eq 'snps') {
        $style = qq(style="color:$fg;). ( $bg ? qq( background-color:$bg;) : '' ) .qq(");
      if ($type eq 'snp'){
        $style .= qq(title="Residues: $pep_snps->[$i]{'pep_snp'} ");
        }
        if ($type eq 'syn'){
        my $string = '';
        for my $letter ( 0..2 ){
                $string .= $pep_snps->[$i]{'ambigcode'}[$letter]  ? '('.$pep_snps->[$i]{'ambigcode'}[$letter].')' : $pep_snps->[$i]{'nt'}[$letter];
        }
        $style .= qq(title="Codon: $string ");
        }
        if($type eq 'insert') {
        $pep_snps->[$i]{'alleles'} = join '', @{$pep_snps->[$i]{'nt'}};
        $pep_snps->[$i]{'alleles'} = Bio::Perl::translate_as_string($pep_snps->[$i]{'alleles'});   # translate insertion.. bio::perl call
        $style .= qq(title="Insert: $pep_snps->[$i]{'allele'} ");
        }
        if($type eq 'delete') {
        $style .= qq(title="Deletion: $pep_snps->[$i]{'allele'} ");
      }
        if($type eq 'frameshift') {
        $style .= qq(title="Frame-shift ");
      }
    }        # end if snp
    
    if($style ne $previous) {
      $fasta.=qq(</span>) unless $previous eq '';
      $fasta.=qq(<span $style>) unless $style eq '';
      $previous = $style;
    }
    $count++; $i++;
    $fasta .= $_->{'aa'};    
  }
  
  my $NUMBER = '';
  if($number eq 'on') {
    $NUMBER = sprintf("%6d ",$pos); $pos += $wrap;
  }
  $output .= ($show eq 'snps' ? "\n$SPACER" : '' ).$NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
  
  my( $sel_snps, $sel_exons,$sel_peptide)=('','','');
  if($show eq'snps') { $sel_snps = ' selected'; }
  elsif($show eq 'exons') {$sel_exons=' selected'; } 
  else { ($sel_snps, $sel_exons ) = ''; }
  
  my ( $sel_numbers, $sel_no)=('','');
  if($number eq'on') { $sel_numbers = ' selected'; }
  else {$sel_no=' selected'; }
  
  my $SNP_LINE = exists($object->species_defs->databases->{'ENSEMBL_VARIATION'}) ? qq(<option value="snps" $sel_snps>Exons/SNPs</option>) : '' ;
  return ($output);
}

#----------------------------------------------------------------------

=head2 domain_list

 Arg[1]      : none
 Example     : $pepdata->renderer->domain_list
 Description : Sorts domains into correct format for spreadsheet table, also set various
                 table configuration parameters
 Return type : list of array refs

=cut

sub domain_list{
  my( $panel, $object ) = @_;
  my $domains = $object->get_protein_domains();
  return unless @$domains ;

  my @domain_list;
  $panel->add_option( 'triangular', 1 );
  $panel->add_columns(
    { 'key' => 'desc',  'title' => 'Description',      'width' => '30%', 'align' => 'center' },
    { 'key' => 'start', 'title' => 'Start',            'width' => '15%', 'align' => 'center' , 'hidden_key' => '_loc' },
    { 'key' => 'end',   'title' => 'End',              'width' => '15%', 'align' => 'center' },
    { 'key' => 'type',  'title' => 'Domain type',      'width' => '20%', 'align' => 'center' },
    { 'key' => 'acc',   'title' => 'Accession number', 'width' => '20%', 'align' => 'center' },
  );

# may do a code reference to url call else clean up url creation on domain type
  my $prev_start = undef;
  my $prev_end   = undef;
  foreach my $domain (
    sort { $a->idesc cmp $b->idesc || 
           $a->start <=> $b->start ||
           $a->end <=> $b->end || 
           $a->analysis->db cmp $b->analysis->db } @$domains ) {
    my $db = $domain->analysis->db;
    my $id = $domain->hseqname;
    $panel->add_row( { 
      'type'  => $db,
      'acc'   => $object->get_ExtURL_link( $id, uc($db), $id ),
      'start' => $domain->start,
      'end'   => $domain->end ,
      'desc'  => $domain->idesc,
      '_loc'  => join '::', $domain->start,$domain->end,
    } );
  }
  return 1;
}

sub other_feature_list {
  my( $panel, $object ) = @_;
  my @other = map { @{$object->get_all_ProteinFeatures($_)} } qw( tmhmm SignalP ncoils Seg );
  return unless @other ;
  $panel->add_option( 'triangular', 1 );
  $panel->add_columns(
    { 'key' => 'type',  'title' => 'Domain type',      'width' => '60%', 'align' => 'center' },
    { 'key' => 'start', 'title' => 'Start',            'width' => '30%', 'align' => 'center' , 'hidden_key' => '_loc' },
    { 'key' => 'end',   'title' => 'End',              'width' => '30%', 'align' => 'center' },
  );
  foreach my $domain ( 
    sort { $a->[0] cmp $b->[0] || $a->[1]->start <=> $b->[1]->start || $a->[1]->end <=> $b->[1]->end }
    map { [ $_->analysis->db || $_->analysis->logic_name || 'unknown', $_ ] }
    @other ) {
    ( my $domain_type = $domain->[0] ) =~ s/_/ /g;
    $panel->add_row( {
      'type'  => ucfirst($domain_type),
      'start' => $domain->[1]->start,
      'end'   => $domain->[1]->end,
      '_loc'  => join '::', $domain->[1]->start,$domain->[1]->end,
    } );
  }
  return 1; 
}

#----------------------------------------------------------------------

=head2 snp_list

 Arg[1]      : none
 Example     : $pepdata->renderer->snp_list
 Description : Sorts snp list into correct format for spreadsheet table, also set various
                 table configuration parameters
 Return type : list of array refs

=cut

sub snp_list {        
  my( $panel, $object ) = @_;
  my $snps = $object->pep_snps();
  return unless @$snps;
    
  $panel->add_columns(
    { 'key' => 'res',    'title' => 'Residue',            'width' => '10%', 'align' => 'center' },
    { 'key' => 'id',     'title' => 'SNP ID',             'width' => '15%', 'align' => 'center' }, 
    { 'key' => 'type',   'title' => 'SNP type',           'width' => '20%', 'align' => 'center' },
    { 'key' => 'allele', 'title' => 'Alleles',            'width' => '20%', 'align' => 'center' },
    { 'key' => 'ambig',  'title' => 'Ambiguity code',     'width' => '15%', 'align' => 'center' },
    { 'key' => 'alt',    'title' => 'Alternative residues', 'width' => '20%', 'align' => 'center' }
  );

  my $counter = 0;
  foreach my $residue (@$snps){    
    $counter++;
    next if !$residue->{'allele'};
    my $type = $residue->{'type'} eq 'snp' ? "Non-synonymous" : ($residue->{'type'} eq 'syn' ? 'Synonymous': ucfirst($residue->{'type'}));
    my $snp_id = $residue->{'snp_id'};
    my $source = $residue->{'snp_source'} ? ";source=".$residue->{'snp_source'} : "";
    $panel->add_row({
     'res'     => $counter,                      
     'id'      => qq(<a href="/@{[$object->species]}/snpview?snp=$snp_id$source">$snp_id</a>),
     'type'    => $type,
     'allele'  => $residue->{'allele'},
     'ambig'   => join('', @{$residue->{'ambigcode'}||[]}),
     'alt'     => $residue->{'pep_snp'} ? $residue->{'pep_snp'} : '-',
     'LDview'  => qq(<a href="/@{[$object->species]}/ldview?snp=$snp_id$source">$snp_id</a>),
    });
  }
  return 1;
}


#----------------------------------------------------------------------

=head2 das_annotation

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub das_annotation {
  my $self = shift;
  my $data = $self->DataObj;

  my $table_tmpl = qq(
<table>%s
</table>);
  my $head_row = qq(
 <tr>
    <th>Source</th>
    <th>ID</th>
    <th>Type</th>
    <th>Notes</th>
 </tr> );
  my $row_tmpl = qq(
 <tr>
    <td><strong>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td><span class="small">%s</small></td>
 </tr> );
  my $link_tmpl = qq(<a href="%s" target="%s">%s</a>);

  my @table_data = ();
  my $das_attribute_data = $data->get_das_attributes
    ("name", "authority","active" );

  foreach my $source( @$das_attribute_data ){
    $source->{active} || next;
    my $source_nm = $source->{name};
    my $source_lab = $source_nm;
    if( my $ln = $source->{authority} ){
      $source_lab = sprintf( $link_tmpl, $ln, $source_nm, $source_nm );
    }
    my $label = "ProteinDAS";
    push( @table_data, $label.": ". $source_lab,'' );

    my @features = $data->get_das_annotation_by_name($source_nm,'global');

    my @rhs_rows;

    if( ! scalar( @features ) ){
      push( @rhs_rows, "No annotation" );
    }
    foreach my $feature( @features ){
      my $segment = $feature->das_segment->ref;
      my $id = $feature->das_feature_id;
      if( my $href = $feature->das_link ){
        $id = sprintf( $link_tmpl, $href, $segment, $id )
      }
      my $note;
      if( $note = $feature->das_note ){
	if (ref $note eq 'ARRAY') {
	  $note = join('<br/>',@$note);
	}
        $note=~s|((\S+?):(http://\S+))      |<a href="$3" target="$segment">[$2]</a>|igx;
        $note=~s|([^"])(http://\S+)([^"])   |$1<a href="$2" target="$segment">$2</a>$3|igx;
        $note=~s|((\S+?):navigation://(\S+))|<a href="protview?gene=$3" >[$2]</a>|igx;
       #$note=~s|([^"])(navigation://\S+)([^"])|$1<A href="$2">$2</A>$3|igx;
      }
      push( @rhs_rows, sprintf( $row_tmpl, 
        #$feature->{-source} || '&nbsp;',
        $feature->das_type || '&nbsp;',
        $id                || '&nbsp;',
        $note              || '&nbsp;'
      ));
    }
    my $space_row;
    $table_data[-1] = sprintf( $table_tmpl, join($space_row, @rhs_rows ) );
  }
  return (@table_data);   
}

#======================================================================

=head2 similarity_matches

 Arg[1]      : (optional) String
               Label
 Example     : $pepdata->renderer->similarity_matches
 Description : Renders similarity matches for transcript in two_col_table format
 Return type : Key / value pair - label and HTML

=cut

sub similarity_matches {
  my $self = shift;
  my $label = shift || 'Similarity Matches';
  my $transl = $self->DataObj->translation;     
  my $data = $self->DataObj();
  # Check cache
  unless ($transl->{'similarity_links'}) {
    my @similarity_links = @{$data->get_similarity_hash($transl)};   
    return unless (@similarity_links);
    # sort links
    $self->_sort_similarity_links(@similarity_links);
  }

  my %links = %{$transl->{'similarity_links'}};
  return unless %links;

  my $db = $data->get_db();
  my $entry = $data->gene_type || 'Ensembl';
    # add table call here
    my $html = qq(
                <p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
    $html .= qq(<table>);
    foreach my $key (sort keys %links){
        if (scalar (@{$links{$key}}) > 0){
            my @sorted_links = sort @{$links{$key}};
            $html .= qq(<tr><td class="nowrap"><strong>$key:</strong></td>\n<td>);

            if( $sorted_links[0] =~ /<br/i ){
                $html .= join(' ', @sorted_links );
            } else { # Need a BR each 5 entries
                $html .= qq(<table><tr>);
                my @sorted_lines;
                for( my $i=0; $i<@sorted_links; $i++ ){
                    my $line_num = int($i/4);
                    if( ref(  $sorted_lines[$line_num] ) ne 'ARRAY' ){$sorted_lines[$line_num] = [];}
                    push( @{$sorted_lines[$line_num]}, "<td>".$sorted_links[$i]."</td>" );
                }
                $html .= join( "</tr>\n<tr>", map{ join( ' ', @$_ ) } @sorted_lines );
                $html .= qq(</tr></table>);
            }
            $html .= qq(</td></tr>);
        }
    }   
    $html .= qq(</table>); 
    return ($label , $html);
}

=head2 _sort_similarity_links

 Arg[1]      : none
 Example     : $pepdata->renderer->_sort_similarity_links
 Description : sorts the similarity matches
 Return type : hashref of similarity matches

=cut

sub _sort_similarity_links{
  my $self = shift;
  my $transl = $self->DataObj->translation;
  my @similarity_links = @_;
  my $data = $self->DataObj();
  my $database = $data->database;
  my $db = $data->get_db() ;
  my $urls = $self->ExtURL;
  my %links ;
  my $ALIGN_LINK = qq( [<a href="/@{[$self->species]}/alignview?transcript=%s&sequence=%s&db=%s" class="small" target="palignview">align</a>] );
  # Nice names    
  my %nice_names = (  
    'protein_id'            => 'Protein ID', 
    'drosophila_gene_id'    => 'Drosophila Gene',
    'flybase_gene'          => 'Flybase Gene',
    'flybase_symbol'        => 'Flybase Symbol',
    'affy_hg_u133'          => 'Affymx Microarray U133',
    'affy_hg_u95'           => 'Affymx Microarray U95',
    'anopheles_symbol'      => 'Anopheles symbol',
    'sanger_probe'          => 'Sanger Probe',
    'wormbase_gene'         => 'Wormbase Gene',
    'wormbase_transcript'   => 'Wormbase Transcript',
    'wormpep_id'            => 'Wormpep ID',
    'briggsae_hybrid'       => 'Briggsae Hybrid',
    'sptrembl'              => 'SpTrEMBL',
    'ens_hs_transcript'     => 'Ensembl Human Transcript',
    'ens_hs_translation'    => 'Ensembl Human Translation',
    'uniprot/sptrembl'      => 'UniProt/TrEMBL',
    'uniprot/swissprot'     => 'UniProt/Swiss-Prot',
    'pubmed'                => 'Sequence Publications',
  );
                       
  foreach my $type (sort @similarity_links) { 
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();

    # remove all orthologs  
    next if ($type->status() eq 'ORTH');
 
    # ditch medline entries - redundant as we also have pubmed
    next if lc($externalDB) eq "medline";
    
    # Ditch celera genes from FlyBase
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ );

    # remove internal links to self and transcripts
    next if $externalDB eq "Vega_gene";
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";

    if( $externalDB eq "GO" ){ #&& $data->database('go')){
      push @{$transl->{'go_links'}} , $display_id;
      next;   
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$transl->{'GKB_links'}{$key}} , $type ;
      next;
    } elsif ($externalDB eq "REFSEQ") { 
      # strip off version
      $display_id =~ s/(.*)\.\d+$/$1/o;
    } elsif ($externalDB eq "protein_id") { 
      # Can't link to srs if there is an Version - so strip it off
      $primary_id =~ s/(.*)\.\d+$/$1/o;
    }
    # Build external links
    if ($urls and $urls->is_linked($externalDB)) {
      $link = '<a href="'.$urls->get_url($externalDB, $primary_id).'">'. $display_id. '</a>';
      if ( uc( $externalDB ) eq "REFSEQ" and $display_id =~ /^NP/) {
        $link = '<a href="'.$urls->get_url('REFSEQPROTEIN',$primary_id).'">'. $display_id. '</a>';
      } elsif ($externalDB eq "HUGO") {
        $link = '<a href="' .$urls->get_url('GENECARD',$display_id) .'">Search GeneCards for '. $display_id. '</a>';
      } elsif ($externalDB eq "MarkerSymbol") { # hack for mouse MGI IDs
        $link = '<a href="' .$urls->get_url('MARKERSYMBOL',$primary_id) .'">'."$display_id ($primary_id)".'</a>';
      } 
      if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
        $link .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';            
        $join_links = 1;    
      }
      if (( $data->species_defs->ENSEMBL_PFETCH_SERVER ) && 
        ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {  
        my $seq_arg = $display_id;
        $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
        $link .= sprintf( $ALIGN_LINK, $transl->stable_id, $seq_arg, $db );
      }
      if ($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link            
        $link .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'" class="small">Search GO</a>]';
      }
      if( $join_links  ) {
        $link .= '<br />';
      }
    } else {
      $link = " $display_id ";
    }
    my $display_name = $nice_names{lc($externalDB)} || ($externalDB =~ s/_/ /g, $externalDB)  ;
    push (@{$links{$display_name}}, $link);         
  }
  $transl->{'similarity_links'} = \%links ;
  return $transl->{'similarity_links'};
}

1; 
