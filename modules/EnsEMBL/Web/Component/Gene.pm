package EnsEMBL::Web::Component::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component::Slice;
use EnsEMBL::Web::RegObj;

use EnsEMBL::Web::Form;

use Data::Dumper;
use Bio::AlignIO;
use IO::String;
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);
our %do_not_copy = map {$_,1} qw(species type view db transcript gene);

sub Summary {
  my( $panel, $object ) =@_;

  my $description = escapeHTML( $object->gene_description() );
  if( $description ) {
    $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/EC_URL($object,$1)/e;
    $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
    my($edb, $acc) = ($1, $2);
    $description .= qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) if $acc;
    $panel->add_description( $description );
  }

## Now a link to location;

  my $url = $object->_url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->seq_region_name.':'.$object->seq_region_start.'-'.$object->seq_region_end
  });

  my $location_html = sprintf( '<a href="%s">%s: %s-%s</a> %s',
    $url,
    $object->neat_sr_name( $object->coord_system, $object->seq_region_name ),
    $object->thousandify( $object->seq_region_start ),
    $object->thousandify( $object->seq_region_end ),
    $object->seq_region_strand < 0 ? ' reverse strand' : ' forward strand'
  );

  $panel->add_row( 'Location', $location_html );

## Now create the transcript information...
  my $transcripts = $object->Obj->get_all_Transcripts;
  my $count = @$transcripts;
  if( $count > 1 ) {
    my $transcript = $object->core_objects->{'parameters'}{'t'};
    my $html = '
        <table id="transcripts" style="display:none">';
    foreach( sort { $a->stable_id cmp $b->stable_id } @$transcripts ) {
      my $url = $object->_url({
        'type'   => 'Transcript',
        'action' => 'Summary',
        't'      => $_->stable_id
      });
      $html .= sprintf( '
          <tr%s>
            <th>%s</th>
            <td><a href="%s">%s</a></td>
          </tr>',
	$_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id
      );
    }
    $html .= '
        </table>';
    $panel->add_row( 'Transcripts', sprintf(q(
        <p id="transcripts_text">There are %d transcripts in this gene:</p>
        %s), $count, $html ));
  }
}

#sub URL {
#  my( $object, $parameters ) = @_;
#  my $extra_parameters = '';
#  foreach ( keys %$parameters ) {
#    $extra_parameters .= sprintf( ';%s=%s',
#      CGI::escape( $_ ),
#      CGI::escape( $parameters->{$_} )
#    ) unless $do_not_copy{$_};
#  }
#  my( $type, $stable_id ) = exists( $parameters->{'transcript'} ) ? ('transcript',$parameters->{'transcript'})
#                          : exists( $parameters->{'gene'}       ) ? ('gene',      $parameters->{'gene'})
#                          : exists( $object->{'transcript'}     ) ? ('transcript',$object->{'transcript'})
#                          :                                         ('gene',      $object->stable_id)
#                          ;
#  return sprintf( '%s%s/%s/%s%s?db=%s;%s=%s%s',
#    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT,
#    exists( $parameters->{'species'} ) ? $parameters->{'species'} : $object->species,
#    exists( $parameters->{'type'   } ) ? $parameters->{'type'}    : $ENV{'ENSEMBL_TYPE'}||'Gene',
#    exists( $parameters->{'view'   } ) ? $parameters->{'view'}    : $object->script,
#    exists( $parameters->{'db'     } ) ? $parameters->{'db'}      : $object->get_db,
#    $type,
#    $stable_id,
#    $extra_parameters
#  );
#}

sub transcript_links {
  my( $panel, $gene ) = @_;
  my $label    = 'Transcripts';
  my $gene_stable_id = $gene->stable_id;
  my $db = $gene->get_db() ;
  my $status   = 'status_gene_transcripts';
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

##----------------------------------------------------------------##
## This panel has two halves...                                   ##
## ... the top is a table of all the transcripts in the gene ...  ##
##----------------------------------------------------------------##

  my $rows = '';
  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts()};
  my $extra = @trans>17?'<p><strong>A large number of transcripts have been returned for this gene. To reduce render time for this page the protein and transcript  information will not be displayed. To view this information please follow the transview and protview links below. </strong></p>':'';
  foreach my $transcript ( @trans ) {
    $rows .= qq(\n  <tr>\n);
        if( $transcript->display_xref ) {
      my ($trans_display_id, $db_name, $ext_id) = $transcript->display_xref();
      if( $ext_id ) {
        $trans_display_id = $gene->get_ExtURL_link( $trans_display_id, $db_name, $ext_id );
      }
      $rows .= "<td>$trans_display_id</td>";
    } else {
      $rows.= "<td>novel transcript</td>";
    }
        my $trans_stable_id = $transcript->stable_id;
#       $rows .= qq(<td><a href="$trans_stable_id">$trans_stable_id</a></td>);
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= "<td>$pep_stable_id</td>";
    } else {
      $rows .= "<td>no translation</td>";
    }
    $rows .= sprintf '
    <td>[<a href="%s">Transcript&nbsp;info</a>]</td>', $gene->URL( 'script' => 'transview', 'db' => $db, 'transcript' => $trans_stable_id );
    $rows .= sprintf '
    <td>[<a href="%s">Exon&nbsp;info</a>]</td>', $gene->URL( 'script' => 'exonview', 'db' => $db, 'transcript' => $trans_stable_id );
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= sprintf '
    <td>[<a href="%s">Peptide&nbsp;info</a>]</td>', $gene->URL( 'script' => 'protview', 'db' => $db, 'peptide' => $pep_stable_id );
    }
    $rows .= "\n  </tr>";
  }
  $panel->add_content(
     qq(<table style="width:100%">$rows</table>\n)
  );
}

sub markup_options {
  my( $panel, $object ) =@_;
  $panel->add_row( 'Markup options', "<div>@{[ $panel->form( 'markup_options' )->render ]}</div>" );
  return 1;
}

sub markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'markup_options', "/@{[$object->species]}/geneseqview", 'get' );
  $form = gene_options_form($panel, $object, $form, "additional exons");
  $form->add_element(
    'type'  => 'Submit', 'value' => 'Update'
  );
  return $form;
}

