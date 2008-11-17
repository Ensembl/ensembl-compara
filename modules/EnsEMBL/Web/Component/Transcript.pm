package EnsEMBL::Web::Component::Transcript;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component);

use Data::Dumper;
use strict;
use warnings;
use EnsEMBL::Web::Form;
use CGI qw(escapeHTML);

no warnings "uninitialized";

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub non_coding_error {
  my $self = shift;
  return $self->_error( 'No protein product', '<p>This transcript does not have a protein product</p>' );
}
sub Summary {
  my( $panel, $object ) =@_;
  my $ob = $object->Obj;

  my $location_html = sprintf( '<a href="/%s/Location/View?r=%s:%s-%s">%s: %s-%s</a> %s',
    $object->species,
    $object->seq_region_name,
    $object->seq_region_start,
    $object->seq_region_end,
    $object->neat_sr_name( $object->seq_region_type, $object->seq_region_name ),
    $object->thousandify( $object->seq_region_start ),
    $object->thousandify( $object->seq_region_end ),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );

  my $description = escapeHTML( $object->trans_description() );
  if( $description ) {
    $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/EC_URL($object,$1)/e;
    $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
    my($edb, $acc) = ($1, $2);
    $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if $acc;
  }

  $panel->add_description( $description );
  $panel->add_row( 'Location', $location_html );
#  if( $ob->can('analysis') ) {
#    my $desc = $ob->analysis->description;
#    $panel->add_row( 'Method',   escapeHTML( $desc ) ) if $desc;
#  }
  my $gene = $object->core_objects->gene;
  my $transcripts = $gene->get_all_Transcripts;
  my $count = @$transcripts;
  if( $count > 1 ) {
    my $html = '
        <table id="transcripts" style="display:none">';
    foreach( sort { $a->stable_id cmp $b->stable_id } @$transcripts ) {
      my $url = $object->_url({
        'type'   => 'Transcript',
  'action' => $object->action,
        't'      => $_->stable_id
      });
      $html .= sprintf( '
          <tr%s>
      <th>%s</th>
      <td><a href="%s">%s</a></td>
    </tr>',
  $_->stable_id eq $object->stable_id ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id
      );

    }
    $html .= '
        </table>';
    $panel->add_row( 'Gene', sprintf(q(<div id="transcripts_text">Is a product of gene %s - There are %d transcripts in this gene:</div> %s), $gene->stable_id, $count, $html ));
  } else {
    $panel->add_row( 'Gene', sprintf(q(<div style="float:left">Is the product of gene %s.</div>), $gene->stable_id ));

  }
#  $panel->add_row( 'Location', 'location' );
}

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
  unless ($transcript->__data->{'links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($transcript->Obj)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }
  return unless $transcript->__data->{'links'}{'gkb'};
  my $GKB_hash = $transcript->__data->{'links'}{'gkb'};

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

sub alternative_transcripts {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
}

sub oligo_arrays {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'oligo_arrays', 'Oligo Matches', 'ARRAY' );
}

sub literature {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'literature', 'References', 'LIT' );
}

sub similarity_matches {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC' );
}

sub _flip_URL {
  my( $transcript, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
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
            This cluster contains $family_count Ensembl gene member(s) in this species.</p>);
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
  my $wuc = $transcript->get_imageconfig( 'geneview' );
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
  my $wuc = $transcript->get_imageconfig( 'transview' );
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
  $panel->timer_push( "Got snps and slices for protein_feature....", 1 );

  my $wuc = $transcript->get_imageconfig( 'protview' );
  $wuc->container_width( $translation->Obj->length );
  my $image    = $transcript->new_image( $translation->Obj, $wuc, [], 1 );
     $image->imagemap = 'yes';
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
  return 1;
}

