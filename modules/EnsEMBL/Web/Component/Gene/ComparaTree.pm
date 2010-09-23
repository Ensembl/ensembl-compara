package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";

use Bio::AlignIO;
use IO::Scalar;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub _get_details {
  my $self = shift;
  my $cdb = shift;
  my $stable_id = shift;
  my $object = $self->object;
  my $member = $object->get_compara_Member($cdb, $stable_id);

  return (undef, '<strong>Gene is not in the compara database</strong>') unless $member;

  my $tree = $object->get_GeneTree($cdb);
  return (undef, '<strong>Gene is not in a compara tree</strong>') unless $tree;

  my $node = $tree->get_leaf_by_Member($member);
  return (undef, '<strong>Gene is not in the compara tree</strong>') unless $node;

  return ($member, $tree, $node);
}

sub content {
  my $self   = shift;
  my $cdb     = shift || 'compara';
  my $hub = $self->hub;
  my ($gene, $member, $tree, $node);
  if ($self->object->isa('EnsEMBL::Web::Object::GeneTree')) {
    $tree = $self->object->Obj;
    $node = $tree->find_node_by_node_id($hub->param('collapse'));
    $member = undef;
  }
  else {
    $gene = $self->object;
    ($member, $tree, $node) = $self->_get_details($cdb);
  }
  # Get the Member and ProteinTree objects and draw the tree


  return $tree . $self->genomic_alignment_links($cdb) if $object->param('g') && !defined $member;

  my $leaves               = $tree->get_all_leaves;
  my $highlight_gene       = $object->param('g1');
  my $highlight_ancestor   = $object->param('anc');
  my $image_width          = $self->image_width               || 800;
  my $collapsability       = $object->param('collapsability') || 'gene';
  my $colouring            = $object->param('colouring')      || 'background';
  my $show_exons           = $object->param('exons');
  my $image_config         = $hub->get_imageconfig('genetreeview');
  my @hidden_clades        = grep { $_ =~ /^group_/ && $object->param($_) eq 'hide'     } $object->param;
  my @collapsed_clades     = grep { $_ =~ /^group_/ && $object->param($_) eq 'collapse' } $object->param;
  my @highlights           = $gene && $member ? ($gene->stable_id, $member->genome_db->dbID) : ();
  my $hidden_genes_counter = 0;
  my ($hidden_genome_db_ids, $highlight_species, $highlight_genome_db_id, $html);
  
  if ($highlight_gene) {
    my $highlight_gene_display_label;
    
    foreach my $this_leaf (@$leaves) {
      if ($highlight_gene && $this_leaf->gene_member->stable_id eq $highlight_gene) {
        $highlight_gene_display_label = $this_leaf->gene_member->display_label || $highlight_gene;
        $highlight_species            = $this_leaf->gene_member->genome_db->name;
        $highlight_genome_db_id       = $this_leaf->gene_member->genome_db_id;
        last;
      }
    }

    if ($member && $gene && $highlight_species) {
      $html .= $self->_info('Highlighted genes',
        sprintf(
          'In addition to all <I>%s</I> genes, the %s gene (<I>%s</I>) and its paralogues have been highlighted. <a href="%s">Click here to switch off highlighting</a>.', 
          $member->genome_db->name, $highlight_gene_display_label, $highlight_species, $hub->url
        )
      );
    } else {
      $html .= $self->_warning('WARNING', "$highlight_gene gene is not in this Gene Tree");
      $highlight_gene = undef;
    }
  }

  my $wuc            = $hub->get_imageconfig( 'genetreeview' );
  my $image_width    = $self->image_width || 800;
  my $collapsability = $hub->param('collapsability');
  unless ($collapsability) {
    $collapsability = $self->object->isa('EnsEMBL::Web::Object::GeneTree') ? 'duplications' : 'gene';
  }
  my $colouring      = $hub->param('colouring') || 'background';
  my $show_exons     = $hub->param('exons');
  my @hidden_clades  = grep {$_ =~ /^group_/ and $hub->param($_) eq "hide"} $hub->param();

  my $hidden_genome_db_ids;
  my $hidden_genes_counter = 0;
  
  if (@hidden_clades) {
    $hidden_genome_db_ids = '_';
    
    foreach my $clade (@hidden_clades) {
      my ($clade_name) = $clade =~ /group_([\w\-]+)_display/;
      $hidden_genome_db_ids .= $object->param("group_${clade_name}_genome_db_ids") . '_';
    }
    
    foreach my $this_leaf (@$leaves) {
      my $genome_db_id = $this_leaf->genome_db_id;
      
      next if $highlight_genome_db_id && $genome_db_id eq $highlight_genome_db_id;
      next if $highlight_gene && $this_leaf->gene_member->stable_id eq $highlight_gene;
      next if $genome_db_id == $member->genome_db_id;
      
      if ($hidden_genome_db_ids =~ /_${genome_db_id}_/) {
        $hidden_genes_counter++;
        $this_leaf->disavow_parent;
        $tree = $tree->minimize_tree;
      }
    }

    $html .= $self->_info('Hidden genes', "There are $hidden_genes_counter hidden genes in the tree. Use the 'configure page' link in the left panel to change the options.") if $hidden_genes_counter;
  }

  $image_config->set_parameters({
    container_width => $image_width,
    image_width     => $image_width,
    slice_number    => '1|1',
    cdb             => $cdb
  });

  #$wuc->tree->dump("GENE TREE CONF", '([[caption]])');
  my @highlights;
  if ($gene && $member) {
    @highlights = ($gene->stable_id, $member->genome_db->dbID);
  }
  else {
    @highlights = (undef, undef);
  }
  # Keep track of collapsed nodes
  my $collapsed_nodes   = $object->param('collapse');
  my $collapsed_to_gene = $self->_collapsed_nodes($tree, $node, 'gene',         $highlight_genome_db_id, $highlight_gene);
  my $collapsed_to_para = $self->_collapsed_nodes($tree, $node, 'paralogs',     $highlight_genome_db_id, $highlight_gene);
  my $collapsed_to_dups = $self->_collapsed_nodes($tree, $node, 'duplications', $highlight_genome_db_id, $highlight_gene);

  if (!defined $collapsed_nodes) { # Examine collapsabilty
    $collapsed_nodes = $collapsed_to_gene if $collapsability eq 'gene';
    $collapsed_nodes = $collapsed_to_para if $collapsability eq 'paralogs';
    $collapsed_nodes = $collapsed_to_dups if $collapsability eq 'duplications';
    $collapsed_nodes ||= '';
  }

  # print $self->_info("Collapsed nodes",  join(" -- ", split(",", $collapsed_nodes)));
  ## FIXME - this doesn't appear to be implemented!
  my @collapsed_clades  = grep {$_ =~ /^group_/ and $hub->param($_) eq "collapse"} $hub->param();
  if (@collapsed_clades) {
    foreach my $clade (@collapsed_clades) {
      my ($clade_name) = $clade =~ /group_([\w\-]+)_display/;
      my $extra_collapsed_nodes = _find_nodes_by_genome_db_ids($tree, [ split '_', $object->param("group_${clade_name}_genome_db_ids") ], 'internal');
      
      if (%$extra_collapsed_nodes) {
        $collapsed_nodes .= ',' if $collapsed_nodes;
        $collapsed_nodes .= join ',', keys %$extra_collapsed_nodes;
      }
    }
  }

  my $coloured_nodes;
  
  if ($colouring =~ /^(back|fore)ground$/) {
    my $mode   = $1 eq 'back' ? 'bg' : 'fg';
    my @clades = grep { $_ =~ /^group_.+_${mode}colour/ } $object->param;

    # Get all the genome_db_ids in each clade
    my $genome_db_ids_by_clade;
    
    foreach my $clade (@clades) {
      my ($clade_name) = $clade =~ /group_(.+)_${mode}colour/;
      $genome_db_ids_by_clade->{$clade_name} = [ split '_', $object->param("group_${clade_name}_genome_db_ids") ];
    }

    # Sort the clades by the number of genome_db_ids. First the largest clades,
    # so they can be overwritten later (see ensembl-draw/modules/Bio/EnsEMBL/GlyphSet/genetree.pm)
    foreach my $clade_name (sort {
          scalar(@{$genome_db_ids_by_clade->{$b}}) <=> scalar(@{$genome_db_ids_by_clade->{$a}})
	        } keys %$genome_db_ids_by_clade) {
      my $genome_db_ids = $genome_db_ids_by_clade->{$clade_name};
      my $colour = $hub->param("group_${clade_name}_${mode}colour") || "magenta";
      my $these_coloured_nodes;
      if ($mode eq "fg") {
        $these_coloured_nodes = _find_nodes_by_genome_db_ids($tree, $genome_db_ids, "all");
      } else {
        $these_coloured_nodes = _find_nodes_by_genome_db_ids($tree, $genome_db_ids);
      }
      if (%$these_coloured_nodes) {
        push(@$coloured_nodes, {
	        'clade' => $clade_name,
	        'colour' => $colour,
	        'mode' => $mode,
	        'node_ids' => [keys %$these_coloured_nodes],
	      });
        # print $self->_info("Coloured nodes ($clade_name - $colour)",  join(" -- ", keys %$these_coloured_nodes));
      }
    }
  }

  if ($show_exons && $show_exons eq 'on') {
    $show_exons = 1;
  } else {
    $show_exons = 0;
  }

  push @highlights, $collapsed_nodes        || undef;
  push @highlights, $coloured_nodes         || undef;
  push @highlights, $highlight_genome_db_id || undef;
  push @highlights, $highlight_gene         || undef;
  push @highlights, $highlight_ancestor     || undef;
  push @highlights, $show_exons;

  my $image = $self->new_image($tree, $image_config, \@highlights);
  
  return $html if $self->_export_image($image, 'no_text');

  my $image_id = $gene ? $gene->stable_id : $tree->stable_id;
  my $li_tmpl  = '<li><a href="%s">%s</a></li>';
  my @view_links;
  
  $image->image_type       = 'genetree';
  $image->image_name       = ($object->param('image_width')) . "-$image_id";
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'tree';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  if ($gene) {
    push @view_links, sprintf $li_tmpl, $hub->url({ collapse => $collapsed_to_gene, g1 => $highlight_gene }), $highlight_gene ? 'View current genes only'        : 'View current gene only';
    push @view_links, sprintf $li_tmpl, $hub->url({ collapse => $collapsed_to_para, g1 => $highlight_gene }), $highlight_gene ? 'View paralogs of current genes' : 'View paralogs of current gene';
    push @view_links, sprintf $li_tmpl, $hub->url({ collapse => $collapsed_to_dups, g1 => $highlight_gene }), 'View all duplication nodes';
    push @view_links, sprintf $li_tmpl, $hub->url({ collapse => '', g1 => $highlight_gene }), 'View fully expanded tree';
    push @view_links, sprintf $li_tmpl, $hub->url, 'Switch off highlighting' if $highlight_gene;
  }

  $html .= $image->render;
  $html .= sprintf(qq{
    <div style="margin-top:1em"><b>View options:</b><br/>
    <small><ul>%s</ul></small>
    Use the 'configure page' link in the left panel to set the default. Further options are available from menus on individual tree nodes.</div>
  }, join('', @view_links));
  
  return $html;
}