sub gene_options_form {
  my( $panel, $object, $form, $exon_type ) = @_;

  # make array of hashes for dropdown options
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',   'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'gene', 'value' => $object->stable_id );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
    'value' => $object->param('flank5_display')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
    'value' => $object->param('flank3_display')
  );

  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) ||
    'Ensembl';
  my $exon_display = [
    { 'value' => 'core'       , 'name' => "$sitetype exons" },
    $object->species_defs->databases->{'ENSEMBL_VEGA'} ? { 'value' => 'vega', 'name' => 'Vega exons' } : (),
    $object->species_defs->databases->{'ENSEMBL_OTHEFEATURES'}  ? { 'value' => 'otherfeatures'  , 'name' => 'EST-gene exons' } : (),
    { 'value' => 'Ab-initio' , 'name' => 'Ab-initio exons' },
    { 'value' => 'off'        , 'name' => 'No exon markup' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_display',
    'label'    => ucfirst($exon_type).' to display',
    'values'   => $exon_display,
    'value'    => $object->param('exon_display')
  );
  my $exon_ori = [
    { 'value' =>'fwd' , 'name' => 'Display same orientation exons only' },
    { 'value' =>'rev' , 'name' => 'Display reverse orientation exons only' },
    { 'value' =>'all' , 'name' => 'Display exons in both orientations' }
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => "Orientation of $exon_type",
    'values'   => $exon_ori,
    'value'    => $object->param('exon_ori')
  );
  if( $object->species_defs->databases->{'ENSEMBL_VARIATION'} ) {
    my $snp_display = [
     { 'value' =>'snp' , 'name' => 'Yes' },
     { 'value' =>'snp_link' , 'name' => 'Yes and show links' },
     { 'value' =>'off' , 'name' => 'No' },
    ];
    $form->add_element(
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => $snp_display,
      'value'    => $object->param('snp_display')
    );
  }
  my $line_numbering = [
    { 'value' =>'sequence' , 'name' => 'Relative to this sequence' },
    { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
    { 'value' =>'off'      , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'line_numbering',
    'label'    => 'Line numbering',
    'values'   => $line_numbering,
    'value'    => $object->param('line_numbering')
  );

  return $form;
}

sub alignment_options_form {
  my( $panel, $object, $form ) = @_;

  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "Alignment width",  'name' => 'display_width',
    'value' => $object->param('display_width'),
    'notes' => 'Number of bp per line in alignments'
  );

  my $conservation = [
    { 'value' =>'all' , 'name' => 'All conserved regions' },
    { 'value' =>'off' , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'conservation',
    'label'    => 'Conservation regions',
    'values'   => $conservation,
    'value'    => $object->param('conservation'),
  );

  my $codons_display = [
    { 'value' =>'all' , 'name' => 'START/STOP codons' },
    { 'value' =>'off' , 'name' => "Do not show codons" },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'codons_display',
    'label'    => 'Codons',
    'values'   => $codons_display,
    'value'    => $object->param('codons_display'),
  );

  my $title_display = [
    { 'value' =>'all' , 'name' => 'Include `title` tags' },
    { 'value' =>'off' , 'name' => 'None' },
  ];
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'title_display',
    'label'    => 'Title display',
    'values'   => $title_display,
    'value'    => $object->param('title_display'),
    'notes'    => "On mouse over displays exon IDs, length of insertions and SNP\'s allele",
  );

  return $form;
}

sub sequence_markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'markup_options', "/@{[$object->species]}/sequencealignview", 'get' );
  $form = gene_options_form($panel, $object, $form, 'exons');
  $form = alignment_options_form($panel, $object, $form);
  my $species =  $object->species_defs->SPECIES_COMMON_NAME || $object->species;

  my $refslice;
  eval {
    $refslice = $object->get_slice_object;
  };
  if ($@) {
    warn $@;
    return $form;
  }
  my %selected_species = map { $_ => 1} $object->param('individuals');

  my %reseq_strains;
  map { $reseq_strains{$_->name} = 1; } (  $refslice->get_individuals('reseq') );
  my $golden_path = $refslice->get_individuals('reference');
  my $individuals = {};
  foreach ( $refslice->get_individuals('display') ) {
    my $key = $_ eq $golden_path   ? 'ref' :
               $reseq_strains{$_} ? 'reseq' : 'other';
    if ( $selected_species{'all'} or $selected_species{$_} ) {
      push @{$individuals->{$key}}, {'value' => $_, 'name'=> $_, 'checked'=>'yes'};
    } else {
      push @{$individuals->{$key}}, {'value' => $_, 'name'=> $_};
    }
  }

  my $strains =  $object->species_defs->translate( 'strain' );
  $form->add_element(
     'type'     => 'NoEdit',#MultiSelect',
     #'name'     => 'individuals',
     'label'    => "Reference $strains:",
     #'values'   =>  $individuals->{'ref'},
     'value'    => "$golden_path",#$object->param('individuals'),
   ) if $individuals->{'ref'};

  $strains .= "s";
  $form->add_element(
    'type'     => 'MultiSelect',
    'name'     => 'individuals',
    'label'    => "Show all $strains",
    'values'   => [{ 'value' =>'all' ,  'name' => "All $strains" }],
    'value'    => $object->param('individuals'),
  ) unless $selected_species{'all'};


 $form->add_element(
    'type'     => 'MultiSelect',
    'name'     => 'individuals',
    'label'    => "Resequenced $species $strains",
    'values'   => $individuals->{'reseq'},
    'value'    => $object->param('individuals'),
  ) if $individuals->{'reseq'};


  $form->add_element(
                       'type'     => 'MultiSelect',
                       'name'     => 'individuals',
                       'label'    => "Other $species $strains",
                       'values'   => $individuals->{'other'},
                       'value'    => $object->param('individuals'),
                      ) if $individuals->{'other'};
  $form->add_element(
    'type'  => 'Submit', 'value' => 'Update'
  );
  return $form;
}

sub align_markup_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'markup_options', "/@{[$object->species]}/geneseqalignview", 'get' );
  $form = gene_options_form($panel, $object, $form, "exons");
  $form = alignment_options_form($panel, $object, $form);

#    { 'value' =>'exon', 'name' => 'Conserved regions within exons' },

  my $aselect = $object->param("RGselect") || "NONE";

  my %alignments = $object->species_defs->multiX('ALIGNMENTS');

# From release to release the alignment ids change so we need to
# check that the passed id is still valid.

  if (! exists ($alignments{$aselect})) {
      $aselect = 'NONE';
      $object->param("RGselect", "NONE");
  }

## onclick action select_child_boxes needs replacing with generic mechanism
  $form->add_element('type' => 'RadioGroup',
         'name' => 'RGselect',
         'values' =>[{name=> "<b>No alignments</b>", value => "NONE", checked => $aselect eq "NONE" ? "yes" : undef}],
         'label' => 'View in alignment with',
         'noescape' => 'yes',
         );
  my @align_select;
  my $pairwise_header = 0;

  foreach my $id (
      sort { 10 * ($alignments{$b}->{'type'} cmp $alignments{$a}->{'type'}) + ($a <=> $b) }
      grep { $alignments{$_}->{'species'}->{$object->species} }
      keys (%alignments)) {

      my $label = $alignments{$id}->{'name'};
      my @species = grep {$_ ne $object->species} sort keys %{$alignments{$id}->{'species'}};

      my @multi_species;
      if ( scalar(@species) > 1) {
        my %selected_species = map { $_ => 1} $object->param("ms_$id");

        foreach my $v (@species) {
          (my $name = $v) =~ s/_/ /g;
          if ($selected_species{$v}) {
            push @multi_species, {"value"=>$v, "name"=>$name, "checked"=>"yes"};
          } else {
            push @multi_species, {"value"=>$v, "name"=>$name};
          }
        }
        $label = "<b>$label</b>";

      } else {
        ($label = "<b>$species[0]</b>") =~ s/_/ /g;
      }

      if (!$pairwise_header && scalar(@species) == 1) {
        $form->add_element('type' => 'NoEdit',
          'name' => 'pairwise_header',
          'value' => '<span style="color:#933;font-weight:bold">Pairwise alignments:</span>',
        );
        $pairwise_header = 1;
      }

      my $count = scalar(@multi_species);
## onclick action select_child_boxes needs replacing with generic mechanism
      $form->add_element('type' => 'RadioGroup',
       'name' => 'RGselect',
       'values' =>  [{name=> $label, 'value' => $id, checked=>$aselect eq "$id" ? "yes" : undef}],
       'label' => '     ',
       'class' => 'radiocheck1col',
       'noescape' => 'yes',
      );
      #warn "Element ".$element->id." ($element)";
      #$element->onclick('select_child_boxes()');

      if (@multi_species) {
        $form->add_element(
           'type' => 'MultiSelect',
           'name'=> "ms_$id",
#           'label'=> ' ',
           'values' => \@multi_species,
           'value' => $object->param("ms_$id")
           );
      }

  }

  $form->add_element(
    'type'  => 'Submit', 'value' => 'Update'
  );

  return $form;
}

sub user_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $uri  = CGI::escape($ENV{'REQUEST_URI'});
  my $html;
  my $stable_id = $object->stable_id;
  my @annotations = $user->annotations;
  if ($#annotations > -1) {
    $html .= "<ul>";
    foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
      warn "CREATED AT: " . $annotation->created_at;
      if ($annotation->stable_id eq $stable_id) {
        $html .= "<li>";
        $html .= "<b>" . $annotation->title . "</b><br />";
        $html .= $annotation->annotation;
        $html .= "<br /><a href='/common/user/annotation?dataview=edit;url=$uri;id=" . $annotation->id . ";stable_id=$stable_id'>Edit</a>";
        $html .= " &middot; <a href='/common/user/annotation?dataview=delete;url=$uri;id=" . $annotation->id . "'>Delete</a>";
        $html .= "</li>";
      }
    }
    $html .= "</ul>";
  }

  $html .= "<a href='/common/user/annotation?url=" . $uri . ";stable_id=" . $stable_id . "'>Add new note</a>";

  $panel->add_row('Your notes', $html);

}

