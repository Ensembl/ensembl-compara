=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Compara_Alignments;

use strict;
use warnings;
no warnings qw(uninitialized);

use HTML::Entities qw(encode_entities);
use List::Util qw(min max);
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::TextSequence::View::ComparaAlignments;

use base qw(EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  my $hub = $self->hub;

  ## Don't cache these pages, as it breaks the species selector
  $self->mcacheable(0);

  my $alignments_session_data = $hub->session ? $hub->session->get_record_data({'type' => 'view_config', 'code' => 'alignments_selector'}) : {};
  if (scalar keys %{$alignments_session_data} > 0 && $alignments_session_data->{$hub->species}) {
    %{$self->{'viewconfig'}{$hub->type}->{'_user_settings'}} = (%{$self->{'viewconfig'}{$hub->type}->{'_user_settings'}}, %{$alignments_session_data->{$hub->species}});
  }
  $self->SUPER::_init(100);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object || $hub->core_object(lc($hub->param('data_type')));
  my $cdb       = shift || $hub->param('cdb') || 'compara';
  my $slice     = $object->slice;
  my $threshold = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $species   = $hub->species;
  my $type      = $hub->type;
  my $compara_db = $hub->database($cdb);
  
  if ($type eq 'Location' && $slice->length > $threshold) {
    return $self->_warning(
      'Region too large',
      '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>'
    );
  }
  
  my $align_param = $hub->get_alignment_id;

  my ($align, $target_species, $target_slice_name_range) = split '--', $align_param;
  my $target_slice = $object->get_target_slice;

  my ($alert_box, $error) = $self->check_for_align_problems({
                    'align' => $align,
                    'species' => $hub->species_defs->IS_STRAIN_OF ? ucfirst $hub->species_defs->SPECIES_PRODUCTION_NAME($object->species) : $object->species,
                  });
  return $alert_box if $error;
  my ($warnings, $image_link);
  $image_link = '';
  
  my $html = $alert_box;
  
  if ($type eq 'Gene' && $align) {
    my $location = $object->Obj; # Use this instead of $slice because the $slice region includes flanking
    
    $image_link = sprintf(
      '<p style="font-weight:bold"><a href="%s">View an image of this alignment</a></p>',
      $hub->url({
        type   => 'Location',
        action => 'Compara_Alignments/Image',
        align  => $align,
        r      => $location->seq_region_name . ':' . $location->seq_region_start . '-' . $location->seq_region_end
      })
    );
  }
  
  $slice = $slice->invert if ($self->param('strand') && $self->param('strand') == -1);

  my $align_blocks;
  my $num_groups = 0;
  my $is_overlap = 0; #whether any of the groups overlaps one another (would need target_slice_table)
  my $groups;
  my $is_low_coverage_species = 0; #is this species part of the low coverage set in the EPO_LOW_COVERAGE alignments

  #method_link_species_set class and type
  my $method_class = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'class'} if ($align);
  my $method_type = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'type'} if ($align);

  # Get all alignment blocks and group_ids when asking for a specific alignment
  if ($align) {
      $align_blocks = $object->get_align_blocks($slice, $align, $cdb);

      #find out if this species is low_coverage and the alignment is EPO_LOW_COVERAGE
      if ($method_type =~ /EPO_LOW_COVERAGE/ && @$align_blocks) {
          # The species is not low-coverage if it's been used in one of the EPO alignments
          $is_low_coverage_species = !scalar( grep {($_->{type} eq 'EPO') && $_->{species}->{$object->species}}
                                              values %{$hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}}
                                            );
      }

      #Group alignments together by group_id and/or dbID
      $groups = $object->get_groups($align_blocks, $is_low_coverage_species);
      $num_groups = keys %$groups;

      #Find if the align_blocks are overlapping one another
      if ($num_groups > 1) {
          $is_overlap = $object->find_is_overlapping($align_blocks);
      }
  }

  #Draw the target_slice_table if using left hand menu (no $target_species) and have more than one group OR using zmenu (target_species is set) and have overlapping blocks
  my $need_target_slice_table = 0; 
  if ($num_groups > 1 && !$target_species) {
      $need_target_slice_table = 1;
  } elsif ($is_overlap && $target_species && !$target_slice) {
      $need_target_slice_table = 1;  
  }
  ## Need to pass information to button code
  $hub->param('need_target_slice_table', $need_target_slice_table);

  my ($slices, $slice_length, $num_slices);
  
  #When we can directly show the text ie do not need a table of results
  unless ($need_target_slice_table) {
    # Get all slices for the gene
    ($slices, $slice_length) = $object->get_slices({
          'slice'   => $slice, 
          'align'   => $align_param, 
          'species' => $species, 
          'start'   => undef, 
          'end'     => undef, 
          'db'      => $cdb, 
          'target'  => $target_slice,
    });
      
    if (scalar @$slices == 1) {
      unshift @$warnings,{
        severity => 'warning',
        title => 'No alignment in this region',
        message => 'There is no alignment between the selected species in this region'
      };
    }
    $num_slices = @$slices;
  }

  #If the slice_length is long, split the sequence into chunks to speed up the process
  #Note that slice_length is not set if need to display a target_slice_table
  if ($hub->param('export')) {
    return $self->draw_tree($cdb, $align_blocks, $slice, $align, $method_class, $groups, $slices);    
  }
  elsif ($align && $slice_length && $slice_length >= $self->param('display_width')) {
    # Display show/hide full text alignment button if slice_length > display_width (currently 120bp)
    my ($table, $padding) = $self->get_slice_table($slices, 1);
    $html .= $self->draw_tree($cdb, $align_blocks, $slice, $align, $method_class, $groups, $slices);
    $html .= $image_link . $table;

    my $subslice_length = $slice_length < $self->{'subslice_length'} ? $slice_length : $self->{'subslice_length'};

    my $chunked_content = $self->chunked_content($slice_length, $subslice_length, { padding => $padding, length => $slice_length },1);

    $html .= qq (
          <div class="_text_alignment_display js_panel">
          <input type="hidden" class="panel_type" value="AlignmentText" name="panel_type_AlignmentText" />
        );

    # Show message saying you are only display a small block from the whole alignment
    my $view_all_button = sprintf qq{<div class="display_full_message_div"> <a data-total-length="%s" data-chunk-length="%s" data-display-width="%s">Display full alignment</a></div><br />}, 
                          $slice_length, 
                          $subslice_length,
                          $self->param('display_width');

    my $info = [{
      severity => 'info',
      title => 'Alignment',
      message => 'Currently showing the alignment for first '. $self->param('display_width') .' columns only. To display the full alignment, please click the button below.' . $view_all_button
    }];

    ($alert_box, $error) = $self->show_warnings($info);
    return $alert_box if $error;

    $html .= $alert_box . $chunked_content;

  } else {
    my ($table, $padding);

    #Draw target_slice_table for overlapping alignments
    if ($need_target_slice_table) {
      $table = $self->_get_target_slice_table($slice, $align, $align_blocks, $groups, $method_class, $method_type, $is_low_coverage_species, $cdb);
      $html .= $image_link . $table;
    } else {
      #Write out sequence if length is short enough
      $html .= $self->draw_tree($cdb, $align_blocks, $slice, $align, $method_class, $groups, $slices) if ($align);
      $html .= $image_link . $self->content_sub_slice($slice, $slices, undef, $cdb) if($align); # Direct call if the sequence length is short enough
    }
  }

  return $html;

}

