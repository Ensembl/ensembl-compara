=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use HTML::Entities qw(encode_entities);
use List::Util qw(min max);
use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component::TextSequence);

sub _init { $_[0]->SUPER::_init(100); }

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
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
  
  my $align_param = $hub->param('align');

  my $alert_box = $self->check_for_align_problems({
                    'align' => $align_param, 
                    'species' => $self->object->species,
                  });
  return $alert_box if $alert_box;

  #target_species and target_slice_name_range may not be defined so split separately
  #target_species but not target_slice_name_range is defined for pairwise compact alignments. 
  my ($align, $target_species, $target_slice_name_range) = split '--', $align_param;
  my ($target_slice_name, $target_slice_start, $target_slice_end) = $target_slice_name_range =~ /(\w+):(\d+)-(\d+)/;

  #Define target_slice
  my $target_slice;
  if ($target_species && $target_slice_start) {
      my $target_slice_adaptor = $hub->database('core', $target_species)->get_SliceAdaptor;
      $target_slice = $target_slice_adaptor->fetch_by_region('toplevel', $target_slice_name, $target_slice_start, $target_slice_end);
  }

  my ($error, $warnings) = $self->object->check_for_align_in_database($align, $species, $cdb);
  return $error if $error;
  
  my $html;
  
  if ($type eq 'Gene') {
    my $location = $object->Obj; # Use this instead of $slice because the $slice region includes flanking
    
    $html .= sprintf(
      '<p style="font-weight:bold"><a href="%s">Go to a graphical view of this alignment</a></p>',
      $hub->url({
        type   => 'Location',
        action => 'Compara_Alignments/Image',
        align  => $align,
        r      => $location->seq_region_name . ':' . $location->seq_region_start . '-' . $location->seq_region_end
      })
    );
  }
  
  $slice = $slice->invert if $hub->param('strand') == -1;

  my $align_blocks;
  my $num_groups = 0;
  my $is_overlap = 0; #whether any of the groups overlaps one another (would need target_slice_table)
  my $groups;
  my $is_low_coverage_species = 0; #is this species part of the low coverage set in the EPO_LOW_COVERAGE alignments

  #method_link_species_set class and type
  my $method_class = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'class'};
  my $method_type = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'type'};

  # Get all alignment blocks and group_ids when asking for a specific alignment
  if ($align) {
      $align_blocks = $self->object->get_align_blocks($slice, $align, $cdb);

      #find out if this species is low_coverage by looking at the un-restricted genomic_align from the first block and the alignment is EPO_LOW_COVERAGE 
      if ($method_type =~ /EPO_LOW_COVERAGE/ && @$align_blocks) {
          my $first_gab = $align_blocks->[0];
          my $ga_adaptor = $compara_db->get_adaptor('GenomicAlign');
          my $ref_ga = $ga_adaptor->fetch_by_dbID($first_gab->reference_genomic_align->original_dbID);
          my $whole_cigar_line = $ref_ga->cigar_line;
          $is_low_coverage_species = 1 if ($whole_cigar_line =~ /X/);
      }

      #Group alignments together by group_id and/or dbID
      $groups = $self->object->get_groups($align_blocks, $is_low_coverage_species);
      $num_groups = keys %$groups;

      #Find if the align_blocks are overlapping one another
      if ($num_groups > 1) {
          $is_overlap = $self->object->find_is_overlapping($align_blocks);
      }
  }

  #Draw the target_slice_table if using left hand menu (no $target_species) and have more than one group OR using zmenu (target_species is set) and have overlapping blocks
  my $need_target_slice_table = 0; 
  if ($num_groups > 1 && !$target_species) {
      $need_target_slice_table = 1;
  } elsif ($is_overlap && $target_species && !$target_slice) {
      $need_target_slice_table = 1;  
  }

  my ($slices, $slice_length, $num_slices);
  
  #When we can directly show the text ie do not need a table of results
  unless ($need_target_slice_table) {
      # Get all slices for the gene
      ($slices, $slice_length) = $self->object->get_slices({
          'slice'   => $slice, 
          'align'   => $align_param, 
          'species' => $species, 
          'start'   => undef, 
          'end'     => undef, 
          'db'      => $cdb, 
          'target'  => $target_slice,
          'image'   => $self->has_image
      });
      
      if (scalar @$slices == 1) {
          $warnings = $self->_info(
                                   'No alignment in this region',
                                   'There is no alignment between the selected species in this region'
                                  ) . $warnings;
      }
      $num_slices = @$slices;
  }

  #If the slice_length is long, split the sequence into chunks to speed up the process
  #Note that slice_length is not set if need to display a target_slice_table
  if ($align && $slice_length >= $self->{'subslice_length'}) {

    my ($table, $padding) = $self->get_slice_table($slices, 1);

    #Check for missing species
    $warnings .= $self->check_for_missing_species({
                                'align'   => $align, 
                                'species' => $species, 
                                'cdb'     => $cdb, 
                                'image'   => $self->has_image
                  });
    $html .= '<div class="sequence_key"></div>' . $table . $self->chunked_content($slice_length, $self->{'subslice_length'}, { padding => $padding, length => $slice_length }) . $warnings;

  } else {
      my ($table, $padding);

      #Draw target_slice_table for overlapping alignments
      if ($need_target_slice_table) {

          $table = $self->_get_target_slice_table($slice, $align, $align_blocks, $groups, $method_class, $method_type, $is_low_coverage_species, $cdb);
          $html .= '<div class="sequence_key"></div>' . $table . $warnings;
      } else {
          #Write out sequence if length is short enough
          #Check for missing species 
          ($warnings) .= $self->check_for_missing_species({
                                'align'   => $align, 
                                'species' => $species, 
                                'cdb'     => $cdb, 
                                'image'   => $self->has_image
                         }); 
          $html .= $self->content_sub_slice($slice, $slices, $warnings, undef, $cdb); # Direct call if the sequence length is short enough
      }
  }
 
  return $html;
}

