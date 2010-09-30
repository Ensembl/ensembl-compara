# $Id$

package EnsEMBL::Web::Component::Compara_Alignments;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  my $object = $self->object;
  
  $self->cacheable(1);
  $self->ajaxable(1);
  
  $self->{'subslice_length'} = $object->param('force') || 100 * ($object->param('display_width') || 60) if $object;
}

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $cdb       = shift || $object->param('cdb') || 'compara';
  my $slice     = $object->slice;
  my $threshold = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $species   = $object->species;
  my $type      = $object->type;
  
  if ($type eq 'Location' && $slice->length > $threshold) {
    return $self->_warning(
      'Region too large',
      '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>'
    );
  }
  
  my $align_param = $object->param('align');
  my ($align) = split '--', $align_param;
  
  my ($error, $warnings) = $self->check_for_errors($object, $align, $species, $cdb);

  return $error if $error;
  
  my $html;
  
  if ($type eq 'Gene') {
    my $location = $object->Obj; # Use this instead of $slice because the $slice region includes flanking
    
    $html .= sprintf(
      '<p style="padding:0.5em 0 1.5em"><strong><a href="%s">Go to a graphical view</a> (Genomic align slice) of this alignment</strong></p>',
      $object->_url({
        type   => 'Location',
        action => 'Compara_Alignments/Image',
        align  => $align,
        r      => $location->seq_region_name . ':' . $location->seq_region_start . '-' . $location->seq_region_end
      })
    );
  }
  
  $slice = $slice->invert if $object->param('strand') == -1;
  
  # Get all slices for the gene
  my ($slices, $slice_length) = $self->get_slices($slice, $align_param, $species, undef, undef, $cdb);
  
  if ($align && $slice_length >= $self->{'subslice_length'}) {
    my ($table, $padding) = $self->get_slice_table($slices, 1);
    my $base_url = $self->ajax_url('sub_slice') . ";padding=$padding;length=$slice_length";
    
    $html .= '<div class="sequence_key"></div>' . $table . $self->chunked_content($slice_length, $self->{'subslice_length'}, $base_url) . $warnings;
  } else {
    $html .= $self->content_sub_slice($slice, $slices, $warnings, undef, $cdb); # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sub_slice {
  my $self = shift;
  my ($slice, $slices, $warnings, $defaults, $cdb) = @_;
  
  my $object = $self->object;
  
  $slice ||= $object->slice;
  $slice = $slice->invert if !$_[0] && $object->param('strand') == -1;
  
  my $start = $object->param('subslice_start');
  my $end = $object->param('subslice_end');
  my $padding = $object->param('padding');
  my $slice_length = $object->param('length') || $slice->length;

  my $config = {
    display_width   => $object->param('display_width') || 60,
    site_type       => ucfirst lc $object->species_defs->ENSEMBL_SITETYPE || 'Ensembl',
    species         => $object->species,
    display_species => $object->species_defs->SPECIES_SCIENTIFIC_NAME,
    comparison      => 1,
    db              => $object->can('get_db') ? $object->get_db : 'core',
    sub_slice_start => $start,
    sub_slice_end   => $end
  };
  
  for (qw(exon_display exon_ori snp_display line_numbering conservation_display codons_display region_change_display title_display align)) {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
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
  my $style = $start == 1 ? 'margin-bottom:0px;' : $end == $slice_length ? 'margin-top:0px;': 'margin-top:0px; margin-bottom:0px' if $start && $end;
  
  $config->{'html_template'} = qq{$template<pre style="$style">%s</pre>};
  
  if ($padding) {
    my @pad = split ',', $padding;
    
    $config->{'padded_species'}->{$_} = $_ . (' ' x ($pad[0] - length $_)) for keys %{$config->{'padded_species'}};
    
    if ($config->{'line_numbering'} eq 'slice') {
      $config->{'padding'}->{'pre_number'} = $pad[1];
      $config->{'padding'}->{'number'}     = $pad[2];
    }
  }
  
  return $self->build_sequence($sequence, $config) . $warnings;
}

sub get_slices {
  my $self = shift;
  my ($slice, $align, $species, $start, $end, $cdb) = @_;
  
  my $object       = $self->object;
  my $species_defs = $object->species_defs;
  my $vega_compara = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'VEGA_COMPARA'};
  my (@slices, @formatted_slices, $length);

  if ($align) {
    push @slices, @{$self->get_alignments(@_)};
  } else {
    push @slices, $slice; # If no alignment selected then we just display the original sequence as in geneseqview
  }
  
  foreach (@slices) {
    my $name         = $_->can('display_Slice_name') ? $_->display_Slice_name : $species;
    my $display_name = $vega_compara ? $self->get_full_name($_) : $species_defs->get_config($name, 'SPECIES_SCIENTIFIC_NAME') || 'Ancestral sequences';
    
    push @formatted_slices, { 
      slice             => $_,
      underlying_slices => $_->can('get_all_underlying_Slices') ? $_->get_all_underlying_Slices : [$_],
      name              => $name,
      display_name      => $display_name
    };
    
    $length ||= $_->length; # Set the slice length value for the reference slice only
  }
  
  return (\@formatted_slices, $length);
}