sub marked_up_seq_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'marked_up_seq', "/@{[$object->species]}/transview", 'get' );
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',         'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->stable_id );
  my $show = [
    { 'value' => 'plain',   'name' => 'Exons' },
#    { 'value' => 'revcom',  'name' => 'Reverse complement sequence' },
    { 'value' => 'codons',  'name' => 'Exons and Codons' },
    { 'value' => 'peptide', 'name' => 'Exons, Codons and Translation'},
  ];
  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ||
      $object->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
    push @$show, { 'value' => 'snps', 'name' => 'Exons, Codons, Translations and SNPs' };
    push @$show, { 'value' => 'snp_coding', 'name' => 'Exons, Codons, Translation, SNPs and Coding sequence'};
  }
  else {
    push @$show, { 'value' => 'coding', 'name' => 'Exons, Codons, Translation and Coding sequence'};
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

  if( $show eq 'codons' ) {
      $HTML .= qq(<img src="/img/help/transview-key1.gif" height="200" width="200" alt="[Key]" border="0" />);
  } elsif( $show eq 'snps' or $show eq 'snp_coding' ) {
      $HTML .= qq(<img src="/img/help/transview-key3.gif" height="350" width="300" alt="[Key]" border="0" />);
  } elsif( $show eq 'peptide' or $show eq 'coding' ) { 
    $HTML .= qq(<img src="/img/help/transview-key2.gif" height="200" width="200" alt="[Key]" border="0" />);
  }
  elsif ($show eq 'revcom') {
    $HTML .= "<p>Reverse complement sequence</p>";
  }
  $HTML .= "<div>@{[ $panel->form( 'markup_up_seq' )->render ]}</div>";
  $panel->add_row( $label, $HTML );
  return 1;
}




# Transcript SNP View ---------------------------------------###################