sub content_sub_slice {
  my $self = shift;

  $self->view->output($self->view->output->subslicer);
  my ($sequence, $config) = $self->_get_sequence(@_);
  my $html = '';
  $html .= $self->describe_filter($config) unless $self->param('follow');
  $html .= $self->build_sequence($sequence, $config,1);
  return $html;
}

sub _get_sequence {
  my $self = shift;
  my ($slice, $slices, $defaults, $cdb) = @_;

  my $hub          = $self->hub;
  my $object       = $self->object || $hub->core_object($hub->param('data_type'));
     $slice      ||= $object->slice;
     $slice        = $slice->invert if !$_[0] && $self->param('strand') && $self->param('strand') == -1;
  my $species_defs = $hub->species_defs;
  my $start        = $hub->param('subslice_start');
  my $end          = $hub->param('subslice_end');
  my $padding      = $hub->param('padding');
  my $slice_length = $hub->param('length') || $slice->length;

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);

  my $config = {
    display_width   => $self->param('display_width'),
    site_type       => ucfirst lc $species_defs->ENSEMBL_SITETYPE || 'Ensembl',
    species         => $hub->species,
    display_species => $species_defs->SPECIES_DISPLAY_NAME,
    comparison      => 1,
    ambiguity       => 1,
    db              => $object->can('get_db') ? $object->get_db : 'core',
    sub_slice_start => $start,
    sub_slice_end   => $end,
  };
  
  for (qw(exon_display exon_ori snp_display line_numbering conservation_display codons_display region_change_display title_display align)) {
    my $param = $self->param($_);
    $config->{$_} = $param;
  }
  
  if ($config->{'line_numbering'} ne 'off') {
    $config->{'number'}     = 1;
  }
  
  $config = { %$config, %$defaults } if $defaults;
  
  # Requesting data from a sub slice
  if($start && $end) {
    ($slices) = $self->object->get_slices({
      slice => $slice,
      align => $config->{'align'},
      species => $config->{'species'},
      start => $start,
      end => $end,
      db => $cdb,
    });
  }
  
  $config->{'slices'} = $slices;

  my $view = $self->view;

  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);

  my @s2 = @{$view->root_sequences};

  foreach my $slice (@{$config->{'slices'}}) {
    my $seq = shift @s2;
    $seq->name($slice->{'display_name'} || $slice->{'name'});
  }

  $view->markup($sequence,$markup,$config);
  
  # Only if this IS NOT a sub slice - print the key and the slice list
  my $template = '';
  $template = $self->get_slice_table($config->{'slices'}) unless $start && $end;
  
  # Only if this IS a sub slice - remove margins from <pre> elements
  my $class = ($start && $end && $end == $slice_length) ? '' : ' class="no-bottom-margin"';
  
  $self->view->output->template(qq{$template<pre$class>%s</pre>});

  if ($padding) {
    my @pad = split ',', $padding;

    if ($config->{'line_numbering'} and $config->{'line_numbering'} eq 'slice') {
      $config->{'padding'}->{'pre_number'} = $pad[1];
      $config->{'padding'}->{'number'}     = $pad[2];
    }
  }
  
  $self->id('');
 
  return ($sequence, $config);
}