sub _collapsed_nodes{
  # Takes the ProteinTree and node related to this gene and a view action
  # ('gene', 'paralogs', 'duplications' ) and returns the list of
  # tree nodes that should be collapsed according to the view action.
  # TODO: Move to Object::Gene, as the code is shared by the ajax menus
  my $self = shift;
  my $tree = shift;
  my $node = shift;
  my $action = shift;
  my $highlight_genome_db_id = shift;
  my $highlight_gene = shift;
  $tree->isa('Bio::EnsEMBL::Compara::ProteinTree') 
      || die( "Need a ProteinTree, not a $tree" );
  return unless $node;
  if (!$self->object->Obj->isa('Bio::EnsEMBL::Compara::ProteinTree') 
        && !$node->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
    die( "Need an AlignedMember, not a $node" );
  }

  my %collapsed_nodes;
  my %expanded_nodes;
  
  if( $action eq 'gene' ){ # View current gene
    foreach my $adj( @{$node->get_all_adjacent_subtrees} ){
      $collapsed_nodes{$adj->node_id} = $_;
    }
    if ($highlight_gene) {
      foreach my $ancestor( @{$node->get_all_ancestors} ){
        $expanded_nodes{$ancestor->node_id} = $ancestor;
      }
      foreach my $leaf( @{$tree->get_all_leaves} ){
        foreach my $adj( @{$leaf->get_all_adjacent_subtrees} ){
          $collapsed_nodes{$adj->node_id} = $_;
        }
        if( $leaf->gene_member->stable_id eq $highlight_gene ){
          foreach my $ancestor( @{$leaf->get_all_ancestors} ){
            $expanded_nodes{$ancestor->node_id} = $ancestor;
          }
          last;
        }
      }
    }
  }
  elsif( $action eq 'paralogs' ){ # View all paralogs
    my $gdb_id = $node->genome_db_id;
    foreach my $leaf( @{$tree->get_all_leaves} ){
      if( $leaf->genome_db_id == $gdb_id or ($highlight_genome_db_id and $leaf->genome_db_id == $highlight_genome_db_id) ){
        foreach my $ancestor( @{$leaf->get_all_ancestors} ){
          $expanded_nodes{$ancestor->node_id} = $ancestor;
        }
        foreach my $adjacent( @{$leaf->get_all_adjacent_subtrees} ){
          $collapsed_nodes{$adjacent->node_id} = $adjacent;
        }
      }
    }
  }
  elsif( $action eq 'duplications' ){ # View all duplications
    foreach my $tnode( @{$tree->get_all_nodes} ){
      next if $tnode->is_leaf;
      if($tnode->get_tagvalue('dubious_duplication') or
         ! $tnode->get_tagvalue('Duplication') ){
        $collapsed_nodes{$tnode->node_id} = $tnode;
        next;
      }
      $expanded_nodes{$tnode->node_id} = $tnode;
      foreach my $ancestor( @{$tnode->get_all_ancestors} ){
        $expanded_nodes{$ancestor->node_id} = $ancestor;
      }
    }
  }
  my $collapsed_node_ids
      = join( ',', grep{! $expanded_nodes{$_}} keys %collapsed_nodes );
  return $collapsed_node_ids;
}

