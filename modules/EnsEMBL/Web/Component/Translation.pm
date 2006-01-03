package EnsEMBL::Web::Component::Translation;

# Puts together chunks of XHTML for gene-based displays
                                                                                
use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub _flip_URL {
  my( $object, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $object->species, $object->script, $object->transcript->stable_id, $object->get_db, $code;
}

sub das {
   my( $panel, $object ) = @_;
   my $status   = 'status_das_sources';
   my $URL = _flip_URL( $object, $status );
   EnsEMBL::Web::Component::format_das_panel($panel, $object, $status, $URL);
}

sub pep_stats {
  my( $panel, $object ) = @_;
  my $pepstats = $object->get_pepstats();
  return unless %{$pepstats||{}};
  my $label = "Peptide stats";
  my $HTML = qq(<table>@{[ map { sprintf( '<tr><th>%s:</th><td style="text-align: right">%s</td></tr>', $_, $object->thousandify($pepstats->{$_}) ) } sort keys %$pepstats ]}</table>);
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
  my $wuc       = $object->get_userconfig( 'protview' );
  $wuc->container_width( $object->Obj->length );
  my $das_collection = $object->get_DASCollection();
  foreach my $das( @{$das_collection->Obj} ){
    next unless $das->adaptor->active;
    my $source = $das->adaptor->name();
    my $color  = $das->adaptor->color() || 'black';
    $wuc->das_sources( { "genedas_$source" => { on=>'on', col=>$color, manager=>'Pprotdas' } } );
  }

  $object->Obj->{'image_snps'}   = $object->pep_snps;
  $object->Obj->{'image_splice'} = $object->pep_splice_site( $object->Obj );

  my $image     = $object->new_image( $object->Obj, $wuc, [], 1 ) ;
     $image->imagemap           = 'yes';
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
    'syn'     => '#99ff99',
    'insert'  => '#99ccff',
    'delete'  => '#99ccff',
    'snp'     => '#ff9999',
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
    { 'key' => 'start', 'title' => 'Start',            'width' => '15%', 'align' => 'center' },
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
      'desc'  => $domain->idesc
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
    { 'key' => 'start', 'title' => 'Start',            'width' => '30%', 'align' => 'center' },
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
      'end' => $domain->[1]->end
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
    { 'key' => 'alt',    'title' => 'Alternate residues', 'width' => '20%', 'align' => 'center' }
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

=head2 das_configurator

  Arg [1]   : 
  Function  : 
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub das_configurator {
  my $self = shift;

  my $transcript = $self->param( "transcript" );
  my $peptide = $self->param( "peptide" );
  my $db      = $self->param( "db" );
  my $param_str = "db=$db";
  $transcript and $param_str .= "&transcript=$transcript";
  $peptide    and $param_str .= "&peptide=$peptide";

  my $conf_submit = qq(
<form name="dasConfigForm" action="/@{[$self->{object}->species]}/dasconfview" method="post">
  <input type="hidden" name="conf_script" value="protview" />
  <input type="hidden" name="conf_script_params" value="$param_str" />
  <input type="submit" value="Manage Sources" />
</form>);

  my $html_tmpl = qq(
<form name="dasForm" id="dasForm" method="get" action="/@{[$self->{'object'}->species]}/@{[$self->{'object'}->script]}">%s </form>);
  my $check_tmpl = qq(
  <input type="checkbox" name="%s" value="1" %s onClick="javascript:document.dasForm.submit()" /> %s 
  <input type="hidden" name=":%s" value="0" />);
  my $hidden_tmpl = qq(
  <input type="hidden" name="%s" value="%s" />);
  my $a_tmpl = qq(<a href="%s" target="new">%s</a>);

  my $label = sprintf( $a_tmpl, "/Docs/gene_das.html",,"ProteinDAS" );
  $label .= " Sources";

  my $hidden = '';
  foreach my $param( "peptide", "translation", "db" ){
    my $val = $self->param($param) || next;
    $hidden .= sprintf( $hidden_tmpl, $param, $val );
  }

  my @checks = ();
  my $data = $self->DataObj;
  my $das_attribute_data = $data->get_das_attributes
                ( "name", "authority", "label", "active" ) || return ();
  foreach my $source( @$das_attribute_data ){
    my $name = $source->{name} ||
      ( warn "DAS source found with no name attribute" ) && next;

    my $source_desc = $source->{label};
    my $param_name = join( '!!', 'ENSEMBL_GENE_DAS_SOURCES', $name, 'active' );

    my $selected = $self->param($param_name) ? 'CHECKED' : '';
    my $href = $source->{authority} || undef();
    my $label = $href ? sprintf( $a_tmpl, $href, $name ) : $name;
    $label .= " ($source_desc)" if $source_desc;

    push @checks, sprintf( $check_tmpl, $param_name,
               $selected, $label, $param_name);
  }
  my $html = sprintf( $html_tmpl, join( "<br />", @checks ).$hidden );
  $html .= "$conf_submit";

  return( $label, $html );
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
    foreach my $feature( sort{ 
      $a->das_type_id    cmp $b->das_type_id ||
      $a->das_feature_id cmp $b->das_feature_id ||
      $a->das_note       cmp $b->das_note
    } @features ){

      my $segment = $feature->das_segment->ref;
      my $id = $feature->das_feature_id;
      if( my $href = $feature->das_link ){
    $id = sprintf( $link_tmpl, $href, $segment, $id )
      }
      my $note;
      if( $note = $feature->das_note ){
    $note=~s|((\S+?):(http://\S+))|
      <A href="$3" target="$segment">[$2]</A>|ig;
    $note=~s|([^"])(http://\S+)([^"])|
      $1<A href="$2" target="$segment">$2</A>$3|ig;
    
    $note=~s|((\S+?):navigation://(\S+))|
      <A href="protview?gene=$3" >[$2]</A>|ig;
    #$note=~s|([^"])(navigation://\S+)([^"])|
    #  $1<A href="$2">$2</A>$3|ig;
      }

      push( @rhs_rows, sprintf( $row_tmpl, 
                #$feature->{-source} || '&nbsp;',
                $feature->das_type || '&nbsp;',
                $id                || '&nbsp;',
                $note              || '&nbsp;' ) );
    }
   my $space_row;
    $table_data[-1] = sprintf( $table_tmpl, 
                   join($space_row, @rhs_rows ) );
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
    my $html;
    unless ($data->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
        $html = qq(
                <p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
    }
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
            'ens_hs_transcript'        => 'Ensembl Human Transcript',
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
        } 
    elsif ($externalDB eq "GKB") {
            my ($key, $primary_id) = split ':', $display_id;
            push @{$transl->{'GKB_links'}{$key}} , $type ;
            next;
        } 
    elsif ($externalDB eq "REFSEQ") { 
        # strip off version
        $display_id =~ s/(.*)\.\d+$/$1/o;
    }  
        elsif ($externalDB eq "protein_id") { 
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
                $link .= sprintf( $ALIGN_LINK,
                $transl->stable_id,
                $seq_arg,
                $db );
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
