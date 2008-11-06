package EnsEMBL::Web::Configuration::Gene;

use strict;
use Bio::AlignIO; # Needed for tree alignments
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Release;

use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  unless( ref $self->object ) {
    $self->{_data}{default} = 'Summary';
    return;
  }
  my $x = $self->object->availability || {};
  if( $x->{'gene'} ) {
    $self->{_data}{default} = 'Summary';
  } elsif( $x->{'idhistory'} ) {
    $self->{_data}{default} = 'Idhistory';
  } elsif( $x->{'family'} ) {
    $self->{_data}{default} = 'Family';#/Proteins';
  }
}

sub populate_tree {
  my $self = shift;
#  my $hash = $obj->get_summary_counts;

  $self->create_node( 'Summary', "Gene summary",
    [qw(summary EnsEMBL::Web::Component::Gene::GeneSummary
        transcripts EnsEMBL::Web::Component::Gene::TranscriptsImage)],
    { 'availability' => 'gene', 'concise' => 'Gene summary' }
  );

  $self->create_node( 'Splice', "Splice variants ([[counts::transcripts]])",
    [qw(image       EnsEMBL::Web::Component::Gene::GeneSpliceImage)],
    { 'availability' => 'gene', 'concise' => 'Splice variants' }
  );

  $self->create_node( 'Evidence', "Supporting evidence",
     [qw(evidence       EnsEMBL::Web::Component::Gene::SupportingEvidence)],
    { 'availability' => 'gene', 'concise' => 'Supporting evidence'}
  );

  $self->create_node( 'Sequence', "Sequence",
     [qw(sequence       EnsEMBL::Web::Component::Gene::GeneSeq)],
    { 'availability' => 'gene', 'concise' => 'Marked-up sequence'}
  );

  $self->create_node( 'Matches', "External references ([[counts::similarity_matches]])",
     [qw(matches       EnsEMBL::Web::Component::Gene::SimilarityMatches)],
    { 'availability' => 'gene', 'concise' => 'External references'}
  );

  $self->create_node( 'Regulation', 'Regulation',
    [qw(
      regulation EnsEMBL::Web::Component::Gene::RegulationImage
      features EnsEMBL::Web::Component::Gene::RegulationTable
    )],
    { 'availability' => 'gene database:funcgen' }
  );

# $self->create_node( 'XRefs', "External references",
#   [qw(xrefs EnsEMBL::Web::Component::Gene::XRefs)],
#   { 'availability' => 1, 'concise' => 'XRefs' }
# );

##----------------------------------------------------------------------
## Compara menu: alignments/orthologs/paralogs/trees
  my $compara_menu = $self->create_submenu( 'Compara', 'Comparative Genomics' );
  $compara_menu->append( $self->create_node( 'Compara_Alignments', "Genomic alignments ([[counts::alignments]])",
    [qw(
      selector   EnsEMBL::Web::Component::Gene::Compara_AlignSliceSelector
      alignments EnsEMBL::Web::Component::Gene::ComparaAlignments
    )],
    { 'availability' => 'gene database:compara core', 'concise' => 'Genomic alignments' }
  ));

## Compara tree
  my $tree_node = $self->create_node(
    'Compara_Tree', "Gene Tree",
    [qw(image        EnsEMBL::Web::Component::Gene::ComparaTree)],
    { 'availability' => 'gene database:compara core' }
  );
  $tree_node->append( $self->create_subnode(
    'Compara_Tree/Text', "Gene Tree (text)",
    [qw(treetext        EnsEMBL::Web::Component::Gene::ComparaTree/text)],
    { 'availability' => 'gene database:compara core' }
  ));

  $tree_node->append( $self->create_subnode(
    'Compara_Tree/Align',       "Gene Tree (alignment)",
    [qw(treealign      EnsEMBL::Web::Component::Gene::ComparaTree/align)],
    { 'availability' => 'gene database:compara core' }
  ));
  $compara_menu->append( $tree_node );

  my $ol_node = $self->create_node(
    'Compara_Ortholog',   "Orthologues ([[counts::orthologs]])",
    [qw(orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs)],
    { 'availability' => 'gene database:compara core', 
      'concise'      => 'Orthologues' }
  );
  $compara_menu->append( $ol_node );
  $ol_node->append( $self->create_subnode(
    'Compara_Ortholog/Alignment', 'Ortholog Alignment',
    [qw(alignment EnsEMBL::Web::Component::Gene::HomologAlignment)],
    { 'availability'  => 'gene database:compara core',
      'no_menu_entry' => 1 }
  ));
  my $pl_node = $self->create_node(
    'Compara_Paralog',    "Paralogues ([[counts::paralogs]])",
    [qw(paralogues  EnsEMBL::Web::Component::Gene::ComparaParalogs)],
    { 'availability' => 'gene database:compara core', 
           'concise' => 'Paralogues' }
  );
  $compara_menu->append( $pl_node );
  $pl_node->append( $self->create_subnode(
    'Compara_Paralog/Alignment', 'Paralog Alignment',
    [qw(alignment EnsEMBL::Web::Component::Gene::HomologAlignment)],
    { 'availability'  => 'gene database:compara core',
      'no_menu_entry' => 1 }
  ));
  my $fam_node = $self->create_node(
    'Family', 'Protein families ([[counts::families]])',
    [qw(family EnsEMBL::Web::Component::Gene::Family)],
    { 'availability' => 'gene' , 'concise' => 'Protein families' }
  );
  $compara_menu->append($fam_node);
  my $sd = ref($self->{'object'}) ? $self->{'object'}->species_defs : undef;
  my $name = $sd ? $sd->SPECIES_COMMON_NAME : '';
  $fam_node->append($self->create_subnode(
    'Family/Genes', 'Other '.$name.' genes in this family',
    [qw(genes    EnsEMBL::Web::Component::Gene::FamilyGenes)],
    { 'availability'  => 'family database:compara core',
      'no_menu_entry' => 1 }
  ));
  $fam_node->append($self->create_subnode(
    'Family/Proteins', 'Other proteins in this family',
    [qw(ensembl EnsEMBL::Web::Component::Gene::FamilyProteins/ensembl
        other   EnsEMBL::Web::Component::Gene::FamilyProteins/other)],
    { 'availability'  => 'family database:compara core',
      'no_menu_entry' => 1 }
  ));
  $fam_node->append($self->create_subnode(
    'Family/Alignments', 'Multiple alignments in this family',
    [qw(jalview EnsEMBL::Web::Component::Gene::FamilyAlignments)],
    { 'availability'  => 'family database:compara core',
      'no_menu_entry' => 1 }
  ));

=pod
  my $user_menu = $self->create_submenu( 'User', 'User data' );
  $user_menu->append( $self->create_node( 'User_Notes', "User's gene based annotation",
    [qw(manual_annotation EnsEMBL::Web::Component::Gene::UserAnnotation)],
    { 'availability' => 1 }
  ));
=cut

## Variation tree
  my $var_menu = $self->create_submenu( 'Variation', 'Genetic Variation' );

  $var_menu->append($self->create_node( 'Variation_Gene/Table',  'Variation Table',
    [qw(snptable       EnsEMBL::Web::Component::Gene::GeneSNPTable
        snpinfo       EnsEMBL::Web::Component::Gene::GeneSNPInfo)],
    { 'availability' => 'gene database:variation' }
  ));
  $var_menu->append($self->create_node( 'Variation_Gene',  'Variation Image',
    [qw(image       EnsEMBL::Web::Component::Gene::GeneSNPImage)],
    { 'availability' => 'gene database:variation' }
  ));


  # External Data tree, including non-positional DAS sources
  $self->create_node( 'ExternalData', 'External Data',
    [qw(external EnsEMBL::Web::Component::Gene::ExternalData)],
    { 'availability' => 'gene' }
  );

  my $history_menu = $self->create_submenu( 'History', 'ID History' );
  $history_menu->append($self->create_node( 'Idhistory', 'Gene history',
    [qw(display     EnsEMBL::Web::Component::Gene::HistoryReport
        associated  EnsEMBL::Web::Component::Gene::HistoryLinked
        map         EnsEMBL::Web::Component::Gene::HistoryMap)],
        { 'availability' => 'history', 'concise' => 'ID History' }
  ));

  my $export_menu = $self->create_node( 'Export', "Export gene data",
     [qw(sequence EnsEMBL::Web::Component::Gene::GeneExport)],
     { 'availability' => 'gene' }
  );
  
  my $format = { fasta => 'FASTA' };
  
  foreach (keys %$format) {
    $export_menu->append($self->create_subnode( "Export/$_", "Export gene data as $format->{$_}",
      [ "sequence" => "EnsEMBL::Web::Component::Gene::GeneExport/gene_$_" ],
      { 'availability' => 'gene', 'no_menu_entry' => 1 }
    ));
  }
}