sub group_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @groups = $user->groups;
  my $uri = CGI::escape($ENV{'REQUEST_URI'});
  my $stable_id = $object->stable_id;
  my $html;
  my $found = 0;
  my %included_annotations = ();
  foreach my $annotation ($user->annotations) {
    if ($annotation->stable_id eq $stable_id) {
      $included_annotations{$annotation->id} = "yes";
    }
  }
  foreach my $group (@groups) {
    my $title_added = 0;
    my $group_annotations = 0;
    my @annotations = $group->annotations;
    foreach my $annotation (@annotations) {
      if ($annotation->stable_id eq $stable_id) {
        $group_annotations = 1;
      }
    }
    if ($group_annotations) {
      if (!$title_added) {
        $html .= "<h4>" . $group->name . "</h4>";
        $title_added = 1;
      }
      $html .= "<ul>";
      foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
        if (!$included_annotations{$annotation->id}) {
          $found = 1;
          $html .= "<li>";
          $html .= "<b>" . $annotation->title . "</b><br />";
          $html .= $annotation->annotation;
          $html .= "</li>";
          $included_annotations{$annotation->id} = "yes";
        }
      }
      $html .= "</ul>";
    }
  }
  if ($found) {
    $panel->add_row('Group notes', $html);
  }
}


sub name {
  my( $panel, $object ) = @_;
  my $page_type= $object->[0];
  my $site_type = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));
  my $sp = $object->species_defs->SPECIES_COMMON_NAME;

  ##add links to Vega or Ensembl depending on the source of the transcript
  my @vega_info=();
  my $url_name   = ($object->get_db eq 'vega') ? 'Ensembl' : 'Vega';
  if($page_type eq 'Transcript'){
    my $trans= $object->transcript;
    my @similarity_links= @{$object->get_similarity_hash($trans)};
    my @vega_links;
    #add links to Ensembl from ensembl-vega
    if ($object->get_db eq 'vega') {
		foreach my $link (@similarity_links) {
			#remove redundancy
			if ($link->dbname =~ /ENST/ ) {
				if ($link->dbname eq 'ENST_ident') {
					@vega_links = ( $link ) ;
					last;
				}
				@vega_links = ( $link );
			}
		}
    }
    #add links to Vega from Ensembl genes
    else {
		#get 'shares CDS' links out first (these are both identical and CDS shared)
		#if there aren't any then get OTTT (but only those with OTT name and NULL info_text
		foreach my $link (@similarity_links) {
			if ($link->display_id =~ /OTT/ && ! $link->info_text ) {
				if ($link->dbname =~ /shares_CDS/ ) {
					@vega_links = ( $link );
					last;
				}
				@vega_links = ( $link );
			}
		}
    }

    my $urls= $object->ExtURL;
    foreach my $link(@vega_links){
      my $id= $link->display_id;
      my $href= $urls->get_url($url_name.'_transcript', $id);
      my $db_display_name = $link->db_display_name;
      push @vega_info, [$id, $href, $db_display_name];
    }
  }
  my( $display_name, $dbname, $ext_id, $dbname_disp, $info_text ) = $object->display_xref();
  $info_text = '';
  return 1 unless defined $display_name;
  my $label = $object->type_name();
  my $lc_type = lc($label);

  #set display xref
  my $linked_display_name = $display_name;
  if( $ext_id ) {
    $linked_display_name = $object->get_ExtURL_link( $display_name, $dbname, $ext_id );
  }

  # If gene ID projected from other spp, put link on other spp geneID
  if ($dbname_disp =~/^Projected/) {
    $linked_display_name = $display_name; # i.e. don't link it
    if ($info_text) {
      $info_text =~ /from (.+) gene (.+)/;
      my ($species, $gene) = ($1, $2);
      $info_text =~ s|$species|<i>$species</i>| if $species =~ /\w+ \w+/;
      $species =~ s/ /_/;
      $info_text =~s|($gene)|<a href="/$species/geneview?gene=$gene">$gene</a> |;
    }
  }
  my $html;
  my $FLAG = 1;
  if ($dbname_disp =~/(HGNC|ZFIN)/){
    #warn "GETTING HGNC/ZFIN synonyms...";
    my ($disp_table, $HGNC_table) = @{get_HGNC_synonyms($object)};
    if ($object->get_db eq 'vega') {
            $html = $disp_table;
    } else   {
            if($HGNC_table=~/tr/){
        $html = $HGNC_table;
        $FLAG = 0;
            }
            if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
        my %T = map { $_->primary_id,1 } @CCDS;
        @CCDS = sort keys %T;
        $html .= qq(<p>
                This $lc_type is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }
              </p>);
            }
    }
  }
  if( $FLAG ) {
    $html = qq(<p>
           <strong>$linked_display_name</strong> $info_text ($dbname_disp)
           <span class="small">To view all $site_type genes linked to the name <a href="/@{[$object->species]}/featureview?type=Gene;id=$display_name">click here</a>.</span>
           </p>);
    if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
            my %T = map { $_->primary_id,1 } @CCDS;
            @CCDS = sort keys %T;
            $html .= qq(<p>
              This $lc_type is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }
            </p>);
    }
  }
  if(@vega_info){
      foreach my $info(@vega_info){
        my $id= $$info[0];
        my $href= $$info[1];
        my $db_display_name = $$info[2];
        $html .= qq(<p>$db_display_name: <a href="$href">$id</a></p>);
      }
        }
  $panel->add_row( $label, $html );
  return 1;
}

sub stable_id {
  my( $panel, $object ) = @_;
  my $db_type   = ucfirst($object->source) ;
  my $db        = $object->get_db;
  my $o_type    = $object->type_name;
  my $label     = "$db_type $o_type ID";
  my $geneid    = $object->stable_id ;
  return 1 unless $geneid;
  my $vega_link = '';
  if( $db eq 'vega' ){
        #hack to display Vega source names nicely
        my %matches = ('Vega_external' => 'External',
                                   'Vega_havana'   => 'Havana',
                                  );
        $label = 'Vega '.$matches{$db_type}.' '.$o_type.' ID';
    $vega_link = sprintf qq(<span class="small">[%s]</span>),
      $object->get_ExtURL_link( "View $o_type @{[$object->stable_id]} in Vega", 'VEGA_'.uc($o_type), $object->stable_id )
  }
  $panel->add_row( $label, qq(
  <p><strong>$geneid</strong> $vega_link</p>)
  );
  return 1;
}

