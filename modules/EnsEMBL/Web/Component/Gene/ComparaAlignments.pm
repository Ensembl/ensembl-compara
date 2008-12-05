package EnsEMBL::Web::Component::Gene::ComparaAlignments;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $slice = $object->get_slice_object->Obj;
  my $length = $slice->length;

  my $width = $object->param('display_width') || 60;
  my $increment = 100 * $width;
  
  # Get all slices for the gene
  my ($slices, $warnings, $error) = $self->get_slices($object, $slice, $object->param('align'), $object->species);
  
  return $error if $error;
  
  if ($length > $increment) {
    my $i = 1;
    my $j = $increment;
    my $end = (int ($length / $increment)) * $increment;
    my $title;
    
    my $html = $self->get_key($object) . $self->get_slice_table($slices);
    
    # The display is split into a managable number of sub slices, which will be processed in parallel by AJAX calls
    while ($j <= $length) {
      $title = qq{/@{[$self->object->species]}/Component/Gene/Web/ComparaAlignments/sub_slice?$ENV{'QUERY_STRING'}&amp;start=${i}&amp;end=$j};
      $html .= qq{<div class="ajax" title="['$title']"></div>};

      $i = $j + 1;
      $j += $increment;

      $j = $length if $j == $end;
    }
    
    $html .= $warnings;
    
    return $html;
  } else {
    return $self->content_sub_slice($slices, $warnings); # Direct call if the sequence length is short enough
  }
}

sub content_sub_slice {
  my $self = shift;
  my ($slices, $warnings) = @_;
  
  my $object = $self->object;
  my $slice  = $object->get_slice_object->Obj;
  my $slice_length = $slice->length;

  my $start = $object->param('start');
  my $end = $object->param('end');
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;

  my $config = {
    display_width => $object->param('display_width') || 60,
    colours => \%c,
    site_type => ucfirst lc $object->species_defs->ENSEMBL_SITETYPE || 'Ensembl',
    species => $object->species,
    key_template => qq{<p><code><span style="%s">THIS STYLE:</span></code> %s</p>},
    key => '',
    comparison => 1,
    db => $object->get_db,
    sub_slice_start => $start,
    sub_slice_end => $end
  };

  for ('exon_display', 'exon_ori', 'snp_display', 'line_numbering', 'conservation_display', 'codons_display', 'title_display', 'align') {
    $config->{$_} = $object->param($_) unless $object->param($_) eq "off";
  }

  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'} = 1;
  }

  # Requesting data from a sub slice
  if ($start && $end) {
    my $error;
    my $sub_slice = $slice->sub_Slice($start, $end);
    
    $slice = $sub_slice;
    
    ($slices, undef, $error) = $self->get_slices($object, $slice, $config->{'align'}, $config->{'species'});
    
    return $error if $error;
  }
  
  $config->{'slices'} = $slices;
  
  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
  
  # markup_comparisons must be called first to get the order of the comparison sequences
  # The order these functions are called in is also important because it determines the order in which things are added to $config->{'key'}
  $self->markup_comparisons($sequence, $markup, $config) if $config->{'align'};
  $self->markup_conservation($sequence, $config) if $config->{'conservation_display'};
  $self->markup_codons($sequence, $markup, $config) if $config->{'codons_display'};
  $self->markup_exons($sequence, $markup, $config) if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};
  
  # Only if this IS NOT a sub slice
  my $template = "<p>$config->{'key'}</p>" . $self->get_slice_table($config->{'slices'}) unless ($start && $end);
  
  # Only if this IS a sub slice
  my $style = ($start == 1) ? "margin-bottom:0px;" : ($end == $slice_length) ? "margin-top:0px;" : "margin-top:0px; margin-bottom:0px" if ($start && $end);
  
  $config->{'html_template'} = qq{$template<pre style="$style">%s</pre>};

  return $self->build_sequence($sequence, $config) . $warnings;
}

sub get_alignments {
  my $self = shift;
  my ($object, $slice, $selected_alignment, $species) = @_;

  $selected_alignment ||= 'NONE';

  my $compara_db = $object->database('compara');
  my $mlss_adaptor = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($selected_alignment);
  my $as_adaptor = $compara_db->get_adaptor('AlignSlice');
  
  # This call is slow for large genes and comparison sets
  # TODO: Hassle the API team until they make it better
  my $align_slice = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, undef, 'restrict'); 

  my @selected_species;

  foreach (grep { /species_$selected_alignment/ } $object->param) {
    if ($object->param($_) eq 'yes') {
      /species_${selected_alignment}_(.+)/;
      push (@selected_species, ucfirst $1) unless $1 =~ /$species/i;
    }
  }

  # I could not find a better way to distinguish between pairwise and multiple alignments.
  # The difference is that in case of multiple alignments
  # there are checkboxes for all species from the alignment apart from the reference species:
  # So we need to add the reference species to the list of selected species.
  # In case of pairwise alignments the list remains empty - that will force the display
  # of all available species in the alignment

  if (scalar (@{$method_link_species_set->species_set}) > 2) {
    unshift @selected_species, $species;
  }

  my $alignments = $align_slice->get_all_Slices(@selected_species);

  return $alignments;
}