sub get_alignments {
  my $self = shift;
  my ($slice, $selected_alignment, $species, $start, $end, $cdb) = @_;
  
  my $hub = $self->hub;
  my $target_slice;
  my ($align, $target_species, $target_slice_name) = split '--', $selected_alignment;
  $align ||= 'NONE';
  $cdb   ||= 'compara';
  
  if ($target_slice_name) {
    my $target_slice_adaptor = $hub->database('core', $target_species)->get_SliceAdaptor;
    $target_slice = $target_slice_adaptor->fetch_by_region('toplevel', $target_slice_name);
  }
  
  my $func                    = $self->{'alignments_function'} || 'get_all_Slices';
  my $compara_db              = $hub->database($cdb);
  my $as_adaptor              = $compara_db->get_adaptor('AlignSlice');
  my $mlss_adaptor            = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($align);
  my $align_slice             = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, 'expanded', 'restrict', $target_slice);
  
  my @selected_species;
  
  foreach (grep { /species_$align/ } $hub->param) {
    if ($hub->param($_) eq 'yes') {
      /species_${align}_(.+)/;
      push @selected_species, $1 unless $1 =~ /$species/i;
    }
  }
  
  # I could not find a better way to distinguish between pairwise and multiple alignments.
  # The difference is that in case of multiple alignments
  # there are checkboxes for all species from the alignment apart from the reference species:
  # So we need to add the reference species to the list of selected species.
  # In case of pairwise alignments the list remains empty - that will force the display
  # of all available species in the alignment
  unshift @selected_species, lc $species if scalar @selected_species;
  
  $align_slice = $align_slice->sub_AlignSlice($start, $end) if $start && $end;
  
  return $align_slice->$func(@selected_species);
}

sub check_for_errors {
  my $self = shift;
  my ($object, $align, $species, $cdb) = @_;

  return (undef, $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>')) unless $align;
  
  my $species_defs  = $object->species_defs;
  my $db_key        = $cdb =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
  my $align_details = $species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};
  
  return $self->_error('Unknown alignment', '<p>The alignment you have selected does not exist in the current database.</p>') unless $align_details;

  if (!exists $align_details->{'species'}->{$species}) {
    return $self->_error('Unknown alignment', sprintf(
      '<p>%s is not part of the %s alignment in the database.</p>',
      $species_defs->species_label($species),
      encode_entities($align_details->{'name'})
    ));
  }
  
  my @skipped;
  my $warnings;
  
  if ($align_details->{'class'} !~ /pairwise/) { # This is a multiway alignment
    foreach (keys %{$align_details->{'species'}}) {
      my $key = sprintf 'species_%d_%s', $align, lc $_;

      next if $species eq $_;
      
      push @skipped, $_ if ($object->param($key)||'off') eq 'off';
    }

    if (scalar @skipped) {
      $warnings = $self->_info(
        'Species hidden by configuration',
        sprintf(
          '<p>The following %d species in the alignment are not shown. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
          scalar @skipped,
          join "</li>\n<li>", sort map { $object->species_defs->species_label($_) } @skipped
        )
      );
    }
  }

  return (undef, $warnings);
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
      <th>$species &gt;&nbsp;</th>
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
  
  my $rtn = "<table>$table_rows</table>";
  $rtn    = qq{<p>NOTE: <a href="/info/docs/compara/analyses.html#epo">How ancestral sequences are calculated</a></p>$rtn} if $ancestral_sequences;
  
  return $return_padding ? ($rtn, "$species_padding,$region_padding,$number_padding") : $rtn;
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
      $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $data->{'region_change'}->{$_} if $config->{'title_display'};
    }
    
    $i++;
  }
  
  $config->{'key'}->{'align_change'} = 1 if $change;
}

# get full name of seq-region from which the alignment comes
sub get_full_name {
  my $self   = shift;
  my $sl     = shift;
  my $object = $self->object;
  my $id;  
  
  if (ref $sl eq 'Bio::EnsEMBL::Compara::AlignSlice::Slice') {
    my $species_name = $sl->seq_region_name;
    my $chr_name     = $sl->{'slice_mapper_pairs'}->[0]->{'slice'}->{'seq_region_name'};
    
    $id = "$species_name:$chr_name";
  } else {
    $id = $object->species;
  }

  return $id;
}

1;