sub email_URL {
    my $email = shift;
    return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

sub location {
  my( $panel, $object ) = @_;
  my $geneid = $object->stable_id;
  my ( $contig_name, $contig, $contig_start) = $object->get_contig_location();
  my $alt_locs = $object->get_alternative_locations;
  my $label    = 'Genomic Location';
  my $html     = '';
  my $lc_type  = lc( $object->type_name );
  if( ! $object->seq_region_name ) {
    $html .=  qq(  <p>This $lc_type cannot be located on the current assembly</p>);
  } else {
    $html .= sprintf( qq(
      <p>
        This $lc_type can be found on %s at location <a href="/%s/contigview?l=%s:%s-%s">%s-%s</a>.
      </p>),
      $object->neat_sr_name( $object->coord_system, $object->seq_region_name ),
      $object->species,
      $object->seq_region_name, $object->seq_region_start, $object->seq_region_end,
      $object->thousandify( $object->seq_region_start ),
      $object->thousandify( $object->seq_region_end )
    );

    $html .= sprintf( qq(
      <p>
        The start of this $lc_type is located in <a href="/%s/contigview?region=%s">%s</a>.
      </p>),
      $object->species, $contig, $contig_name
    );
  }

  # Haplotype/PAR locations
  if( @$alt_locs ) {
    $html .= qq(
      <p>Additionally this $lc_type is mapped to the following haplotypes/PARs:</p>
      <ul>);
    foreach my $loc (@$alt_locs){
      my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
      $html .= sprintf( qq(
        <li>
          <a href="/%s/contigview?l=%s:%s-%s">%s : %s-%s</a>
        </li>), $object->species, $altchr, $altstart, $altend, $altchr,
             $object->thousandify( $altstart ),
             $object->thousandify( $altend ));
  }
    $html .= "\n    </ul>";
  }
  $panel->add_row( $label, $html );
  return 1;
}

sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub description {
  my( $panel, $object ) = @_;
  my $description = CGI::escapeHTML( $object->gene_description() );
     $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/EC_URL($object,$1)/e;
     $description =~ s/\[\w+:([\w\/]+)\;\w+:(\w+)\]//g;
  my($edb, $acc) = ($1, $2);

  return 1 unless $description;
  my $label = 'Description';
  my $html = sprintf qq(\n     <p>%s%s</p>), $description,
    $acc ? qq( <span class="small">@{[ $object->get_ExtURL_link("Source: $edb $acc",$edb, $acc) ]}</span>) : '' ;
  $panel->add_row( $label, $html );
  return 1;

}

sub method {
  my( $panel, $gene ) = @_;
  my $db = $gene->get_db ;
  my $label = ( ($db eq 'vega' or $gene->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
  my $text = "No $label defined in database";
  my $o = $gene->Obj;
  eval {
  if( $o &&
      $o->can( 'analysis' ) &&
      $o->analysis &&
      $o->analysis->description ) {
    $text = $o->analysis->description;
  } elsif( $gene->can('gene') && $gene->gene->can('analysis') && $gene->gene->analysis && $gene->gene->analysis->description ) {
    $text = $gene->gene->analysis->description;
  } else {
    my $logic_name = $o->can('analysis') && $o->analysis ? $o->analysis->logic_name : '';
    if( $logic_name ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
      $text = "<strong>FROM CONFIG:</strong> ".$gene->species_defs->$confkey;
    }
    if( ! $text ){
      my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
      $text   = "<strong>FROM DEFAULT CONFIG:</strong> ".$gene->species_defs->$confkey;
    }
  }
  $panel->add_row( $label, sprintf(qq(<p>%s</p>), $text ));
  };
  return 1;
}

sub get_HGNC_synonyms {
  my $self = shift;
  my $species = $self->species;
  my ($display_name, $dbname, $ext_id, $dbname_disp, $info_text ) = $self->display_xref();
  my ($prefix,$name);
  #remove prefix from the URL for Vega External Genes
  if ($species eq 'Homo_sapiens' && $self->source eq 'vega_external') {
        ($prefix,$name) = split ':', $display_name;
        $display_name = $name;
  }
  my $linked_display_name = $self->get_ExtURL_link( $display_name, $dbname, $ext_id );
  if ( $prefix ) {
        $linked_display_name = $prefix . ':' . $linked_display_name;
  }

  my $site_type = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));
  my ($disp_id_table, $HGNC_table, %syns, %text_info );
  my $disp_syn = 0;
  my $matches = $self->get_database_matches;
  $self->_sort_similarity_links( @$matches );
  my $links = $self->__data->{'links'}{'PRIMARY_DB_SYNONYM'}||[];
  foreach my $link (@$links){
     my ($key, $text)= @$link;
       my $temp = $text;
       $text =~s/\<div\s*class="multicol"\>|\<\/div\>//g;
       $text =~s/<br \/>.*$//gism;
       my @t = split(/\<|\>/, $temp);
       my $id = $t[4];
       my $synonyms = get_synonyms($id, @$matches);
      if ($id =~/$display_name/){
         unless ($synonyms !~/\w/) {
          $disp_syn = 1;
          $syns{$id} = $synonyms;
         }
       }
       $text_info{$id} = $text;
       unless ($synonyms !~/\w/ || $id =~/$display_name/){
        $syns{$id} = $synonyms;
       }
  }
 my @keys = keys %syns;
 my $syn_count = @keys;
 my $width ="100%";
 $disp_id_table = qq(<table width="$width" cellpadding="4">);
 $HGNC_table = qq(<table width="$width" cellpadding="4">);

SYN: foreach my $k (keys (%text_info)){
         my $syn = $syns{$k};
         my $syn_entry;

         if ($syn_count >= 1) { $syn_entry = qq(<td>$syn</td>); }
         my $text = $text_info{$k};
         $HGNC_table .= qq(
          <tr>
           <td><strong>$text</strong> ($dbname_disp)</td>$syn_entry
           <td><span class="small"> To view all $site_type genes linked to the name <a href="/@{[$self->species]}/featureview?type=Gene;id=$k">click here</a>.</span></td>
          </tr>
         );


         if ($k=~/$display_name/){
                 #don't want to show synonyms for ensembl-vega genes
                 if ( ($species eq 'Homo_sapiens') && ($self->source eq 'vega_external') ) {
                         next SYN unless ($k eq $display_name);
                 }
                 if ($disp_syn == 1) { $syn_entry = qq(<td>$syn</td>); }
                 $disp_id_table .= qq(
       <tr>
        <td><strong>$linked_display_name</strong> ($dbname_disp)</td>$syn_entry
        <td><span class="small"> To view all $site_type genes linked to the name <a href="/@{[$self->species]}/featureview?type=Gene;id=$display_name">click here</a>.</span></td>
        </tr>
      );
         }
 }

 $disp_id_table .=qq(</table>);
 $HGNC_table .= qq(</table>);

 my @tables = ($disp_id_table, $HGNC_table);
#warn "-"x78,"\n",$disp_id_table,"\n","-"x78,"\n",$HGNC_table,"\n","-"x78,"\n\n ";
 return \@tables;
}


sub get_synonyms {
  my $match_id = shift;
  my @matches = @_;
  my $ids;
  foreach my $m (@matches){
    my $dbname = $m->db_display_name;
    my $disp_id = $m->display_id();
    if ( $dbname =~/(HGNC|ZFIN)/ && $disp_id eq $match_id){
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
    $syns = "<b>Synonyms:   </b>" .$ids;
  }
  return $syns;
}

sub alignments {
  my( $panel, $gene ) = @_;
  my $label  = 'Alignments';
  my $status = 'status_gene_alignments';
  my $FLAG = 0;
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }
  my $html = qq{<p><b>This gene can be viewed in genomic alignment with other species</b></p>} ;

  my %alignments = $gene->species_defs->multiX('ALIGNMENTS');
  my $species = $gene->species;

  foreach my $id (
    sort { 10 *($alignments{$b}->{'type'} cmp $alignments{$a}->{'type'}) + ($a <=> $b) }
    grep { $alignments{$_}->{'species'}->{$species} }
    keys (%alignments)
  ) {
    my $label = $alignments{$id}->{'name'};
    my $KEY = "opt_align_${id}";
    my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};
    if ( scalar(@species) == 1) {
     ($label = $species[0]) =~ s/_/ /g;
    }
    $html .= sprintf( qq(&nbsp;&nbsp;&nbsp;<a href="/%s/alignsliceview?l=%s:%s-%s;align=%s">view genomic alignment with <b>%s</b></a> <br/>),
       $gene->species,
       $gene->seq_region_name,
       $gene->seq_region_start,
       $gene->seq_region_end,
       $KEY,
       $label
    );
    $FLAG = 1;
  }
  if( $FLAG ) {
    $panel->add_row( $label, $html, "$URL=off" );
  }
  return 1;
}

