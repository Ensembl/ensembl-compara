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
  
  $self->{'subslice_length'} = $self->object->param('force') || 100 * ($self->object->param('display_width') || 60) if $self->object;
}

sub caption {
  return undef;
}

sub content {  
  my $self = shift;
  my $object = $self->object;
  my $slice = $object->get_slice_object->Obj;
  
  my $align = $object->param('align');
  
  my ($error, $warnings) = $self->check_for_errors($object, $align, $object->species);
  
  return $error if $error;
  
  my $html;
  
  # Get all slices for the gene
  my ($slices, $slice_length) = $self->get_slices($object, $slice, $align, $object->species);
  
  if ($align && $slice_length >= $self->{'subslice_length'}) {    
    my ($table, $padding) = $self->get_slice_table($slices, 1);
    
    my $url = qq{/@{[$object->species]}/Component/Gene/Web/ComparaAlignments/sequence?padding=$padding;length=$slice_length};    
    $html = $self->get_key($object) . $table;
    
    if ($ENV{'ENSEMBL_AJAX_VALUE'} eq 'enabled') {
      $html .= qq{<div class="ajax" title="['$url;$ENV{'QUERY_STRING'}']"></div>};
    } else {
      map { $url .= ";$_=" . $object->param($_) } $object->param;
      
      my $renderer = new EnsEMBL::Web::Document::Renderer::Assembler(session => $object->get_session);
      $renderer->print(HTTP::Request->new('GET', $object->species_defs->ENSEMBL_BASE_URL . $url));
      $renderer->process;
      
      $html .= $renderer->content;
    }
  } else {
    $html = $self->content_sub_slice($slices, $warnings); # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sequence {
  my $self = shift;
  my $object = $self->object;
  my $slice = $object->get_slice_object->Obj;
  my $slice_length = $object->param('length') || $slice->length;
  
  return unless ($slice_length >= $self->{'subslice_length'}); # The sequence will have been printed already by content calling content_sub_slice directly
  
  my ($error, $warnings) = $self->check_for_errors($object, $object->param('align'), $object->species);
  
  return if $error; # The error will have been printed already by content
  
  my $i = 1;
  my $j = $self->{'subslice_length'};
  my $end = (int ($slice_length / $self->{'subslice_length'})) * $self->{'subslice_length'};
  my $base_url = qq{/@{[$object->species]}/Component/Gene/Web/ComparaAlignments/sub_slice?$ENV{'QUERY_STRING'}};
  
  my $renderer = ($ENV{'ENSEMBL_AJAX_VALUE'} eq 'enabled') ? undef : new EnsEMBL::Web::Document::Renderer::Assembler(session => $object->get_session);
  
  my ($url, $html);
  
  # The display is split into a managable number of sub slices, which will be processed in parallel by requests
  while ($j <= $slice_length) {
    $url = qq{$base_url;start=$i;end=$j};
    
    if ($renderer) {
      $renderer->print(HTTP::Request->new('GET', $object->species_defs->ENSEMBL_BASE_URL . $url));
    } else {
      $html .= qq{<div class="ajax" title="['$url']"></div>};
    }
    
    $i = $j + 1;
    $j += $self->{'subslice_length'} unless $j == $end;
    
    $j = $slice_length if $j == $end;
  }
  
  if ($renderer) {
    $renderer->process;
    $html = $renderer->content;
  }
  
  return $html . $warnings;
}

sub content_sub_slice {
  my $self = shift;
  my ($slices, $warnings) = @_;
  
  my $object = $self->object;
  my $slice  = $object->get_slice_object->Obj;
  
  my $start = $object->param('start');
  my $end = $object->param('end');
  my $padding = $object->param('padding');
  my $slice_length = $object->param('length') || $slice->length;

  my $config = {
    display_width => $object->param('display_width') || 60,
    site_type => ucfirst lc $object->species_defs->ENSEMBL_SITETYPE || 'Ensembl',
    species => $object->species,
    key_template => qq{<p><code><span class="%s">THIS STYLE:</span></code> %s</p>},
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
    ($slices) = $self->get_slices($object, $slice, $config->{'align'}, $config->{'species'}, $start, $end);
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
  
  # Only if this IS NOT a sub slice - print the key and the slice list
  my $template = "<p>$config->{'key'}</p>" . $self->get_slice_table($config->{'slices'}) unless ($start && $end);
  
  # Only if this IS a sub slice - remove margins from <pre> elements
  my $style = ($start == 1) ? "margin-bottom:0px;" : ($end == $slice_length) ? "margin-top:0px;" : "margin-top:0px; margin-bottom:0px" if ($start && $end);
  
  $config->{'html_template'} = qq{$template<pre style="$style">%s</pre>};
  
  if ($padding) {
    my @pad = split (/,/, $padding);
    
    foreach (keys %{$config->{'padded_species'}}) {
      $config->{'padded_species'}->{$_} = $_ . (' ' x ($pad[0] - length $_));
    }
    
    if ($config->{'line_numbering'} eq 'slice') {
      $config->{'padding'}->{'pre_number'} = $pad[1];
      $config->{'padding'}->{'number'} = $pad[2];
    }
  }
  
  return $self->build_sequence($sequence, $config) . $warnings;
}


sub get_slices {
  my $self = shift;
  my ($object, $slice, $align, $species, $start, $end) = @_;
  
  my @slices;
  my @formatted_slices;
  my $length;

  if ($align) {
    push @slices, @{$self->get_alignments($object, $slice, $align, $species, $start, $end)};
  } else {
    # If no alignment selected then we just display the original sequence as in geneseqview
    push @slices, $slice;
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
    
    $length ||= $_->length; # Set the slice length value for the reference slice only
  }
  
  return (\@formatted_slices, $length);
}

sub get_alignments {
  my $self = shift;
  my ($object, $slice, $selected_alignment, $species, $start, $end) = @_;
  
  $selected_alignment ||= 'NONE';
  
  my $compara_db = $object->database('compara');
  my $as_adaptor = $compara_db->get_adaptor('AlignSlice');
  my $mlss_adaptor = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($selected_alignment);
  my $align_slice = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, 'expanded', 'restrict');
  
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
  unshift (@selected_species, $species) if scalar @selected_species;
  
  $align_slice = $align_slice->sub_AlignSlice($start, $end) if ($start && $end);
  
  return $align_slice->get_all_Slices(@selected_species);
}

sub check_for_errors {
  my $self = shift;
  my ($object, $align, $species) = @_;

  return (undef, $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>')) unless $align;

  # Check for errors
  my $h = $object->species_defs->multi_hash->{'DATABASE_COMPARA'};
  my $align_details = $h->{'ALIGNMENTS'}{$align} if exists $h->{'ALIGNMENTS'};
  
  if (!$align_details) {
    return $self->_error(
      'Unknown alignment',
      sprintf (
        '<p>The alignment you have select "%s" does not exist in the current database.</p>',
        escapeHTML($align)
      )
    );
  }

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

  my @skipped;
  my $warnings;

  if ($align_details->{'class'} !~ /pairwise/) { # This is a multiway alignment
    foreach (keys %{$align_details->{species}}) {
      my $key = sprintf ('species_%d_%s', $align, lc $_);

      next if $species eq $_;
      
      push (@skipped, $_) if (($object->param($key)||'no') eq 'no');
    }

    if (scalar @skipped) {
      $warnings = $self->_info(
        'Species hidden by configuration',
        sprintf (
          '<p>The following %d species in the alignment are not shown in the image: %s. Use the "<strong>Configure this page</strong>" on the left to show them.</p>',
          scalar @skipped,
          join (', ', sort map { $object->species_defs->species_label($_) } @skipped)
        )
      );
    }
  }

  return (undef, $warnings);
}

# This function is pretty nasty because 
# 1) Variables are declared which will be redeclare later (cannot pass them through because of parallel processing).
# 2) The key is unconditional - i.e. if variation markup is turned on, the variation key will appear even if there are no variations.
# 3) It smells like hack. This is similar to the smell of chicken which went off last month, only slightly worse.
sub get_key {
  my $self = shift;
  my $object = shift;
  
  my $site_type = ucfirst lc $object->species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my $key_template = qq{<p><code><span class="%s">THIS STYLE:</span></code> %s</p>};
  
  my $exon_label = ucfirst $object->param('exon_display');
  $exon_label = $site_type if $exon_label eq 'Core';
  
  my @map = (
    [ 'conservation_display', 'con' ],
    [ 'codons_display', 'cu' ],
    [ 'exon_display', 'e2' ],
    [ 'snp_display', 'sn,si,sd' ]
  );
  
  my $key = {
    con => "Location of conserved regions (where >50&#37; of bases in alignments match)",
    cu  => "Location of START/STOP codons",
    e2  => "Location of $exon_label exons",
    sn  => "Location of SNPs",
    si  => "Location of insertions",
    sd  => "Location of deletions"
  };
  
  my $rtn = '';
  
  foreach my $param (@map) {
    next if (($object->param($param->[0])||'off') eq 'off');
    
    foreach (split (/,/, $param->[1])) {
      $rtn .= sprintf ($key_template, $_, $key->{$_});
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
  my ($slices, $return_padding) = @_;

  my $table_rows;
  my ($species_padding, $region_padding, $number_padding);

  foreach (@$slices) {
    my $species = $_->{'name'};
    
    $species_padding = length $species if $return_padding && length ($species) > $species_padding;
    
    $table_rows .= qq{
    <tr>
      <th>$species &gt;&nbsp;</th>
      <td>};
    
    foreach my $slice (@{$_->{'underlying_slices'}}) {
      next if $slice->seq_region_name eq 'GAP';
      
      my $slice_name = $slice->name;
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $slice_name);
      
      if ($return_padding) {
        $region_padding = length $region if length ($region) > $region_padding;
        $number_padding = length $end if length ($end) > $number_padding;
      }

      if ($species eq 'Ancestral_sequences') {
        $table_rows .= $slice->{'_tree'};
      } else {
        $table_rows .= qq{
          <a href="/$species/Location/View?r=$region:$start-$end">$slice_name</a><br />};
      }
    }

    $table_rows .= qq{
      </td>
    </tr>};
  }
  
  $region_padding++ if $region_padding;

  my $rtn = qq{
  <table>$table_rows
  </table>
  };
  
  return $return_padding ? ($rtn, "$species_padding,$region_padding,$number_padding") : $rtn;
}

1;