sub draw_tree {
  my ($self, $cdb, $align_blocks, $slice, $align, $class, $groups, $slices) = @_;
  my $hub             = $self->hub;
  my $compara_db      = $hub->database($cdb);

  my $image_config    = $hub->get_imageconfig('speciestreeview');

  my $image_width     = $self->image_width || 800;
  my $colouring       = $self->param('colouring') || 'background';
  my $species         = $hub->species;
  my $mlss_adaptor            = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($align);

  my $highlights;
  my $html;

  my $num_groups = (keys %$groups);
  #Do not draw a tree if have more than group or for pairwise alignments
  if ($num_groups > 1) {
    $html = $self->info_panel("Species Tree", "<p>No tree is drawn when there is more than one block displayed because each block is represented by a separate tree");
    return $html;
  } elsif ($num_groups < 1) {
    #No alignment found
    return;
  } elsif ($class =~ /pairwise/) {
    return;
  }

  $image_config->set_parameters({
				 container_width => $image_width,
				 image_width     => $image_width,
				 slice_number    => '1|1',
				 cdb             => $cdb,
				});

  #Take the first block since even if we have more than one block (eg using low coverage species as reference), all the blocks should be compatible since num_groups = 1

  my $gab = $align_blocks->[0];

  #If we only have a single GenomicAlignBlock we can restrict it and skip any
  #empty GenomicAligns. If we have more than one GenomicAlignBlock we cannot
  #do this because the first block may not be representative of all the blocks
  my $skip_empty_GenomicAligns = 0;
  $skip_empty_GenomicAligns = 1 if (@$align_blocks == 1);

  #get tree and restrict
  my $restricted_tree;
  if (@$align_blocks == 1) {
    my $tree = $align_blocks->[0]->get_GenomicAlignTree;

    #set reference genomic_align if it is not already in the tree
    my $ref_genomic_align = $tree->reference_genomic_align || $gab->reference_genomic_align;

    $restricted_tree = $tree->restrict_between_reference_positions($slice->start, $slice->end, $ref_genomic_align, $skip_empty_GenomicAligns);
  } else {
    #Get the first GenomicAlignBlock from the unrestricted slice (ie all the gabs will be the same)
    my $gab_adaptor = $compara_db->get_adaptor('GenomicAlignBlock');
    my $gab = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice)->[0];

    #Restrict the tree by looking at the species in the AlignSlice
    $restricted_tree = $gab->get_GenomicAlignTree;
  }

    # Remove the leaves (and their parents) from the tree if the species is
    # hidden by the current configuration (i.e. is not in $slices)
    my %slice_ok = map {(lc $_->{name}) => 1} @$slices;
    foreach my $this_node (@{$restricted_tree->get_all_leaves}) {
      my $genomic_align_group = $this_node->genomic_align_group;
      next if (!$genomic_align_group);
      my $node_name = $genomic_align_group->genome_db->name;
      next if $slice_ok{$node_name};
      $this_node->disavow_parent;
      $restricted_tree = $restricted_tree->minimize_tree;
    }

  #Get cigar lines from each Slice which will be passed to the genetree.pm drawing code
  my $slice_cigar_lines;

  # The nodes should be in the same order as the slices, so we can match
  # the internal nodes to the ancestral slices
  my @internal_nodes = grep {not $_->is_leaf} @{$restricted_tree->get_all_sorted_genomic_align_nodes};
  foreach my $this_slice (@$slices) {
    if (lc($this_slice->{name}) eq "ancestral_sequences") {
      #skip cigar lines for ancestral seqs and transfer the counter_position flag
      my $ga_node = shift @internal_nodes;
      $ga_node->{_counter_position} = $this_slice->{_counter_position};
    } else {
      push @$slice_cigar_lines, $this_slice->{cigar_line};
    }
  }

  #Get low coverage species from the EPO_LOW_COVERAGE species set
  my $low_coverage_species = {};
  if ($class =~ /GenomicAlignTree.tree_alignment/) {
    $low_coverage_species = _get_low_coverage_genome_db_sets($method_link_species_set);
  }

  #Use highlights array to store the cigar lines and low coverage species but the first 8 fields need to be undef
  for (my $i = 0; $i < 8; $i++) {
    push @$highlights, undef;
  }
  push @$highlights, $slice_cigar_lines;
  push @$highlights, $low_coverage_species;

  my $image = $self->new_image($restricted_tree, $image_config, $highlights);

  $image->{'export_params'} = [['align', $align]];


  return if $self->_export_image($image);

  my $image_name            = $hub->param('image_width') || $image_width;  
  my $image_id              = $gab->dbID || $gab->original_dbID;
  $image_name              .= "-$image_id";
  $image->image_type        = 'genetree';
  $image->image_name        = $image_name;
  $image->imagemap          = 'yes';
  $image->{'panel_number'}  = 'tree';
  $image->set_button('drag', 'title' => 'Drag to select region');

  $html .= $image->render;

  return $html;
}