sub check_for_missing_species {
    ## Check what species are not present in the alignment
    my $self = shift;

    my ($title, $warnings) = $self->object->check_for_missing_species(@_);

    return ($self->_info(ucfirst($title), $warnings)) if $warnings;
}

sub content_sub_slice {
  my $self = shift;
  my ($slice, $slices, $warnings, $defaults, $cdb) = @_;
  
  my $hub          = $self->hub;
  my $object       = $self->object;
     $slice      ||= $object->slice;
     $slice        = $slice->invert if !$_[0] && $hub->param('strand') == -1;
  my $species_defs = $hub->species_defs;
  my $start        = $hub->param('subslice_start');
  my $end          = $hub->param('subslice_end');
  my $padding      = $hub->param('padding');
  my $slice_length = $hub->param('length') || $slice->length;

  my $config = {
    display_width   => $hub->param('display_width') || 60,
    site_type       => ucfirst lc $species_defs->ENSEMBL_SITETYPE || 'Ensembl',
    species         => $hub->species,
    display_species => $species_defs->SPECIES_COMMON_NAME,
    comparison      => 1,
    ambiguity       => 1,
    db              => $object->can('get_db') ? $object->get_db : 'core',
    sub_slice_start => $start,
    sub_slice_end   => $end,
  };
  
  for (qw(exon_display exon_ori snp_display line_numbering conservation_display codons_display region_change_display title_display align)) {
    $config->{$_} = $hub->param($_) unless $hub->param($_) eq 'off';
  }
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'}     = 1;
  }
  
  $config = { %$config, %$defaults } if $defaults;
  
  # Requesting data from a sub slice
  ($slices) = $self->get_slices($slice, $config->{'align'}, $config->{'species'}, $start, $end, $cdb) if $start && $end;
  
  $config->{'slices'} = $slices;
  
  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
  
  # markup_comparisons must be called first to get the order of the comparison sequences
  # The order these functions are called in is also important because it determines the order in which things are added to $config->{'key'}
  $self->markup_comparisons($sequence, $markup, $config)   if $config->{'align'};
  $self->markup_conservation($sequence, $config)           if $config->{'conservation_display'};
  $self->markup_region_change($sequence, $markup, $config) if $config->{'region_change_display'};
  $self->markup_codons($sequence, $markup, $config)        if $config->{'codons_display'};
  $self->markup_exons($sequence, $markup, $config)         if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config)     if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config)           if $config->{'line_numbering'};
  
  # Only if this IS NOT a sub slice - print the key and the slice list
  my $template = sprintf('<div class="sequence_key">%s</div>', $self->get_key($config)) . $self->get_slice_table($config->{'slices'}) unless $start && $end;
  
  # Only if this IS a sub slice - remove margins from <pre> elements
  my $class = $end == $slice_length ? '' : ' class="no-bottom-margin"' if $start && $end;
  
  $config->{'html_template'} = qq{$template<pre$class>%s</pre>};

  if ($padding) {
    my @pad = split ',', $padding;
    
    $config->{'padded_species'}->{$_} = $_ . (' ' x ($pad[0] - length $_)) for keys %{$config->{'padded_species'}};
    
    if ($config->{'line_numbering'} eq 'slice') {
      $config->{'padding'}->{'pre_number'} = $pad[1];
      $config->{'padding'}->{'number'}     = $pad[2];
    }
  }
  
  $self->id('');
  
  return $self->build_sequence($sequence, $config) . $warnings;
}