sub _find_nodes_by_genome_db_ids {
  my ($tree, $genome_db_ids, $mode) = @_;
  my $node_ids = {};

  if ($tree->is_leaf()) {
    my $genome_db_id = $tree->genome_db_id;
    if (grep {$_ eq $genome_db_id} @$genome_db_ids) {
      $node_ids->{$tree->node_id} = 1;
    }
  } else {
    my $tag = 1;
    foreach my $this_child (@{$tree->children}) {
      my $these_node_ids = _find_nodes_by_genome_db_ids($this_child, $genome_db_ids, $mode);
      foreach my $node_id (keys %$these_node_ids) {
        $node_ids->{$node_id} = 1;
      }
      $tag = 0 if (!$node_ids->{$this_child->node_id});
    }
    if ($mode eq "internal") {
      foreach my $this_child (@{$tree->children}) {
        delete($node_ids->{$this_child->node_id}) if $this_child->is_leaf();
      }
    }
    if ($tag) {
      unless ($mode eq "all") {
        foreach my $this_child (@{$tree->children}) {
          delete($node_ids->{$this_child->node_id});
        }
      }
      $node_ids->{$tree->node_id} = 1;
    }
  }

  return $node_ids;
}

sub content_align {
  my $self           = shift;
  my $cdb     = shift || 'compara';
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my ( $member,$tree,$node ) = $self->_get_details($cdb);
  return $tree . $self->genomic_alignment_links($cdb) unless defined $member;

  #----------
  # Return the text representation of the tree
  my $htmlt = q(
<p>Multiple sequence alignment in "<i>%s</i>" format:</p>
<p>The sequence alignment format can be configured using the
'configure page' link in the left panel.<p>
<pre>%s</pre>);

  #----------
  # Determine the format
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS();
  my $mode = $object->param('text_format');
     $mode = 'fasta' unless $formats{$mode};
  my $fmt_caption = $formats{$mode} || $mode;

  my $align_format = $mode;

  my $formatted; # Variable to hold the formatted alignment string
  my $SH = IO::Scalar->new(\$formatted);
  #print $SH "FOO\n";
  my $aio = Bio::AlignIO->new( -format => $align_format, -fh => $SH );
  $aio->write_aln( $tree->get_SimpleAlign );

  return $object->param('_format') eq 'Text'
       ? $formatted 
       : sprintf( $htmlt, $fmt_caption, $formatted )
       ;
}