sub user_populate_tree {
  my $self = shift;
  my $all_das  = $ENSEMBL_WEB_REGISTRY->get_all_das();
  my @active_das = qw(DS_549 Emage);
  my $ext_node = $self->tree->get_node( 'ExternalData' );
  for my $logic_name ( @active_das ) {
    my $source = $all_das->{$logic_name} || next;
    $ext_node->append($self->create_subnode( "ExternalData/$logic_name", $source->label,
      [qw(textdas EnsEMBL::Web::Component::Gene::TextDAS)],
      { 'availability' => 'gene', 'concise' => $source->caption }
    ));	 
  }
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }

sub configurator {
  return $_[0]->_configurator;
}

sub ajax_zmenu      {
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj  = $self->object;

  my $action = $obj->[1]{'_action'} || 'Summary'; 
  #warn $action;

  if( $action =~ 'Idhistory_Node'){
    return $self->ajax_zmenu_id_history_tree_node();
  }
  if( $action =~ 'Idhistory_Branch'){
    return $self->ajax_zmenu_id_history_tree_branch();
  }
   if( $action =~ 'Idhistory_Label'){
    return $self->ajax_zmenu_id_history_tree_label();
  }
  if( $action =~ 'Regulation'){
    return $self->_ajax_zmenu_regulation($panel, $obj);
  }
  if( $action eq 'Variation'){
    return $self->ajax_zmenu_variation($panel, $obj);
  }
  if( $action eq 'Variation_transcript'){
    return $self->ajax_zmenu_variation_transcript($panel, $obj);
  }
  if( $action =~ 'Compara_Tree_Node' ){
    return $self->_ajax_zmenu_compara_tree_node($panel);
  }

  my( $disp_id, $X,$Y, $db_label ) = $obj->display_xref;
  $panel->{'caption'} = $disp_id ? "$db_label: $disp_id" : 'Novel transcript';

  if( $action =~ 'Compara_Tree' ){
    my $species = $obj->species;
    $panel->add_entry({
      'type'     => 'Species',
      'label'    => $species,
      'link'     => "/$species",
      'priority' => 200
        });    

    # Link to protein sequence for cannonical or longest translation
    my $ens_tran = $obj->Obj->canonical_transcript;
    my $ens_prot;
    unless( $ens_tran ){
      my ($longest) = ( sort{ $b->[1]->length <=> $a->[1]->length } 
                        map{[$_, ( $_->translation || next ) ]} 
                        @{$obj->Obj->get_all_Transcripts} );
      ($ens_tran, $ens_prot) = @{$longest||[]};
    }
    if( $ens_prot ){
      $panel->add_entry({
        'type'     => 'Protein',
        'label'    => $ens_prot->display_id,
        'link'     => $obj->_url({
          'type'  => 'Transcript',
          'action'=> 'Sequence_Protein',
          't'     => $ens_tran->stable_id 
        }),
        'priority' => 180
      });
    }

    # Link to TreeFam
    # Currently broken!
    warn( "==> @$obj" );
    if( my $treefam_link = $obj->get_ExtURL( 'TREEFAM', $obj->stable_id ) ){
      $panel->add_entry({
        'type'     => 'TreeFam',
        'label'    => 'TreeFam',
        'link'     => $treefam_link,
        'priority' => 195,
        'extra'     => {'external' => 1}, 
      });
    }
  }

  $panel->add_entry({
    'type'     => 'Gene',
    'label'    => $obj->stable_id,
    'link'     => $obj->_url({'type'=>'Gene', 'action'=>$action}),
    'priority' => 195
  });
  $panel->add_entry({
    'type'     => 'Location',
    'label'    => sprintf( "%s: %s-%s",
                    $obj->neat_sr_name($obj->seq_region_type,$obj->seq_region_name),
                    $obj->thousandify( $obj->seq_region_start ),
                    $obj->thousandify( $obj->seq_region_end )
                  ),
    'link' => $obj->_url({'type'=>'Location',   'action'=>'View'   })
  });
  $panel->add_entry({
    'type'     => 'Strand',
    'label'    => $obj->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  if( $obj->analysis ) {
    $panel->add_entry({
      'type'     => 'Analysis',
      'label'    => $obj->analysis->display_label,
      'priority' => 2
    });
    $panel->add_entry({
      'label_html'    => $obj->analysis->description,
      'priority' => 1
    });
  }


## Protein coding transcripts only....
  return;
}

sub _ajax_zmenu_compara_tree_node{
  # Specific zmenu for compara tree nodes
  my $self = shift;
  my $panel = shift;
  my $obj = $self->object;

  my $collapse = $obj->param('collapse');
  my $node_id  = $obj->param('node') || die( "No node value in params" );
  my %collapsed_ids = map{$_=>1} grep{$_} split(',', $collapse);
  my $tree = $obj->get_ProteinTree || die( "No protein tree for gene" );
  my $node = $tree->find_node_by_node_id($node_id) 
      || die( "No node_id $node_id in ProteinTree" );
  
  my $tagvalues = $node->get_tagvalue_hash; 
  my $is_leaf = $node->is_leaf;
  my $leaf_count = scalar @{$node->get_all_leaves};
  my $parent_distance = $node->distance_to_parent || 0;

  # Caption
  my $taxon = $tagvalues->{'taxon_name'};
  if( ! $taxon  and $is_leaf ){
    $taxon = $node->genome_db->name;
  }
  $taxon ||= 'unknown';
  $panel->{'caption'} = "Taxon: $taxon";
  if( my $alias = $tagvalues->{'taxon_alias'} ){
    $panel->{'caption'} .= " ($alias)";
  }

  # Branch length
  $panel->add_entry({
    'type' => 'Branch_Length',
    'label' => $parent_distance,
    'priority' => 9,
  });

  # Bootstrap
  if( my $boot = $tagvalues->{'Bootstrap'} ){
    $panel->add_entry({
      'type' => 'Bootstrap',
      'label' => $boot,
      'priority' => 8,
    });
  }

  # Expand all nodes
  if( %collapsed_ids ){
    $panel->add_entry({
      'type'     => 'Image',
      'label'    => 'expand all sub-trees',
      'priority' => 4,
      'link'     => $obj->_url
          ({'type'     =>'Gene',
            'action'   =>'Compara_Tree',
            'collapse' => '' }),
        });
  }

  # Collapse other nodes
  my @adjacent_subtree_ids 
      = map{$_->node_id} @{$node->get_all_adjacent_subtrees};
  if( grep{ !$collapsed_ids{$_} } @adjacent_subtree_ids ){
    $panel->add_entry({
      'type'     => 'Image',
      'label'    => 'collapse other nodes',
      'priority' => 3,
      'link'     => $obj->_url
          ({'type'   =>'Gene',
            'action' =>'Compara_Tree',
            'collapse' => join( ',', 
                                (keys %collapsed_ids),
                                @adjacent_subtree_ids ) }), });
  }
  

  if( $is_leaf ){ # Leaf node
    # expand all paralogs
    my $gdb_id = $node->genome_db_id;
    my %collapse_nodes;
    my %expand_nodes;
    foreach my $leaf( @{$tree->get_all_leaves} ){
      if( $leaf->genome_db_id == $gdb_id ){
        foreach my $ancestor( @{$leaf->get_all_ancestors} ){
          $expand_nodes{$ancestor->node_id} = $ancestor;
        }
        foreach my $adjacent( @{$leaf->get_all_adjacent_subtrees} ){
          $collapse_nodes{$adjacent->node_id} = $adjacent;
        }
      }
    }
    my @collapse_node_ids = grep{! $expand_nodes{$_}} keys %collapse_nodes;
    if( @collapse_node_ids ){
      $panel->add_entry({
        'type'     => 'Image',
        'label'    => 'show all paralogs',
        'priority' => 5,
        'link'     => $obj->_url
            ({'type'     =>'Gene', 
              'action'   =>'Compara_Tree',
              'collapse' => join( ',', @collapse_node_ids ) }),
          }); 
    }
  }

  if( ! $is_leaf ){
    
    # Duplication confidence
    my $dup = $tagvalues->{'Duplication'};
    if( defined( $dup ) ){
      my $con = sprintf( "%.3f",
                         $tagvalues->{'duplication_confidence_score'} 
                         || $dup || 0 );
      $con = 'dubious' if $tagvalues->{'dubious_duplication'};
      $panel->add_entry({
        'type' => 'Type',
        'label' => ($dup ? "Duplication (confidence $con)" : 'Speciation' ),
        'priority' => 7,
      });
    }
    
    # Gene count
    $panel->add_entry({
      'type' => 'Gene_Count',
      'label' => $leaf_count,
      'priority' => 10,
    });

    # Expand this node
    if( $collapsed_ids{$node_id} ){
      $panel->add_entry({
        'type'     => 'Image',
        'label'    => 'expand this sub-tree',
        'priority' => 5,
        'link'     => $obj->_url
            ({'type'     =>'Gene', 
              'action'   =>'Compara_Tree',
              'collapse' => join( ',', 
                                  ( grep{$_ != $node_id} 
                                    keys %collapsed_ids ) ) }),
           });
    }

    # Collapse this node
    else {
      $panel->add_entry({
        'type'     => 'Image',
        'label'    => 'collapse this node',
        'priority' => 3,
        'link'     => $obj->_url
            ({'type'   =>'Gene',
              'action' =>'Compara_Tree',
              'collapse' => join( ',', $node_id, (keys %collapsed_ids) ) }),
          });
    }

    # Subtree dumps
    my( $url_align, $url_tree ) = $self->_dump_tree_as_text($node);

    $panel->add_entry({
      'type'      => 'View Sub-tree',
      'label'     => 'Tree: New Hampshire',
      'priority'  => 2,
      'link'      => $url_tree,
      'extra'     => {'external' => 1}, 
    });

    $panel->add_entry({
      'type'      => 'View Sub-tree',
      'label'     => 'Alignment: FASTA',
      'priority'  => 2,
      'link'      => $url_align,
      'extra'     => {'external' => 1},
    });

    # Jalview
    my $jalview_html 
        = $self->_compara_tree_jalview_html( $url_align, $url_tree );
    $panel->add_entry({
      'type'      => 'View Sub-tree',
      'label'     => '[Requires Java]',
      'label_html'=> $jalview_html,
      'priority'  => 1, } );
  }


  return;
}


sub _dump_tree_as_text{
  # Takes a compara tree and dumps the alignment and tree as text files.
  # Returns the urls of the files that contain the trees
  my $self = shift;
  my $tree = shift || die( "Need a ProteinTree object!" );

  # Establish some URL/file paths
  my $object = $self->object;
  my $defs   = $object->species_defs;
  my $temp_name = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file_base = $defs->ENSEMBL_TMP_DIR_IMG . "/$temp_name";
  my $file_fa   = $file_base . '.fa.png'; # .png suffix until httpd.conf fixed
  my $file_nh   = $file_base . '.nh.png';
  my $url_site  = $defs->ENSEMBL_BASE_URL;
  my $url_base  = $url_site . $defs->ENSEMBL_TMP_URL_IMG . "/$temp_name";
  my $url_fa    = $url_base . '.fa.png';
  my $url_nh    = $url_base . '.nh.png';
  $object->make_directory( $file_base );

  # Write the fasta alignment using BioPerl
  my $format = 'fasta';
  my $align = $tree->get_SimpleAlign('','','','','',1);
  my $aio = Bio::AlignIO->new( -format => $format, -file => ">$file_fa" );
  $aio->write_aln( $align );

  #and nh files
  open( NH, ">$file_nh" ) or die( "Cannot open $file_nh for write: $!" );
  print( NH $tree->newick_format("full_web") );
  close NH; 

  return( $url_fa, $url_nh );

}

our $_JALVIEW_HTML_TMPL = qq(
<applet code="jalview.bin.JalviewLite"
       width="140" height="35"
       archive="%s/jalview/jalviewApplet.jar">
  <param name="file" value="%s">
  <param name="treeFile" value="%s">
  <param name="defaultColour" value="clustal">
</applet> );

sub _compara_tree_jalview_html{
  # Constructs the html needed to launch jalview for fasta and nh file urls
  my $self = shift;
  my $url_fa = shift;
  my $url_nh = shift;
  my $url_site  = $self->object->species_defs->ENSEMBL_BASE_URL;
  my $html = sprintf( $_JALVIEW_HTML_TMPL, $url_site, $url_fa, $url_nh );
  return $html;
}

sub _ajax_zmenu_regulation {
 # Specific zmenu for functional genomics features

  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $fid = $obj->param('fid') || die( "No feature ID value in params" );
  my $ftype = $obj->param('ftype')  || die( "No feature type value in params" );
  my $db_adaptor = $obj->database('funcgen');
  my $ext_adaptor =  $db_adaptor->get_ExternalFeatureAdaptor();
  my $species= $obj->species;

  if ($ftype eq 'ensembl_reg_feat'){
    my $rf_adaptor = $db_adaptor->get_RegulatoryFeatureAdaptor();
    my $reg_feat = $rf_adaptor->fetch_by_stable_id($fid);
    my $location = $reg_feat->slice->seq_region_name .":". $reg_feat->start ."-" . $reg_feat->end;
    my $location_link = $obj->_url({'type' => 'Location', 'action' => 'View', 'r' => $location});

    my @atts  = @{$reg_feat->regulatory_attributes()};
    my @temp = map $_->feature_type->name(), @atts;
    my %att_label;
    my $c = 1;
    foreach my $k (@temp){
      if (exists  $att_label{$k}) {
        my $old = $att_label{$k};
        $old++;
        $att_label{$k} = $old;
      } else {
        $att_label{$k} = $c;
      }
    }
    my @keys = keys %att_label;
    my $label = "";
    foreach my $k (keys %att_label){
      my $v = $att_label{$k};
      $label .= "$k($v), ";
    }
    $label =~s/\,\s$//;

    $panel->{'caption'} = "Regulatory Feature";
    $panel->add_entry({
        'type'     =>  'Stable ID:',
        'label'    =>  $reg_feat->stable_id,
        'priority' =>  10,
    });
    $panel->add_entry({
        'type'     =>  'Type:',
        'label'    =>  $reg_feat->feature_type->name,
        'priority' =>  9,
    });
    $panel->add_entry({
        'type'        =>  'bp:',
        'label_html'  =>  $location,
        'link'        =>  $location_link,
        'priority'    =>  8,
    });
    $panel->add_entry({
        'type'     =>  'Attributes:',
        'label'    =>  $label,
        'priority' =>  7,
    });
  } else {
    my $feature = $ext_adaptor->fetch_by_dbID($obj->param('dbid'));
    my $location = $feature->slice->seq_region_name .":". $feature->start ."-" . $feature->end;
    my $location_link = $obj->_url({'type' => 'Location', 'action' => 'View', 'r' => $location});
    my ($feature_link, $factor_link);
    my $factor = $obj->param('fid');
    $panel->{'caption'} = "Regulatory Region";


    if ($ftype eq 'cisRED'){
      $factor =~s/\D*//g;
      $feature_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'};
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;dbid=".$obj->param('dbid').";id=" . $obj->param('fid');
      $feature_link =~s/###ID###/$factor/;
    } elsif($ftype eq 'miRanda'){
      my $name = $obj->param('fid');
      $name =~/\D+(\d+)/;
      my $temp_factor = $name;
      my @temp = split (/\:/, $temp_factor);
    $factor = $temp[1];
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');

    } elsif($ftype eq 'vista_enhancer'){
      $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');

    }elsif($ftype eq 'NestedMICA'){
       $factor_link = "/$species/Location/Genome?ftype=RegulatoryFactor;id=$factor;name=" . $obj->param('fid');
       $feature_link = "http://servlet.sanger.ac.uk/tiffin/motif.jsp?acc=".$obj->param('fid');

    } elsif($ftype eq 'cisred_search'){
      my ($id, $type, $analysis_link, $associated_link, $gene_reg_link);
      my $db_ent = $feature->get_all_DBEntries;
      foreach my $dbe (@$db_ent){
        $id = $dbe->primary_id;
        my $dbname = $dbe->dbname;
        if ($dbname =~/gene/i){
          $associated_link = $obj->_url({'type' => 'Gene', 'action'=> 'Summary', 'g' => $id });
          $gene_reg_link = $obj->_url({'type' => 'Gene', 'action'=> 'Regulation', 'g' => $id });
          $analysis_link = $self->object->species_defs->ENSEMBL_EXTERNAL_URLS->{'CISRED'};
          $analysis_link =~s/siteseq\?fid=###ID###/gene_view?ensembl_id=$id/;
        } elsif ($dbname =~/transcript/i){
          $associated_link = $obj->_url({'type' => 'Transcript', 'action'=> 'Summary', 't' => $id });
        } elsif ($dbname =~/transcript/i){
          $associated_link = $obj->_url({'type' => 'Transcript', 'action'=> 'Summary', 'p' => $id });
        }
      }

        
      $panel->{'caption'} = "Regulatory Search Region";
      $panel->add_entry({
        'type'        =>  'Analysis:',
        'label_html'  =>  $obj->param('ftype'),
        'link'        =>  $analysis_link,
        'priority'    =>  7,
      });
      $panel->add_entry({
        'type'        =>  'Target Gene:',
        'label_html'  =>  $id,
        'link'        =>  $associated_link,
        'priority' =>  6,
      });
      unless ($obj->referer =~/Regulation/){
        $panel->add_entry({
          'label_html'  =>  'View Gene Regulation',
          'link'        =>  $gene_reg_link,
          'priority' =>  4,
        });
      }   
     
    }

    ## add zmenu items that apply to all external regulatory features
    unless ($ftype eq 'cisred_search'){
      $panel->add_entry({
        'type'        =>  'Feature:',
        'label_html'  =>  $obj->param('fid'),
        'link'        =>  $feature_link,
        'priority'    =>  10,
      });
      $panel->add_entry({
        'type'        =>  'Factor:',
        'label_html'  =>  $factor,
        'link'        =>  $factor_link,
        'priority'    =>  9,
      }) ;
    }
    $panel->add_entry({
      'type'        =>  'bp:',
      'label_html'  =>  $location,
      'link'        =>  $location_link,
      'priority'    =>  8,
    });

  }

  return;
}

sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub geneseqview {
  my $self   = shift;
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
      name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::sequence_display
    ));
    $self->add_panel( $panel1 );
  }
}

sub geneseqalignview {
  my $self   = shift;
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
      name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::align_sequence_display
    ));
    $self->add_panel( $panel1 );
  }
}


sub sequencealignview {

  ### Calls methods in component to build the page
  ### Returns nothing

  my $self   = shift;
  my $strain =  $self->{object}->species_defs->translate( "strain" );
  $self->set_title( "Gene sequence for ".$self->{object}->stable_id );
  if( my $panel1 = $self->new_panel( 'Information',
    'code'    => "info#",
    #'null_data' => "<p>No $strain data for this gene.</p>",
   'caption' => 'Gene Sequence information for '.$self->{object}->stable_id,
  ) ) {
    $panel1->add_components(qw(
     name           EnsEMBL::Web::Component::Gene::name
      location       EnsEMBL::Web::Component::Gene::location
      markup_options EnsEMBL::Web::Component::Gene::markup_options
      sequence       EnsEMBL::Web::Component::Slice::sequencealignview
    ));
   $self->add_panel( $panel1 );
  }
}


1;