sub get_slices {
  my $self = shift;
  my ($object, $slice, $align, $species) = @_;
  
  my ($error, $warnings);
  my @slices;
  my @formatted_slices;

  if ($align) {
    ($error, $warnings) = $self->check_for_errors($object, $align, $species);

    return (undef, undef, $error) if $error;

    push @slices, @{$self->get_alignments($object, $slice, $align, $species)};
  } else {
    # If 'No alignment' selected then we just display the original sequence as in geneseqview
    push @slices, $slice;

    $warnings .= $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>');
  }
  
  foreach (@slices) {
    my $name = $_->can('display_Slice_name') ? $_->display_Slice_name : $species;
    
    # get_all_underlying_Slices is slow for large genes and comparison sets
    # TODO: Hassle the API team until they make it better
    push (@formatted_slices, {
      slice => $_,
      underlying_slices => $_->can('get_all_underlying_Slices') ? $_->get_all_underlying_Slices : [$_],
      name => $name
    });
  }
  
  return (\@formatted_slices, $warnings);
}

sub check_for_errors {
  my $self = shift;
  my ($object, $align, $species) = @_;

  # Check for errors
  my $h = $object->species_defs->multi_hash->{'DATABASE_COMPARA'};
  my %c = exists $h->{'ALIGNMENTS'} ? %{$h->{'ALIGNMENTS'}} : ();

  if (!exists $c{$align}) {
    return $self->_error(
      'Unknown alignment',
      sprintf (
        '<p>The alignment you have select "%s" does not exist in the current database.</p>',
        escapeHTML($align)
      )
    );
  }

  my $align_details = $c{$align};

  if (!exists $align_details->{'species'}{$species}) {
    return $self->_error(
      'Unknown alignment',
      sprintf (
        '<p>%s is not part of the %s alignment in the database.</p>',
        $object->species_defs->species_label($species),
        escapeHTML($align_details->{'name'})
      )
    );
  }

  my @species = ();
  my @skipped = ();
  my $warnings = '';

  if ($align_details->{'class'} =~ /pairwise/) { # This is a pairwise alignment
    foreach (keys %{$align_details->{species}}) {
      push @species, $_ unless $species eq $_;
    }
  } else { # This is a multiway alignment
    foreach (keys %{$align_details->{species}}) {
      my $key = sprintf ('species_%d_%s', $align, lc $_);

      next if $species eq $_;

      if ($object->param($key) eq 'no') {
        push @skipped, $_;
      } else {
        push @species, $_;
      }
    }
  }

  if (@skipped) {
    $warnings .= $self->_info(
      'Species hidden by configuration',
      sprintf (
        '<p>The following %d species in the alignment are not shown in the image: %s. Use the "<strong>Configure this page</strong>" on the left to show them.</p>%s',
        scalar @skipped,
        join (', ', sort map { $object->species_defs->species_label($_) } @skipped)
      )
    );
  }

  return (undef, $warnings);
}

# This function is pretty nasty because 
# 1) Variables are declared which will be redeclare later (cannot pass them through because of parallel processing).
# 2) The key is unconditional - i.e. if variation markup is turned on, the variation key will appear even if there are no variations.
# 3) It smells like hack. This is similar to the smell of chicken which went off last month, only worse.
sub get_key {
  my $self = shift;
  my $object = shift;
  
  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my $site_type = ucfirst lc $object->species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my $key_template = qq{<p><code><span style="%s">THIS STYLE:</span></code> %s</p>};
  
  my $exon_label = ucfirst $object->param('exon_display');
  $exon_label = $site_type if $exon_label eq 'Core';
  
  my @map = (
    [ 'conservation_display', 'conservation' ],
    [ 'codons_display', 'codonutr' ],
    [ 'exon_display', 'exon2' ],
    [ 'snp_display', 'snp_default,snp_gene_delete' ]
  );
  
  my $key = {
    conservation    => "Location of conserved regions (where >50% of bases in alignments match)",
    codonutr        => "Location of START/STOP codons",
    exon2           => "Location of $exon_label exons",
    snp_default     => "Location of SNPs",
    snp_gene_delete => "Location of deletions"
  };
  
  my $rtn = '';
  
  foreach my $param (@map) {
    next if $object->param($param->[0]) eq "off";
    
    foreach (split (/,/, $param->[1])) {
      my $attr = $_ eq 'exon2' ? 'color' : 'background-color';
      $rtn .= sprintf ($key_template, "$attr:$c{$_};", $key->{$_});
    }
  }
  
  if ($object->param('line_numbering') eq 'slice' && $object->param('align')) {
    $rtn .= qq{ NOTE: For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line};
  }
  
  return $rtn;
}

# Displays slices for all species above the sequence
sub get_slice_table {
  my $self = shift;
  my $slices = shift;

  my $table_rows;

  foreach (@$slices) {
    my $species = $_->{'name'};

    $table_rows .= qq{
    <tr>
      <th>$species &gt;&nbsp;</th>
      <td>};

    foreach my $slice (@{$_->{'underlying_slices'}}) {
      next if $slice->seq_region_name eq 'GAP';

      if ($species eq 'Ancestral_sequences') {
        $table_rows .= $slice->{'_tree'};
      } else {
        my $slice_name = $slice->name;

        my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $slice_name);

        $table_rows .= qq{
          <a href="/$species/Location/View?r=$region:$start-$end">$slice_name</a><br />};
      }
    }

    $table_rows .= qq{
      </td>
    </tr>};
  }

  return qq{
  <table>$table_rows
  </table>
  };
}

1;