sub transcriptsnpview { 
  my( $panel, $object, $do_not_render ) = @_;

  # Params for context transcript expansion.
  my $db = $object->get_db();
  my $transcript = $object->stable_id;
  my $script = 'transcriptsnpview';
  my $base_URL = "/".$object->species."/$script?db=$db;transcript=$transcript;";

  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $extent = tsv_extent($object);
  foreach my $slice_type (
    [ 'context',           'normal', '100%'  ],
    [ 'transcript',        'normal', '20%'  ],
    [ 'TSV_transcript',    'munged', $extent ],
  ) {
    $object->__data->{'slices'}{ $slice_type->[0] } =  $object->get_transcript_slices( $slice_type ) || warn "Couldn't get slice";
  }
  my $transcript_slice = $object->__data->{'slices'}{'TSV_transcript'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'TSV_transcript'}[2];
  my $fake_length      =  $object->__data->{'slices'}{'TSV_transcript'}[3];

  #SNPs
  my ($count_sample_snps, $sample_snps, $context_count) = $object->getFakeMungedVariationsOnSlice( $transcript_slice, $sub_slices  );
  my $start_difference =  $object->__data->{'slices'}{'TSV_transcript'}[1]->start - $object->__data->{'slices'}{'transcript'}[1]->start;

  my @transcript_snps;
  map { push @transcript_snps, 
    [ $_->[2]->start + $start_difference, 
      $_->[2]->end   + $start_difference, 
      $_->[2]] } @$sample_snps;

  # Taken out domains (prosite, pfam)

  # Tweak the configurations for the five sub images ------------------ 
  # Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  my @ens_exons;
  foreach my $exon (@{ $object->Obj->get_all_Exons() }) {
    my $offset = $transcript_slice->start -1;
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps( 'TSV_transcript', $es );
    push @ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }


  # General page configs -------------------------------------
  # Get 4 configs (one for each section) set width to width of context config
  my $Configs;
  my $image_width    = $object->param( 'image_width' );

  foreach (qw(context transcript transcripts_bottom transcripts_top)) {
    $Configs->{$_} = $object->image_config_hash( "TSV_$_" );
    $Configs->{$_}->set( '_settings', 'width',  $image_width );
    $Configs->{$_}->{'id'} = $object->stable_id;
  }

  $Configs->{'transcript'}->{'filtered_fake_snps'} = \@transcript_snps;

  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'transid'}     = $object->stable_id;
    $Configs->{$_}->{'transcripts'} = [{ 'exons' => \@ens_exons }];
    $Configs->{$_}->{'snps'}        = $sample_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->container_width( $fake_length );
  }


  $Configs->{'snps'} = $object->image_config_hash( "genesnpview_snps" );
  $Configs->{'snps'}->set( '_settings', 'width',  $image_width );
  $Configs->{'snps'}->{'snp_counts'} = [$count_sample_snps, scalar @$sample_snps, $context_count];

  $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  $Configs->{'context'}->set( 'est_transcript','on','off');
  $Configs->{'context'}->set( '_settings', 'URL', $base_URL."bottom=%7Cbump_", 1);
  #$Configs->{'context'}->{'filtered_fake_snps'} = $context_snps;

  # SNP stuff ------------------------------------------------------------
  my ($containers_and_configs, $haplotype);

  # Foreach sample ... 
  ($containers_and_configs, $haplotype) = _sample_configs($object, $transcript_slice, $sub_slices, $fake_length);

  # -- Map SNPs for the last SNP display to fake even spaced co-ordinates
  # @snps: array of arrays  [fake_start, fake_end, B:E:Variation obj]
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $snp_fake_length = -1; ## end of last drawn snp on bottom display...
  my @fake_snps = map {
    $snp_fake_length +=$SNP_REL+1;
      [ $snp_fake_length - $SNP_REL+1, $snp_fake_length, $_->[2], $transcript_slice->seq_region_name,
  $transcript_slice->strand > 0 ?
  ( $transcript_slice->start + $_->[2]->start - 1,
    $transcript_slice->start + $_->[2]->end   - 1 ) :
  ( $transcript_slice->end - $_->[2]->end     + 1,
    $transcript_slice->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @$sample_snps;

  if (scalar @$haplotype) {
    $Configs->{'snps'}->set( 'snp_fake_haplotype', 'on', 'on' );
    $Configs->{'snps'}->set( 'TSV_haplotype_legend', 'on', 'on' );
    $Configs->{'snps'}->{'snp_fake_haplotype'}  =  $haplotype;
  }
  $Configs->{'snps'}->container_width(   $snp_fake_length   );
  $Configs->{'snps'}->{'snps'}        = \@fake_snps;
  $Configs->{'snps'}->{'reference'}   = $object->param('reference')|| "";
  $Configs->{'snps'}->{'fakeslice'}   = 1;
  $Configs->{'snps'}->{'URL'} =  $base_URL;
  return if $do_not_render;

  ## -- Render image ----------------------------------------------------- ##
  # Send the image pairs of slices and configurations
  my $image    = $object->new_image(
    [
     $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
     $object->__data->{'slices'}{'transcript'}[1],  $Configs->{'transcript'},
     $transcript_slice, $Configs->{'transcripts_top'},
     @$containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
     $transcript_slice, $Configs->{'snps'},
    ],
    [ $object->stable_id ]
  );

  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );

  return 0;
}




sub _sample_configs {
  my ($object, $transcript_slice, $sub_slices, $fake_length) = @_;

  my @containers_and_configs = (); ## array of containers and configs
  my @haplotype = ();
  my $extent = tsv_extent($object);

  # THIS IS A HACK. IT ASSUMES ALL COVERAGE DATA IN DB IS FROM SANGER fc1
  # Only display coverage data if source Sanger is on
  my $display_coverage = $object->get_viewconfig->get( "opt_sanger" ) eq 'off' ? 0 : 1;

  foreach my $sample ( $object->get_samples ) {
    my $sample_slice = $transcript_slice->get_by_strain( $sample );
    next unless $sample_slice;

    ## Initialize content...
    my $sample_config = $object->get_imageconfig( "TSV_sampletranscript" );
    $sample_config->{'id'}         = $object->stable_id;
    $sample_config->{'subslices'}  = $sub_slices;
    $sample_config->{'extent'}     = $extent;

    ## Get this transcript only, on the sample slice
    my $transcript;

    foreach my $test_transcript ( @{$sample_slice->get_all_Transcripts} ) {
      next unless $test_transcript->stable_id eq $object->stable_id;
      $transcript = $test_transcript;  # Only display on e transcripts...
      last;
    }
    next unless $transcript;

    my $raw_coding_start = defined( $transcript->coding_region_start ) ? $transcript->coding_region_start : $transcript->start;
    my $raw_coding_end   = defined( $transcript->coding_region_end )   ? $transcript->coding_region_end : $transcript->end;
    my $coding_start = $raw_coding_start + $object->munge_gaps( 'TSV_transcript', $raw_coding_start );
    my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'TSV_transcript', $raw_coding_end );

    my @exons = ();
    foreach my $exon (@{$transcript->get_all_Exons()}) {
      my $es = $exon->start;
      my $offset = $object->munge_gaps( 'TSV_transcript', $es );
      push @exons, [ $es + $offset, $exon->end + $offset, $exon ];
    }

    my ( $allele_info, $consequences ) = $object->getAllelesConsequencesOnSlice($sample, "TSV_transcript", $sample_slice);
    my ($coverage_level, $raw_coverage_obj) = ([], []);
    if ($display_coverage) {
      ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);
    }
    my $munged_coverage = $object->munge_read_coverage($raw_coverage_obj);

    $sample_config->{'transcript'} = {
      'sample'          => $sample,
      'exons'           => \@exons,  
      'coding_start'    => $coding_start,
      'coding_end'      => $coding_end,
      'transcript'      => $transcript,
      'allele_info'     => $allele_info,
      'consequences'    => $consequences,
      'coverage_level'  => $coverage_level,
      'coverage_obj'    => $munged_coverage,
    };
    unshift @haplotype, [ $sample, $allele_info, $munged_coverage ];

warn "#### $sample\n";
warn map { "  >> @$_\n" } @$allele_info;
#warn map { "  << @$_\n" } @$munged_coverage;
    $sample_config->container_width( $fake_length );
  
    ## Finally the variation features (and associated transcript_variation_features )...  Not sure exactly which call to make on here to get 

    ## Now push onto config hash...
    push @containers_and_configs,    $sample_slice, $sample_config;
  } #end foreach sample

  return (\@containers_and_configs, \@haplotype);
}