# Displays slices for all species above the sequence
sub get_slice_table {
  my ($self, $slices, $return_padding) = @_;
  my $hub             = $self->hub;
  my $primary_species = $hub->species;
  
  my $table_rows = '';
  $_ = 0 for my ($species_padding, $region_padding, $number_padding, $ancestral_sequences);

  foreach (@$slices) {
    my $species = $_->{'display_name'} || $_->{'name'};
    
    next unless $species;
    
    my %url_params = (
      species => $_->{'name'},
      type    => 'Location',
      action  => 'View'
    );

    $url_params{'__clear'} = 1 unless $_->{'name'} eq $primary_species;

    $species_padding = length $species if $return_padding && length $species > $species_padding;

    $table_rows .= sprintf '<tr><th>%s&nbsp;&rsaquo;</th><td>', $species =~ s/\s/&nbsp;/r;

    foreach my $slice (@{$_->{'underlying_slices'}}) {
      next if $slice->seq_region_name eq 'GAP';

      my $slice_name = $slice->name;
      my ($stype, $assembly, $region, $start, $end, $strand) = split ':' , $slice_name;

      if ($return_padding) {
        $region_padding = length $region if length $region > $region_padding;
        $number_padding = length $end    if length $end    > $number_padding;
      }
      
      if ($species =~ /^Ancestral sequences/) {
        $table_rows .= $slice->{'_tree'};
        $ancestral_sequences = 1;
      } else {
        $table_rows .= sprintf qq{<a href="%s">$slice_name</a><br />}, $hub->url({ %url_params, r => "$region:$start-$end" });
      }
    }

    $table_rows .= '</td></tr>';
  }
  
  $region_padding++ if $region_padding;
 
  if ($table_rows) { 
    my $rtn = qq(<table class="bottom-margin" cellspacing="0">$table_rows</table>);
    $rtn    = qq{<p>NOTE: <a href="/info/genome/compara/ancestral_sequences.html">How ancestral sequences are calculated</a></p>$rtn} if $ancestral_sequences;
    return $return_padding ? ($rtn, "$species_padding,$region_padding,$number_padding") : $rtn;
  }
}