sub content_text {
  my $self           = shift;
  my $cdb     = shift || 'compara';
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my ( $member,$tree,$node ) = $self->_get_details($cdb);
  return $tree . $self->genomic_alignment_links($cdb) unless defined $member;

  #----------
  # Template for the section HTML
  my $htmlt = q(
<p>The following is a representation of the tree in "<i>%s</i>" format</p>
<p>The tree representation can be configured using the
'configure page' link in the left panel.<p>
<pre>%s</pre>);


  #----------
  # Return the text representation of the tree
  my %formats = EnsEMBL::Web::Constants::TREE_FORMATS();
  my $mode = $object->param('tree_format');
     $mode = 'newick' unless $formats{$mode};
  my $fn   = $formats{$mode}{'method'};
  my $fmt_caption = $formats{$mode}{caption} || $mode;

  my @params = ( map { $object->param( $_ ) } 
                 @{ $formats{$mode}{'parameters'} || [] } );
  my $string = $tree->$fn(@params);
  if( $formats{$mode}{'split'} && $object->param('_format') ne 'Text') {
    my $reg = '(['.quotemeta($formats{$mode}{'split'}).'])';
    $string =~ s/$reg/$1\n/g;
  }

  return $object->param('_format') eq 'Text'
       ? $string 
       : sprintf( $htmlt, $fmt_caption, $string )
       ;
}