sub tsv_extent {
  my $object = shift;
  return $object->param( 'context' ) eq 'FULL' ? 1000 : $object->param( 'context' );
}


sub transcriptsnpview_menu    {
  my ($panel, $object) = @_;
  my $valids = $object->valids;

  my @onsources;
  map {  push @onsources, $_ if $valids->{lc("opt_$_")} }  @{$object->get_source || [] };

  my $text;
  my @populations = $object->get_samples('display');
  if ( $onsources[0] ) {
    $text = " from these sources: " . join ", ", @onsources if $onsources[0];
  }
  else {
    $text = ". Please select a source from the yellow 'Source' dropdown menu" if scalar @populations;
  }
  $panel->print("<p>Where there is resequencing coverage, SNPs have been called using a computational method.  Here we display the SNP calls observed by transcript$text.  </p>");

  my $image_config = $object->image_config_hash( 'TSV_sampletranscript' );
  $image_config->{'Populations'}    = \@populations;


  my $individual_adaptor = $object->Obj->adaptor->db->get_db_adaptor('variation')->get_IndividualAdaptor;
  $image_config->{'snp_haplotype_reference'}    =  $individual_adaptor->get_reference_strain_name();

  my $strains = ucfirst($object->species_defs->translate("strain"))."s";

  return 0;
}
# PAGE DUMP METHODS -------------------------------------------------------