# Displays slices for all species above the sequence
sub get_slice_table {
  my ($self, $slices, $return_padding) = @_;
  my $hub             = $self->hub;
  my $primary_species = $hub->species;
  
  my ($table_rows, $species_padding, $region_padding, $number_padding, $ancestral_sequences);

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

    $table_rows .= qq{
    <tr>
      <th>$species &rsaquo;</th>
      <td>};

    foreach my $slice (@{$_->{'underlying_slices'}}) {
      next if $slice->seq_region_name eq 'GAP';

      my $slice_name = $slice->name;
      my ($stype, $assembly, $region, $start, $end, $strand) = split ':' , $slice_name;

      if ($return_padding) {
        $region_padding = length $region if length $region > $region_padding;
        $number_padding = length $end    if length $end    > $number_padding;
      }
      
      if ($species eq 'Ancestral sequences') {
        $table_rows .= $slice->{'_tree'};
        $ancestral_sequences = 1;
      } else {
        $table_rows .= sprintf qq{<a href="%s">$slice_name</a><br />}, $hub->url({ %url_params, r => "$region:$start-$end" });
      }
    }

    $table_rows .= qq{
      </td>
    </tr>};
  }
  
  $region_padding++ if $region_padding;
 
  if ($table_rows) { 
    my $rtn = qq(<table class="bottom-margin" cellspacing="0">$table_rows</table>);
    $rtn    = qq{<p>NOTE: <a href="/info/docs/compara/analyses.html#epo">How ancestral sequences are calculated</a></p>$rtn} if $ancestral_sequences;
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

  my $other_species;

  #Find the mapping reference species for EPO_LOW_COVERAGE alignments to distinguish the overlapping blocks
  if ($type =~ /EPO_LOW_COVERAGE/ && $is_low_coverage_species) {
      #HACK - have a guess based on the mlss name. Better to have this in the mlss_tag table in the database
      if ($method_link_species_set->name =~ /mammals/) {
          $other_species = "homo_sapiens";
      } elsif ($method_link_species_set->name =~ /fish/) {
          $other_species = "oryzias_latipes";
      } else {
          #sauropsids
          $other_species = "gallus_gallus";
      }
  } elsif ($class =~ /pairwise/) {
      #Find the non-reference species for pairwise alignments
      #get the non_ref name from the first block
      $other_species = $gabs->[0]->get_all_non_reference_genomic_aligns->[0]->genome_db->name;
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

      $gab_num++;

      my $slice_length = ($ref_end-$ref_start+1);

      my $align_params = "$align";
      $align_params .= "--" . $non_ref_ga->genome_db->name . "--" . $non_ref_ga->dnafrag->name . ":$non_ref_start-$non_ref_end" if ($non_ref_ga);

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
                                   species => $non_ref_ga->genome_db->name,
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

  my $table = $self->new_table(\@columns, \@rows, {
      data_table => 1,
      data_table_config => {iDisplayLength => 25},
      class             => 'fixed_width',
      sorting           => [ 'length desc' ],
      exportable        => 0
  });

  my $html = "A total of " . @$merged_blocks . " alignment blocks have been found. Please select an alignment to view by selecting a Block from the Alignment column. <br /> <br />";
  $html .= $table->render;
  
  return qq{<div class="summary_panel">$html</div>};

}

sub markup_region_change {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($change, $class, $seq);
  my $i = 0;

  foreach my $data (@$markup) {
    $change = 1 if scalar keys %{$data->{'region_change'}};
    $seq = $sequence->[$i];
    
    foreach (sort {$a <=> $b} keys %{$data->{'region_change'}}) {      
      $seq->[$_]->{'class'} .= 'end ';
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? "\n" : '') . $data->{'region_change'}->{$_} if $config->{'title_display'};
    }
    
    $i++;
  }
  
  $config->{'key'}->{'align_change'} = 1 if $change;
}

1;