sub _get_target_slice_table {
  ## Displays all the alignment blocks as a table
  my ($self, $slice, $align, $gabs, $groups, $class, $type, $is_low_coverage_species, $cdb) = @_;

  $cdb   ||= 'compara';

  my $hub                     = $self->hub;
  my $ref_species             = lc($hub->species);
  my $compara_db              = $hub->database($cdb);
  my $mlss_adaptor            = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($align);
  my $ref_region              = $slice->seq_region_name;
  my $html                    = '';

  my $other_species;

  #Find the mapping reference species for EPO_LOW_COVERAGE alignments to distinguish the overlapping blocks
  if ($type =~ /EPO_LOW_COVERAGE/ && $is_low_coverage_species) {
    
    my $gdba = $compara_db->get_adaptor('GenomeDB');
    my $main_species = $gdba->fetch_by_name_assembly($ref_species);

    my $sptree = $method_link_species_set->species_tree();
    my $st_hash = $sptree->get_genome_db_id_2_node_hash();

    $other_species = $st_hash->{$main_species->dbID()}->get_value_for_tag('reference_species');

  } elsif ($class =~ /pairwise/) {
    #Find the non-reference species for pairwise alignments
    #get the non_ref name from the first block
    $other_species = $hub->species_defs->production_name_mapping($gabs->[0]->get_all_non_reference_genomic_aligns->[0]->genome_db->name);
  }

  my $merged_blocks = $self->object->build_features_into_sorted_groups($groups);

  #Create table columns
  my @columns = (
                 { key => 'block', sort => 'none', title => 'Alignment (click to view)' },
                 { key => 'length', sort => 'numeric', title => 'Length (bp)' },
                 { key => 'ref_species', sort => 'html', title => "Location on " . $self->object->get_slice_display_name(ucfirst($ref_species)) },
                );

  push @columns, { key => 'other_species', sort => 'html', title => "Location on " . $self->object->get_slice_display_name(ucfirst($other_species)) } if ($other_species);
  push @columns, { key => 'additional_species', sort => 'numeric', title => 'Additional species'} unless ($class =~ /pairwise/);

  my @rows;
  my $gab_num = 0; #block counter

  #Add blocks to the table
  foreach my $gab_group (@$merged_blocks) {
    next unless $gab_group; 
    my $min_start;
    my $max_end;
    my ($min_gab, $max_gab);
    my $gab_length;
    my $non_ref_species;
    my $non_ref_region;
    my $non_ref_ga;
    my $num_species = 0;

    #Find min and max start and end for ref and non-ref
    #Will not have $non_ref_ga for multiple alignments which are not low coverage
    my ($ref_start, $ref_end, $non_ref_start, $non_ref_end);
    if ($class =~ /pairwise/) { 
      ($ref_start, $ref_end, $non_ref_start, $non_ref_end, $non_ref_ga) = $self->object->get_start_end_of_slice($gab_group);
    } elsif ($type =~ /EPO_LOW_COVERAGE/ && $is_low_coverage_species) {
      ($ref_start, $ref_end, $non_ref_start, $non_ref_end, $non_ref_ga, $num_species) = $self->object->get_start_end_of_slice($gab_group, $other_species);
    } else {
      #want num_species but not non_ref details
      ($ref_start, $ref_end, $non_ref_start, $non_ref_end, undef, $num_species) = $self->object->get_start_end_of_slice($gab_group, $ref_species);
    }
    next if $num_species == 0 && $class !~ /pairwise/;

    $gab_num++;

    my $slice_length = ($ref_end-$ref_start+1);

    my $align_params = "$align";
    $align_params .= "--" . $hub->species_defs->production_name_mapping($non_ref_ga->genome_db->name) . "--" . $non_ref_ga->dnafrag->name . ":$non_ref_start-$non_ref_end" if ($non_ref_ga);

    my %url_params = (
                     species => $ref_species,
                     type    => 'Location',
                     action  => 'Compara_Alignments'
                    );

    my $block_link = $hub->url({
                               species => $ref_species,
                               type    => 'Location',
                               action  => 'Compara_Alignments',
                               align   => $align_params,
                               r       => "$ref_region:$ref_start-$ref_end"
                               });

    my $ref_string = "$ref_region:$ref_start-$ref_end";
    my $ref_link = $hub->url({
                             species => $ref_species,
                             type   => 'Location',
                             action => 'View',
                             r      => $ref_string,
                            });

    #Other species - ref species used for mapping (EPO_LOW_COVERAGE) or non_ref species (pairwise)
    my ($other_string, $other_link);
    if ($other_species) {
      $other_string = $non_ref_ga->dnafrag->name.":".$non_ref_start."-".$non_ref_end;
      $other_link = $hub->url({
                                   species => $hub->species_defs->production_name_mapping($non_ref_ga->genome_db->name),
                                   type   => 'Location',
                                   action => 'View',
                                   r      => $other_string,
                                  });
    }

    my $this_row = {
                      block => { value => qq{<a href="$block_link">Block $gab_num</a>}, class => 'bold' },
                      length => $slice_length,
                      ref_species => qq{<a href="$ref_link">$ref_string</a>},
                      additional_species => $num_species
                     };
    $this_row->{'other_species'} = qq{<a href="$other_link">$other_string</a>} if ($other_species);
    push @rows, $this_row;
  }

  if (scalar(@rows)) {
    my $table = $self->new_table(\@columns, \@rows, {
      data_table => 1,
      data_table_config => {iDisplayLength => 25},
      class             => 'fixed_width',
      sorting           => [ 'length desc' ],
      exportable        => 0
    });

    $html = "A total of " . @$merged_blocks . " alignment blocks have been found. Please select an alignment to view by selecting a Block from the Alignment column. <br /> <br />";
    $html .= $table->render;
    $html = qq{<div class="summary_panel">$html</div>};
  }
  return $html;

}