sub dump {
  my ( $panel, $object ) = @_;
  my $strain = $object->species_defs->translate("strain");
  $panel->print("<p>Dump of SNP data per $strain (SNPs in rows, $strain","s in columns).  For more advanced data queries use <a href='/biomart/martview'>BioMart</a>. </p>");
  my $html = qq(
   <div>
     @{[ $panel->form( 'dump_form' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}


sub dump_form {
  my ($panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new('tsvview_form', "/@{[$object->species]}/transcriptsnpdataview", 'get' );

  my  @formats = ( {"value" => "astext",  "name" => "Text format"},
        #          {"value" => "asexcel", "name" => "In Excel format"},
                   {"value" => "ashtml",  "name" => "HTML format"}
                 );

  return $form unless @formats;
  $form->add_element( 'type'  => 'Hidden',
                      'name'  => '_format',
                      'value' => 'ashtml' );
  $form->add_element(
    'class'     => 'radiocheck1col',
    'type'      => 'DropDown',
    'renderas'  => 'checkbox',
    'name'      => 'dump',
    'label'     => 'Dump format',
    'values'    => \@formats,
    'value'     => $object->param('dump') || 'astext',
  );

  $form->add_element (
                           'type'      => 'Hidden',
                           'name'      => 'transcript',
                           'value'     => $object->param('transcript'),
         );

  my @cgi_params = @{$panel->get_params($object, {style =>"form"}) };
  foreach my $param ( @cgi_params) {
       $form->add_element (
                          'type'      => 'Hidden',
                          'name'      => $param->{'name'},
                          'value'     => $param->{'value'},
                          'id'        => "Other param",
                         );
  }


 $form->add_element(
    'type'      => 'Submit',
    'name'      => 'submit',
    'value'     => 'Dump',
                    );

=pod
## TODO - Replace this inline javascript with a class name and function
  $form->add_attribute( 'onSubmit',
  qq(this.elements['_format'].value='HTML';this.target='_self';flag='';for(var i=0;i<this.elements['dump'].length;i++){if(this.elements['dump'][i].checked){flag=this.elements['dump'][i].value;}}if(flag=='astext'){this.elements['_format'].value='Text';this.target='_blank'}if(flag=='gz'){this.elements['_format'].value='Text';})
    );
=cut

  return $form;
}


sub html_dump {
  my( $panel, $object ) = @_;

  my $view_config = $object->get_viewconfig;
  $view_config->reset;
  foreach my $param ( $object->param() ) {
    $view_config->set($param, $object->param($param) , 1);
  }
  # $view_config->save;
  my @samples = sort ( $object->get_samples );

  my $snp_data = get_page_data($panel, $object, \@samples );
  unless (ref $snp_data eq 'HASH') {
    $panel->print("<p>No data in this region.");
    return;
  }

  $panel->print("<p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>\n");
  my $header_row = join "</th><th>", ("bp position", @samples);
  $panel->print("<table class='ss tint'>\n");
  $panel->print("<tr><th>$header_row</th></tr>\n");

  my @background = ('class="bg2"', ""); 
  my $image_config = $object->image_config_hash( 'genesnpview_snps' );
  my %colours = $image_config->{'_colourmap'}->colourSet('variation');

  foreach my $snp_pos ( sort keys %$snp_data ) {
    my $background= shift @background;
    push @background, $background;
    $panel->print(qq(<tr $background><td>$snp_pos</td>));
    foreach my $sample ( @samples ) {
      my @info;
      my $style;

      foreach my $row ( @{$snp_data->{$snp_pos}{$sample} || [] } ) {
  (my $type = $row->{consequence}) =~ s/\(Same As Ref. Assembly\)//;
  if ($row->{ID}) {
    if ($row->{aachange} ne "-") {
      my $colour = $image_config->{'_colourmap'}->hex_by_name($colours{$type}[0]);
      $style = qq(style="background-color:#$colour");
    }
    push @info, "$row->{ID}; $type; $row->{aachange};";
  }
  else {
    push @info, "<td>.</td>";
  }
      }
      my $print = join "<br />", @info;
      $panel->print("<td $style>$print</td>");
    }
    $panel->print("</tr>\n");
  }
  $panel->print("\n</table>");
  return 1;
}

sub text_dump {
  my( $panel, $object ) = @_;

  my $view_config = $object->get_viewconfig;
  $view_config->reset;
  foreach my $param ( $object->param() ) {
    $view_config->set($param, $object->param($param) , 1);
  }
  # $view_config->save;
  my @samples = sort ( $object->get_samples );
  $panel->print("Variation data for ".$object->stable_id);
  $panel->print("\nFormat: tab separated per strain (SNP id; Type; Amino acid change;)\n\n");

  my $snp_data = get_page_data($panel, $object, \@samples );
  unless (ref $snp_data eq 'HASH') {
    $panel->print("No data in this region.");
    return;
  }

  my $header_row = join "\t", ("bp position", @samples);
  $panel->print("$header_row\n");

  foreach my $snp_pos ( sort keys %$snp_data ) {
    $panel->print(qq($snp_pos\t));
    foreach my $sample ( @samples ) {
      foreach my $row ( @{$snp_data->{$snp_pos}{$sample} || [] }) {
  (my $type = $row->{consequence}) =~ s/\(Same As Ref. Assembly\)//;;
  my $info = $row->{ID} ? "$row->{ID}; $type; $row->{aachange}; " : ".";
  $panel->print(qq($info));
      }
      $panel->print("\t");
    }
    $panel->print("\n");
  }
  $panel->print("\n");
  return 1;
}

sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;
  
  my $i = 0;
  
  my $title = {
    'delete' => sub { return "Deletion: $_[0]->{'alleles'}" },
    'insert' => sub { shift; $_->{'alleles'} = join '', @{$_->{'nt'}}; $_->{'alleles'} = Bio::Perl::translate_as_string($_->{'alleles'}); return "Insert: $_->{'alleles'}" },
    'frameshift' => sub { return "Frame-shift" },
    'snp' => sub { return "Residues: $_[0]->{'pep_snp'}" },
    'syn' => sub { my $p = shift; my $t = ''; $t .= $p->{'ambigcode'}[$_] ? '('.$p->{'ambigcode'}[$_].')' : $p->{'nt'}[$_] for (0..2); return "Codon: $t" },
    'transcript' => sub { return "Alleles: $_[0]->{'alleles'}" } # All transcript variations have the same title format
  };

  foreach my $data (@$markup) {
    foreach (sort {$a <=> $b} keys %$data) {
      my $type = $data->{$_}->{'variation'};
      
      next unless $type;
      
      $sequence->[$i]->[$_]->{'title'} = &{$title->{$type}}($data->{$_}) if $title->{$type};
      
      if ($type eq 'transcript') {
        $sequence->[$i]->[$_]->{'background-color'} = $config->{'translation'} ?  $config->{'colours'}->{"$data->{$_}->{'snp'}$data->{$_}->{'bg'}"} : $config->{'colours'}->{'snp_default'};
      } else {
        $sequence->[$i]->[$_]->{'background-color'} = $config->{'colours'}->{$type} if $type;
      }
    }
    
    $i++;
  }

  $config->{'v_space'} = "\n";
}

1;