sub orthologues {
  my( $panel, $gene ) = @_;
  my $label = 'Orthologue Prediction';
  my $status   = 'status_gene_orthologues';
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

  my $db              = $gene->get_db() ;
  my $cache_obj = cache( $panel, $gene, 'orth', join '::', $db, $gene->species, $gene->stable_id );
  my $html;
  if( $cache_obj->exists ) {
    $html = $cache_obj->retrieve();
    return 1 unless $html;
  } else {
    my $orthologue = $gene->get_homology_matches('ENSEMBL_ORTHOLOGUES');
    unless( keys %{$orthologue} ) {
      cache_print( $cache_obj, undef );
      return 1;
    }
    my %orthologue_list = %{$orthologue};

# Find the selected method_link_set
    $html = qq#
      <p>
        The following gene(s) have been identified as putative
        orthologues:
      </p>
      <p>(N.B. If you don't find a homologue here, it may be a 'between-species paralogue'.
Please view the <a href="/#.$gene->species.'/genetreeview?gene='.$gene->stable_id.qq#">gene tree info</a> or export between-species
paralogues with BioMart to see more.)</p>
      <table width="100%" cellpadding="4">
        <tr>
          <th>Species</th>
          <th>Type</th>
          <th>dN/dS</th>
          <th>Gene identifier</th>
        </tr>#;
    my %orthologue_map = qw(SEED BRH PIP RHS);

    my %SPECIES;
    my $STABLE_ID = $gene->stable_id; my $C = 1;
    my $ALIGNVIEW = 0;
    my $matching_orthologues = 0;
    my %SP = ();
    my $multicv_link = sprintf "/%s/multicontigview?gene=%s;context=10000", $gene->species, $gene->stable_id;
    my $FULL_URL     = $multicv_link;

    foreach my $species (sort keys %orthologue_list) {
      my $C_species = 1;
      my $rowspan = scalar(keys %{$orthologue_list{$species}});
      $rowspan++ if $rowspan > 1;
      $html .= sprintf( qq(
        <tr>
          <th rowspan="$rowspan"><em>%s</em></th>), $species );
      my $start = '';
      my $mcv_species = $multicv_link;
      foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
        my $OBJ = $orthologue_list{$species}{$stable_id};
        $html .= $start;
        $start = qq(
        <tr>);
        $matching_orthologues = 1;
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $orthologue_desc = $orthologue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
        my $orthologue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
         $orthologue_dnds_ratio = '&nbsp;' unless (defined $orthologue_dnds_ratio);
        my ($last_col, $EXTRA2);
        if(exists( $OBJ->{'display_id'} )) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $EXTRA = qq(<span class="small">[<a href="$multicv_link;s1=$spp;g1=$stable_id">MultiContigView</a>]</span>);
          if( $orthologue_desc ne 'DWGA' ) {
            $EXTRA .= qq(&nbsp;<span class="small">[<a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID;g1=$stable_id">Align</a>]</span> );
            $EXTRA2 = qq(<br /><span class="small">[Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}]</span>);
            $ALIGNVIEW = 1;
          }
          $mcv_species .= ";s$C_species=$spp;g$C_species=$stable_id";
          $FULL_URL    .= ";s$C=$spp;g$C=$stable_id";
          $C_species++;
          $C++;
          my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $last_col = qq(<a href="$link">$stable_id</a> (@{[$OBJ->{'display_id'}]}) $EXTRA<br />).
                      qq(<span class="small">$description</span> $EXTRA2);
        } else {
          $last_col = qq($stable_id<br /><span class="small">$description</span> $EXTRA2);
        }
        $html .= sprintf( qq(
              <td>$orthologue_desc</td>
              <td>$orthologue_dnds_ratio</td>
              <td>$last_col</td>
            </tr>));
      }
      if( $rowspan > 1) {
        $html .= qq(<tr><td>&nbsp;</td><td>&nbsp;</td><td><a href="$mcv_species">MultiContigView showing all $species orthologues</a></td></tr>); 
      }
    }
    $html .= qq(\n      </table>);
    if( keys %orthologue_list ) {
      # $html .= qq(\n      <p><a href="$FULL_URL">View all genes in MultiContigView</a>;);
      $html .= qq(\n      <p><a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID">View sequence alignments of all homologues</a>.</p>) if $ALIGNVIEW;
    }
    cache_print( $cache_obj, \$html );
    return 1 unless($matching_orthologues);
  }
  $panel->add_row( $label, $html, "$URL=off" );
  return 1;
}

sub HOMOLOGY_TYPES {
  my $self = shift;
  return {
    'BRH'  => 'Best Reciprocal Hit',
    'UBRH' => 'Unique Best Reciprocal Hit',
    'RHS'  => 'Reciprocal Hit based on Synteny around BRH',
    'DWGA' => 'Derived from Whole Genome Alignment'
  };
}


sub SIMPLEALIGN_FORMATS {
    return {
	'fasta'    => 'FASTA',
	'msf'      => 'MSF',
	'clustalw' => 'CLUSTAL',
	'selex'    => 'Selex',
	'pfam'     => 'Pfam',
	'mega'     => 'Mega',
	'nexus'    => 'Nexus',
	'phylip'   => 'Phylip',
	'psi'      => 'PSI',
    };
}

sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub renderer_type {
  my $self = shift;
  my $K = shift;
  my $T = SIMPLEALIGN_FORMATS;
  return $T->{$K} ? $K : SIMPLEALIGN_DEFAULT;
}

sub paralogues {
  my( $panel, $gene ) = @_;
  # make the paralogues panel a collapsable one
  my $label  = 'Paralogue Prediction';
  my $status = 'status_gene_paralogues';
  my $URL    = _flip_URL($gene, $status );
  if( $gene->param($status) eq 'off' ) {
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

## call table method here
  my $db              = $gene->get_db() ;
  my $cache_obj = cache( $panel, $gene, 'para', join '::', $db, $gene->species, $gene->stable_id );
  my $html;
  if( $cache_obj->exists ) {
    $html = $cache_obj->retrieve;
    return 1 unless $html;
  } else {
    my $paralogue = $gene->get_homology_matches('ENSEMBL_PARALOGUES', 'within_species_paralog');
    unless( keys %{$paralogue} ) {
      cache_print( $cache_obj, undef );
      return 1;
    }
    my %paralogue_list = %{$paralogue};
    $html = qq(
      <p>
        The following gene(s) have been identified as putative paralogues (within species):
      </p>
      <table>);
    $html .= qq(
        <tr>
          <th>Taxonomy Level</th><th>dN/dS</th><th>Gene identifier</th>
        </tr>);
    my %paralogue_map = qw(SEED BRH PIP RHS);

    my $STABLE_ID = $gene->stable_id; my $C = 1;
    my $FULL_URL  = qq(/@{[$gene->species]}/multicontigview?gene=$STABLE_ID);
    my $ALIGNVIEW = 0;
    my $EXTRA2;
    my $matching_paralogues = 0;
    foreach my $species (sort keys %paralogue_list){
 # foreach my $stable_id (sort keys %{$paralogue_list{$species}}){
      foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}){

        my $OBJ = $paralogue_list{$species}{$stable_id};
        my $matching_paralogues = 1;
        my $description = $OBJ->{'description'};
           $description = "No description" if $description eq "NULL";
        my $paralogue_desc = $paralogue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
        my $paralogue_subtype = $OBJ->{'homology_subtype'};
           $paralogue_subtype = "&nbsp;" unless (defined $paralogue_subtype);
        my $paralogue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
        $paralogue_dnds_ratio = "&nbsp;" unless ( defined $paralogue_dnds_ratio);
        if($OBJ->{'display_id'}) {
          (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
          my $EXTRA = qq(<span class="small">[<a href="/@{[$gene->species]}/multicontigview?gene=$STABLE_ID;s1=$spp;g1=$stable_id;context=1000">MultiContigView</a>]</span>);
          if( $paralogue_desc ne 'DWGA' ) {
            $EXTRA .= qq(&nbsp;<span class="small">[<a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID;g1=$stable_id">Align</a>]</span>);
            $EXTRA2 = qq(<br /><span class="small">[Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}]</span>);
            $ALIGNVIEW = 1;
          }
          $FULL_URL .= ";s$C=$spp;g$C=$stable_id";$C++;
          my $link = qq(/$spp/geneview?gene=$stable_id;db=$db);
          if( $description =~ s/\[\w+:(\w+)\;\w+:(\w+)\]//g ) {
            my ($edb, $acc) = ($1, $2);
            if( $acc ) {
              $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
            }
          }
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td> $paralogue_dnds_ratio</td>
          <td><a href="$link">$stable_id</a> (@{[ $OBJ->{'display_id'} ]}) $EXTRA<br />
              <span class="small">$description</span>$EXTRA2</td>
        </tr>);
        } else {
          $html .= qq(
        <tr>
          <td>$paralogue_subtype</td>
          <td>$stable_id <br /><span class="small">$description</span>$EXTRA2</td>
       </tr>);
        }
      }
    }
   $html .= qq(</table>);
   if( keys %paralogue_list ) {
      $html .= qq(\n      <p><a href="/@{[$gene->species]}/alignview?class=Homology;gene=$STABLE_ID">View sequence alignments of all homologues</a>.</p>) if $ALIGNVIEW;    }
   cache_print( $cache_obj, \$html );
 }

  $panel->add_row( $label, $html, "$URL=off" );
  return 1;
}