#Find the set of low coverage species (genome_dbs) from the EPO_LOW_COVERAGE set (high + low coverage)
#This could be improved by having a direct link between the EPO_LOW_COVERAGE and the corresponding high coverage EPO set
sub _get_low_coverage_genome_db_sets {
  my ($mlss) = @_;
  my $found_high_mlss;
  my $low_coverage_species_set;
  my $high_coverage_species_set;

  #Fetch all the high coverage EPO method_link_species_sets
  my $high_coverage_mlsss = $mlss->adaptor->fetch_all_by_method_link_type("EPO");
  foreach my $high_coverage_mlss (@$high_coverage_mlsss) {
    my $species_set = $high_coverage_mlss->species_set;
    foreach my $genome_db (@{$species_set->genome_dbs}) {
      $high_coverage_species_set->{ $high_coverage_mlss}{$genome_db->name} = 1;
    }
  }

  #Find high coverage mlss which has the same tag name (eg mammals) and is a subset of the low_coverage species set
  foreach my $high_mlss (@$high_coverage_mlsss) {
    my $counter = 0;
    foreach my $low_genome_db (@{$mlss->species_set->genome_dbs}) {
      if ($high_coverage_species_set->{$high_mlss}{$low_genome_db->name} && $mlss->species_set->name eq $high_mlss->species_set->name) {
        $counter++;
      }
    }
    if ($counter == @{$high_mlss->species_set->genome_dbs}) {
      $found_high_mlss = $high_mlss;
      last;
    }
  }

  my $low_coverage_species;
  foreach my $low_genome_db (@{$mlss->species_set->genome_dbs}) {
    unless ($high_coverage_species_set->{$found_high_mlss}{$low_genome_db->name}) {
#      push @$low_coverage_species, $low_genome_db->dbID;
      $low_coverage_species->{$low_genome_db->dbID} = 1;
    }
  }
  return $low_coverage_species;
}

sub export_options { 
  my $self = shift;
  my $hub = $self->hub;

  my $align_params = $hub->get_alignment_id || '';
  my ($align)      = split '--', $align_params;
  
  return unless $align;  

  return {
          'action'  => 'TextAlignments', 
          'params'  => [['align', $align]], 
          'caption' => 'Download alignment',
        }; 
}

sub get_export_data {
## Get data for export
  my $self = shift;
  my $hub = $self->hub;
  ## Fetch object explicitly, as we're probably coming from a DataExport URL
  my $obj = $hub->core_object($hub->param('data_type'));
  return $obj;
}

sub initialize_export_new {
  my ($self, $slice) = @_;
  my $hub = $self->hub;

  my $object    = $self->builder->object($self->param('data_type'));
  $slice      ||= $object->slice;
  my $cdb       = $self->param('cdb') || 'compara';
  my ($slices)  = $object->get_slices({
                        'slice'   => $slice,
                        'align'   => $self->param('align'),
                        'species' => $hub->species,
                        'start'   => undef,
                        'end'     => undef,
                        'db'      => $cdb,
                        'target'  => $object->get_target_slice,
                        'image'   => $self->has_image
                });
  return $self->_get_sequence($slice, $slices, undef, $cdb);
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::ComparaAlignments->new(
    $self->hub
  );
}

1;