sub genomic_alignment_links {
  my $self       = shift;
  my $cdb = shift || $self->object->param('cdb') || 'compara';
  (my $ckey = $cdb) =~ s/compara//;

  my $object     = $self->object;
  my $alignments = $object->species_defs->multi_hash->{$ckey}{'ALIGNMENTS'}||{};
  my $species    = $object->species;
  my $url        = $object->_url({ action => "Compara_Alignments$ckey", align => undef });
  my (%species_hash, $list);
  
  foreach my $row_key (grep $alignments->{$_}{'class'} !~ /pairwise/, keys %$alignments) {
    my $row = $alignments->{$row_key};
    
    next unless $row->{'species'}->{$species};
    
    $row->{'name'} =~ s/_/ /g;
    
    $list .= qq{<li><a href="$url;align=$row_key">$row->{'name'}</a></li>};
  }
  
  foreach my $i (grep $alignments->{$_}{'class'} =~ /pairwise/, keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      if ($alignments->{$i}->{'species'}->{$species} && $_ ne $species) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        $species_hash{$object->species_defs->species_label($_) . "###$type"} = $i;
      }
    } 
  }
  
  foreach (sort { $a cmp $b } keys %species_hash) {
    my ($name, $type) = split /###/, $_;
    
    $list .= qq{<li><a href="$url;align=$species_hash{$_}">$name - $type</a></li>};
  }
  
  return qq{<div class="alignment_list"><p>View genomic alignments for this gene</p><ul>$list</ul></div>};
}

1;