sub diseases {
  my( $panel, $gene ) = @_;

  my $omim_list = $gene->get_disease_matches;
  return 1 unless ref($omim_list);
  return 1 unless scalar(%$omim_list);

  my $label = 'Disease Matches';
  my $html  = qq(
      <p>
        This Ensembl entry corresponds to the following
        OMIM disease identifiers:
      </p>
      <dl>);
  for my $description (sort keys %{$omim_list}){
    $html.= sprintf( qq(
        <dt>%s</dt>
        <dd><ul>), CGI::escapeHTML($description) );
    for my $omim (sort @{$omim_list->{$description}}){
      my $omim_link = $omim;
      my $omim_URL = $gene->get_ExtURL('OMIM', $omim_link);
      if( $omim_URL ) {
        $omim_link = qq(<a href="$omim_URL" rel="external">$omim_link</a>);
      }
      $html.= sprintf( qq(
          <li>[Omim ID: %s] -
            <a href="/@{[$gene->species]}/featureview?type=Disease;id=%d">View disease information</a>
          </li>), $omim_link, $omim );
    }
    $html.= qq(
        </ul></dd>);
  }
  $html.= qq(
      </dl>);
  $panel->add_row( 'Disease Matches', $html );
  return 1;
}

sub das {
   my( $panel, $object ) = @_;
   my $status   = 'status_das_sources';
   my $URL = _flip_URL( $object, $status );
   EnsEMBL::Web::Component::format_das_panel($panel, $object, $status, $URL);
}

sub _flip_URL {
  my( $gene, $code ) = @_;
  return sprintf '/%s/%s?gene=%s;db=%s;%s', $gene->species, $gene->script, $gene->stable_id, $gene->get_db, $code;
}

sub transcripts {
  my( $panel, $gene ) = @_;
  warn "... $gene .... $panel ...";
  my $label    = 'Transcripts';
  my $gene_stable_id = $gene->stable_id;
  my $db = $gene->get_db() ;
  my $status   = 'status_gene_transcripts';
  my $URL = _flip_URL( $gene, $status );
  if( $gene->param( $status ) eq 'off' ) { $panel->add_row( $label, '', "$URL=on" ); return 0; }

##----------------------------------------------------------------##
## This panel has two halves...                                   ##
## ... the top is a table of all the transcripts in the gene ...  ##
##----------------------------------------------------------------##

  my $rows = '';
  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts()};
  my $extra = @trans>17?'<p><strong>A large number of transcripts have been returned for this gene. To reduce render time for this page the protein and transcript  information will not be displayed. To view this information please follow the transview and protview links below. </strong></p>':'';
  foreach my $transcript ( @trans ) {
    $rows .= qq(\n  <tr>\n);
  if( $transcript->display_xref ) {
      my ($trans_display_id, $db_name, $ext_id) = $transcript->display_xref();
      if( $ext_id ) {
        $trans_display_id = $gene->get_ExtURL_link( $trans_display_id, $db_name, $ext_id );
      }
      $rows .= "<td>$trans_display_id</td>";
    } else {
      $rows.= "<td>novel transcript</td>";
    }
  my $trans_stable_id = $transcript->stable_id;
  $rows .= qq(<td>$trans_stable_id</td>);
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= "<td>$pep_stable_id</td>";
    } else {
      $rows .= "<td>no translation</td>";
    }
    $rows .= sprintf '
    <td>[<a href="%s">Transcript&nbsp;info</a>]</td>', $gene->URL( 'script' => 'transview', 'db' => $db, 'transcript' => $trans_stable_id );
    $rows .= sprintf '
    <td>[<a href="%s">Exon&nbsp;info</a>]</td>', $gene->URL( 'script' => 'exonview', 'db' => $db, 'transcript' => $trans_stable_id );
    if( $transcript->translation_object ) {
      my $pep_stable_id = $transcript->translation_object->stable_id;
      $rows .= sprintf '
    <td>[<a href="%s">Peptide&nbsp;info</a>]</td>', $gene->URL( 'script' => 'protview', 'db' => $db, 'peptide' => $pep_stable_id );
    }
    $rows .= "\n  </tr>";
  }

##----------------------------------------------------------------##
## ... and the second part is an image of the transcripts +-10k   ##
##----------------------------------------------------------------##

  warn "............ $panel .................";
  if ($panel->is_asynchronous('transcripts')) {
#    warn "Asynchronously load transcripts";
    my $json = "{ components: [ 'EnsEMBL::Web::Component::Gene::transcripts'], fragment: {db: '".$db."', stable_id: '" . $gene->stable_id . "', species: '" . $gene->species . "'} }";
    my $html = "<div id='component_0' class='info'>Loading transcripts...</div><div class='fragment'>$json</div>";
    $panel->add_row($label . " <img src='/img/ajax-loader.gif' width='16' height='16' alt='(loading)' id='loading' />", $html, "$URL=off");
  } else {
    ## Get a slice of the gene +/- 10k either side...

    my $gene_slice = $gene->Obj->feature_Slice->expand( 10e3, 10e3 );
    $gene_slice = $gene_slice->invert if $gene->seq_region_strand < 0;
    ## Get the web_image_config
    my $wuc        = $gene->image_config_hash( 'altsplice' );
    ## We now need to select the correct track to turn on....
    ## We need to do the turn on turn off for the checkboxes here!!
    foreach( $trans[0]->default_track_by_gene ) {
      $wuc->set( $_,'on','on');
    }
    # $wuc->{'_no_label'}   = 'true';
    $wuc->{'_add_labels'} = 'true';
    $wuc->set( '_settings', 'width',  $gene->param('image_width') );

    ## Will need to add bit here to configure which tracks to turn on and off!!
    ## Get the drawable_container
    ## Now
    my  $image  = $gene->new_image( $gene_slice, $wuc, [$gene->Obj->stable_id] );
    $image->introduction       = qq($extra\n<table style="width:100%">$rows</table>\n);
    $image->imagemap           = 'yes';
    $image->set_extra( $gene );

    $panel->add_content( $image->render, "$URL=odd" );
  }

}


# Gene Regulation View -------------------------------------

sub regulation_factors {
 my($panel, $object) = @_;
  my $feature_objs = $object->features;
  return unless @$feature_objs;

  $panel->add_columns(
    {'key' =>'Location',   },
    {'key' =>'Length',  },
    {'key' =>'Sequence',},
    {'key' =>'Reg. factor',  },
    {'key' =>'Reg. feature', },
    {'key' =>'Feature analysis',},
  );

  $panel->add_option( 'triangular', 1 );
  my @sorted_features = sort { $a->display_id cmp $b->display_id} @$feature_objs;

  my $object_slice = $object->Obj->feature_Slice;
  my $offset = $object_slice->start -1;
  foreach my $feature_obj ( @sorted_features ) {
    my $row;
    my $factor_name = $feature_obj->display_label;
    my $type = $feature_obj->feature_type->name;
    my $analysis = $feature_obj->analysis->logic_name;
    #if ( $feature_obj->display_label =~/Search/){next;}
    if ($analysis =~/cisRED/){
     $factor_name =~s/\D*//;
    }elsif ($analysis =~/miRanda/){
      $factor_name =~/\D+(\d+)/;
      my @temp = split (/\:/, $factor_name);
      $factor_name = $temp[1];
    }
    my $factor_link = $factor_name? qq(<a href="/@{[$object->species]}/featureview?id=$factor_name;type=RegulatoryFactor;id=$factor_name;name=$type">$factor_name</a>) : "unknown";
    my $feature_name = $feature_obj->display_label;
    my $db_ent = $feature_obj->get_all_DBEntries;
    my $seq_name = $feature_obj->slice->seq_region_name;
    my $position =  $object->thousandify( $feature_obj->start ). "-" .
      $object->thousandify( $feature_obj->end );
    $position = qq(<a href="/@{[$object->species]}/contigview?c=$seq_name:).$feature_obj->start.qq(;w=100">$seq_name:$position</a>);

    $feature_obj->{'start'} =  $feature_obj->{'start'} - $offset  ;
    $feature_obj->{'end'} = $feature_obj->{'end'} - $offset;
    my $seq = $feature_obj->seq();
    $seq =~ s/([\.\w]{60})/$1<br \/>/g;

    my $desc = $feature_obj->analysis->description;
    $desc =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;
    $row = {
      'Location'         => $position,
      'Reg. factor'      => $factor_link,
      'Reg. feature'     => "$feature_name",
      'Feature analysis' =>  $desc,
      'Length'           => $object->thousandify( length($seq) ).' bp',
            'Sequence'         => qq(<font face="courier" color="black">$seq</font>),
     };

     $panel->add_row( $row );
  }
  return 1;
}

sub gene_structure {
  my( $panel, $object ) = @_;
  my $label    = 'Gene structure';
  my $object_slice = $object->Obj->feature_Slice;
     $object_slice = $object_slice->invert if $object_slice->strand < 1; ## Put back onto correct strand!
## Now we need to extend the slice!!
  my $start = $object->Obj->start;
  my $end   = $object->Obj->end;
  my $offset = $object_slice->start -1;
  foreach my $grf ( @{ $object->features } ) {
    $grf->{'start'} += $offset;
    $grf->{'end'} += $offset;
    $start = $grf->start if $grf->start < $start;
    $end   = $grf->end   if $grf->end   > $end;
  }
  my $gr_slice = $object_slice->expand( $object->Obj->start - $start, $end - $object->Obj->end );

  my $trans = $object->get_all_transcripts;
  my $gene_track_name =$trans->[0]->default_track_by_gene;

  my $wuc = $object->get_imageconfig( 'geneview' );
     $wuc->{'geneid'} = $object->Obj->stable_id;
     $wuc->{'_draw_single_Gene'} = $object->Obj;
     $wuc->set( '_settings',          'width',       900);
     $wuc->set( '_settings',          'show_labels', 'yes');
     $wuc->set( 'ruler',              'str',         $object->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $gene_track_name,     'on',          'on');
     $wuc->set( 'regulatory_regions', 'on',          'on');
     $wuc->set( 'regulatory_search_regions', 'on',   'on');

  my $image    = $object->new_image( $gr_slice, $wuc, [] );
  $image->imagemap           = 'yes';
  $panel->print( $image->render );
}

sub factor {
  my( $panel, $object ) = @_;
    my $slice = $object->Obj->feature_Slice;
    my $fg_db = undef;
    my $db_type  = 'funcgen';
    unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
      if(!$fg_db) {
        warn("Cannot connect to $db_type db");
        return [];
      }
    }
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;
  my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
  my $cisred_search_fset = $feature_set_adaptor->fetch_by_name('cisRED search regions');
  my $external_Feature_adaptor = $fg_db->get_ExternalFeatureAdaptor;
  #my $factors = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $cisred_fset, $cisred_search_fset);
  my $factors = $object->features;

  return 1 unless @$factors;

  my $gene = $object->Obj->stable_id;
  my $html = "$gene codes for regulation factor: ";
  foreach my $factor (@$factors) {
    my $factor_name = $factor->display_label;
    $html .= qq(<a href="featureview?type=RegulatoryFactor;id=$factor_name">$factor_name</a><br />);
  }

  my $label = "Regulation factor: ";
#  $panel->add_row( $label, $html );
  return 1;
}
#-------- end gene regulation view ---------------------


sub genespliceview_menu {  return gene_menu( @_, 'genesnpview_transcript',
   [qw( Features SNPContext ImageSize THExport )] ); }

sub genetreeview_menu {
}

sub nogenetree {
  my ($panel, $object) = @_;
  my $html = qq(
    <p>This gene has no orthologues in Ensembl Compara, so a gene tree cannot be built.</p>
  );
  $panel->print( $html );
  return 1;
}


sub genesnpview_menu    {  return gene_menu( @_, 'genesnpview_transcript',
   [qw( Features  Source SNPClasses SNPValid SNPTypes SNPContext THExport ImageSize)], ['SNPHelp'] ); }

sub gene_menu {
  return 0;
}

sub genespliceview {
  my( $panel, $object ) = @_;
  return genesnpview( $panel, $object, 1 );
}

sub genesnpview {
  my( $panel, $object, $no_snps, $do_not_render ) = @_;

  my $image_width  = $object->param( 'image_width' );
  my $context      = $object->param( 'context' );
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $master_config = $object->get_imageconfig( "genesnpview_transcript" );
     $master_config->set( '_settings', 'width',  $image_width );


  # Padding-----------------------------------------------------------
  # Get 5 configs - and set width to width of context config
  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $Configs;
  my @confs = qw(context gene transcripts_top transcripts_bottom);
  push @confs, 'snps' unless $no_snps;

  foreach( @confs ) {
    $Configs->{$_} = $object->get_imageconfig( "genesnpview_$_" );
    $Configs->{$_}->set( '_settings', 'width',  $image_width );
  }
   $object->get_gene_slices( ## Written...
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'  ],
    [ 'transcripts', 'munged', $extent ]
  );

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];


  # Fake SNPs -----------------------------------------------------------
  # Grab the SNPs and map them to subslice co-ordinate
  # $snps contains an array of array each sub-array contains [fake_start, fake_end, B:E:Variation object] # Stores in $object->__data->{'SNPS'}
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $transcript_slice, $sub_slices  );
  my $start_difference =  $object->__data->{'slices'}{'transcripts'}[1]->start - $object->__data->{'slices'}{'gene'}[1]->start;

  my @fake_filtered_snps;
  map { push @fake_filtered_snps,
     [ $_->[2]->start + $start_difference,
       $_->[2]->end   + $start_difference,
       $_->[2]] } @$snps;

  $Configs->{'gene'}->{'filtered_fake_snps'} = \@fake_filtered_snps unless $no_snps;


  # Make fake transcripts ----------------------------------------------
 $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}

  my @domain_logic_names = qw(Pfam scanprosite Prints pfscan PrositePatterns PrositeProfiles Tigrfam Superfamily Smart PIRSF);
  foreach( @domain_logic_names ) {
    $object->store_TransformedDomains( $_ );    ## Stores in $transcript_object->__data->{'transformed'}{'Pfam_hits'}
  }
  $object->store_TransformedSNPS() unless $no_snps;      ## Stores in $transcript_object->__data->{'transformed'}{'snps'}


  ### This is where we do the configuration of containers....
  my @transcripts            = ();
  my @containers_and_configs = (); ## array of containers and configs

  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
## create config and store information on it...
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    my $CONFIG = $object->get_imageconfig( "genesnpview_transcript" );
    $CONFIG->{'geneid'}     = $object->stable_id;
    $CONFIG->{'snps'}       = $snps unless $no_snps;
    $CONFIG->{'subslices'}  = $sub_slices;
    $CONFIG->{'extent'}     = $extent;
      ## Store transcript information on config....
    my $TS = $trans_obj->__data->{'transformed'};
#        warn Data::Dumper::Dumper($TS);
    $CONFIG->{'transcript'} = {
      'exons'        => $TS->{'exons'},
      'coding_start' => $TS->{'coding_start'},
      'coding_end'   => $TS->{'coding_end'},
      'transcript'   => $trans_obj->Obj,
      'gene'         => $object->Obj,
      $no_snps ? (): ('snps' => $TS->{'snps'})
    };
    foreach ( @domain_logic_names ) {
      $CONFIG->{'transcript'}{lc($_).'_hits'} = $TS->{lc($_).'_hits'};
    }

    $CONFIG->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
    if( $object->seq_region_strand < 0 ) {
      push @containers_and_configs, $transcript_slice, $CONFIG;
    } else {
      ## If forward strand we have to draw these in reverse order (as forced on -ve strand)
      unshift @containers_and_configs, $transcript_slice, $CONFIG;
    }
    push @transcripts, { 'exons' => $TS->{'exons'} };
  }

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

## map snps to fake evenly spaced co-ordinates...
  my @snps2;
  unless( $no_snps ) {
    @snps2 = map {
      $fake_length+=$SNP_REL+1;
      [ $fake_length-$SNP_REL+1 ,$fake_length,$_->[2], $slice_trans->seq_region_name,
        $slice_trans->strand > 0 ?
          ( $slice_trans->start + $_->[2]->start - 1,
            $slice_trans->start + $_->[2]->end   - 1 ) :
          ( $slice_trans->end - $_->[2]->end     + 1,
            $slice_trans->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @{ $snps };
## Cache data so that it can be retrieved later...
    #$object->__data->{'gene_snps'} = \@snps2; fc1 - don't think is used
    foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
      $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
    }
  }

## -- Tweak the configurations for the five sub images ------------------ ##
## Gene context block;
  my $gene_stable_id = $object->stable_id;
  $Configs->{'context'}->{'geneid2'} = $gene_stable_id; ## Only skip background stripes...
  $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  $Configs->{'context'}->set('variation','on','off') if $no_snps;
  $Configs->{'context'}->set('snp_join','on','off') if $no_snps;
## Transcript block
  $Configs->{'gene'}->{'geneid'}      = $gene_stable_id;
  $Configs->{'gene'}->container_width( $object->__data->{'slices'}{'gene'}[1]->length() );
  $Configs->{'gene'}->set('snp_join','on','off') if $no_snps;
## Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->set('snp_join','on','off') if $no_snps;
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'geneid'}      = $gene_stable_id;
    $Configs->{$_}->{'transcripts'} = \@transcripts;
    $Configs->{$_}->{'snps'}        = $object->__data->{'SNPS'} unless $no_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->container_width( $object->__data->{'slices'}{'transcripts'}[3] );
  }
  $Configs->{'transcripts_bottom'}->set('spacer','on','off') if $no_snps;
## SNP box track...
  unless( $no_snps ) {
    $Configs->{'snps'}->{'fakeslice'}   = 1;
    $Configs->{'snps'}->{'snps'}        = \@snps2;
    $Configs->{'snps'}->container_width(   $fake_length   );
    $Configs->{'snps'}->{'snp_counts'} = [$count_snps, scalar @$snps, $context_count];
  }
  return if $do_not_render;
## -- Render image ------------------------------------------------------ ##
  my $image    = $object->new_image([
    $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
    $object->__data->{'slices'}{'gene'}[1],        $Configs->{'gene'},
    $transcript_slice, $Configs->{'transcripts_top'},
    @containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
    $no_snps ? ():($transcript_slice, $Configs->{'snps'})
  ],
  [ $object->stable_id ]
  );
  #$image->set_extra( $object );

  $image->imagemap = 'yes';

  my $T = $image->render;
  $panel->print( $T );
  return 0;
}

sub genesnpview_legend {
  ## NOT CALLED FROM ANYWHERE IN CODE - REMOVE? ap5
  my( $panel, $object ) = @_;
  $panel->print( qq(
    <p>
      <img src="/img/help/genesnpview-key.gif" height="160" width="800" border="0" alt="" />
    </p>
  ) );
  return 0;
}

sub table_info {

  ### Adds text to panel defined in Configuration::Gene
  ### just above spreadsheet tables
  ### Returns 0

  my ($panel, $object)= @_;
  $panel->print("The yellow dropdown menus at the top of the image above can be used to customise the exon context and types of SNPs displayed in both the image above and tables below.  Please note the default 'Context' settings will probably filter out some intronic SNPs.");
  return 0;
}


sub too_big {
  my( $panel, $object ) = @_;
  my $object_type = $panel->{'object_type'};
  $panel->print( qq(<p>Due to the length of this $object_type, this display is disabled as the rendering time is too long.</p>) );
  return 0;
}

sub genetreeview {
  my( $panel, $object ) = @_;

  my $databases       = $object->DBConnection->get_databases( 'core', 'compara' );
  my $comparaDBA      = $databases->{'compara'};

  my $id = $object->stable_id;
  my $clusterset_id = 0; ### WHAT IS IT ???

  my $treeDBA = $comparaDBA->get_ProteinTreeAdaptor;
  my $member = $comparaDBA->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $id);

 ( $panel->print( qq(<p style="text-align:center"><b>Could not find a tree for gene $id.</b></p>) ) and return 1) unless (defined $member);
  my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
                                                                          $member->get_longest_peptide_Member->member_id,
                                                                          $clusterset_id);
  (warn("Can't get aligned member") and return 0) unless (defined $aligned_member);

  my $node = $aligned_member->subroot;

  my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;

#  warn("Z-0:".localtime);
  my $label = "GeneTree";

  my $treeimage = create_genetree_image( $object, $tree, $member);
#  warn("Y-0:".localtime);

  my $T = $treeimage->render;
  $panel->print( $T );
#  warn("X-0:".localtime);

  return 1;
}


sub external_links {
  my( $panel, $object ) = @_;

  my $databases       = $object->DBConnection->get_databases( 'core', 'compara' );
  my $comparaDBA      = $databases->{'compara'};

  my $id = $object->stable_id;
  my $clusterset_id = 0;

  my $treeDBA = $comparaDBA->get_ProteinTreeAdaptor;
  my $member = $comparaDBA->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $id);
  return 0 unless (defined $member);
  my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
                                                                          $member->get_longest_peptide_Member->member_id,
                                                                          $clusterset_id);
  return 0 unless (defined $aligned_member);
  my $node = $aligned_member->subroot;
  my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
  $node->release_tree;
  my $label = "External Links";

  my $FN        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file      = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN";
  $object->make_directory( $file );

  my $URL       = $object->species_defs->ENSEMBL_BASE_URL.$object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN";
  if( open NHX,   ">$file" ) {
      print NHX $tree->nhx_format('simple');
      close NHX;
  }

  my $alignio = Bio::AlignIO->newFh(
                                    -fh     => IO::String->new(my $var),
                                    -format => 'fasta'
                                    );

  print $alignio $tree->get_SimpleAlign( -append_sp_short_name => 1 );
  my $FN2        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file2      = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN2";
  $object->make_directory( $file2 );
  my $URL2       = $object->species_defs->ENSEMBL_BASE_URL.$object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN2";
  if( open FASTA,   ">$file2" ) {
      print FASTA $var;
      close FASTA;
  }

  my $jalview = qq{
    <applet archive="}.($object->species_defs->ENSEMBL_BASE_URL).qq{/jalview/jalview.jar"
        code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">
      <param name="input" value="$URL2" />
      <param name="type" value="URL" />
      <param name=format value="FASTA" />
      <param name="fontsize" value="10" />
      <param name="Consensus" value="*" />
      <param name="srsServer" value="srs.sanger.ac.uk/srsbin/cgi-bin/" />
      <param name="database" value="ensemblpep" />
      <strong>Java must be enabled to view alignments</strong>
    </applet>
};

  my $html = $jalview;
  my $z_html = qq{
<script type="text/javascript" src="/js/atv.js"></script>
<form>
    <input style="background-color:white;vertical-align:top; margin: 5px; border: 1; width:70px; height:23px" type=button value="ATV" onClick="openATV(\'}.
    $object->species_defs->ENSEMBL_BASE_URL.qq{\',\'$URL\' )">
    $jalview
</form>
};

  $panel->add_row( $label, $html );
  return 1;
}

sub create_genetree_image {
  my(  $object, $tree, $member ) = @_;

  my $wuc        = $object->image_config_hash( 'genetreeview' );
  my $image_width  = $object->param( 'image_width' ) || 1200;

  $wuc->container_width($image_width);
  $wuc->set_width( $object->param('image_width') );
  $wuc->{_object} = $object;

  my $image  = $object->new_image( $tree, $wuc, [$object->stable_id, $member->genome_db->dbID] );
#  $image->cacheable   = 'yes';
  $image->image_type  = 'genetree';
  $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap           = 'yes';
  return $image;
}

1;
