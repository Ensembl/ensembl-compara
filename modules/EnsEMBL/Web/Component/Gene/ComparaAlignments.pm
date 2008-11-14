package EnsEMBL::Web::Component::Gene::ComparaAlignments;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);
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
  my $self   = shift;
  my $object = $self->object;
  my $slice  = $object->get_slice_object->Obj;

  my $colours = $object->species_defs->colour('sequence_markup');
  my %c = map { $_ => $colours->{$_}->{'default'} } keys %$colours;
  
  my @sliceArray;

  my $config = {
    wrap => $object->param('display_width') || 60,
    colours => \%c,
    site_type => ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl',
    slice_name => $slice->name,
    species => $object->species,
    key_template => qq{<p><code><span style="%s">THIS STYLE:</span></code> %s</p>},
    key => '',
    comparison => 1,
    db => $object->get_db
  };
  for ('exon_display', 'exon_ori', 'snp_display', 'line_numbering', 'conservation_display', 'codons_display', 'title_display', 'align') {
    $config->{$_} = $object->param($_) unless $object->param($_) eq "off";
  }
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'} = 1;
  }

  my ($error, $warnings);

  if ($config->{'align'}) {
    ($error, $warnings) = $self->check_for_errors($object, $config->{'align'}, $config->{'species'});

    return $error if $error;

    push @sliceArray, @{$self->get_alignments($object, $slice, $config->{'align'}, $config->{'species'})};
  } else {
    # If 'No alignment' selected then we just display the original sequence as in geneseqview
    push @sliceArray, $slice;

    $warnings .= $self->_info('No alignment specified', '<p>Select the alignment you wish to display from the box above.</p>');
  }
    
  foreach (@sliceArray) {
    my $species = $_->can('display_Slice_name') ? $_->display_Slice_name : $config->{'species'};
    
    push (@{$config->{'slices'}}, {
      slice => $_,
      underlying_slices => $_->can('get_all_underlying_Slices') ? $_->get_all_underlying_Slices : [$_],
      name => $species
    });
  }

  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
  
  # markup_comparisons must be called first to get the order of the comparison sequences
  # The order these functions are called in is also important because it determines the order in which things are added to $config->{'key'}
  $self->markup_comparisons($sequence, $markup, $config) if $config->{'align'};
  $self->markup_conservation($sequence, $markup, $config) if $config->{'conservation_display'};
  $self->markup_codons($sequence, $markup, $config) if $config->{'codons_display'};
  $self->markup_exons($sequence, $markup, $config) if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};

#  FIXME: Param doesn't exist any more
#  if ($object->param('individuals')) {
#    $config->{'key'} .= qq{ ~&nbsp;&nbsp; No resequencing coverage at this position };
#  }
  
  
  my $table = $self->get_slice_table($config);
  
  $config->{'html_template'} = qq{<p>$config->{'key'}</p>$table<pre>%s</pre>};
  
  return $self->build_sequence($sequence, $config) . $warnings;
}

sub get_alignments {
  my $self = shift;
  my ($object, $slice, $selectedAlignment, $species) = @_;

  $selectedAlignment ||= 'NONE';

  my $compara_db = $object->database('compara');
  my $mlss_adaptor = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($selectedAlignment); 
  my $as_adaptor = $compara_db->get_adaptor('AlignSlice');
  my $align_slice = $as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $method_link_species_set, undef, 'restrict');
  
  my @selected_species;
  
  foreach (grep { /species_$selectedAlignment/ } $object->param) {
    if ($object->param($_) eq 'yes') {
      /species_${selectedAlignment}_(.+)/; 
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
  
  my $rtn = $align_slice->get_all_Slices(@selected_species);
  
  if ($method_link_species_set->method_link_class =~ /GenomicAlignTree/) {
    ## Slices built from GenomicAlignTrees (EPO alignments) are returned in a specific order
    ## This tag will allow us to keep that order
    my $count = 0;
    
    $_->{'_order'} = $count++ for @$rtn;
  }

  return $rtn;
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
      my $key = sprintf 'species_%d_%s', $align, lc($_);
      
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
        scalar(@skipped), 
        join (', ', sort map { $object->species_defs->species_label($_) } @skipped)
      )
    );
  }
  
  return (undef, $warnings);
}

# Displays slices for all species above the sequence
sub get_slice_table {
  my $self = shift;
  my $config = shift;
  
  my $table_rows;

  foreach (@{$config->{'slices'}}) {
    my $species = $_->{'name'};
    
    $table_rows .= qq{
    <tr>
      <th>$species &gt;&nbsp;</th>
      <td>};
    
    foreach my $slice (@{$_->{'underlying_slices'}}) {
      next if $slice->seq_region_name eq 'GAP';
      
      my $slice_name = $slice->name;
      
      my ($stype, $assembly, $region, $start, $end, $strand) = split (/:/ , $slice_name);
      
      $table_rows .= qq{
        <a href="/$species/Location/View?r=$region:$start-$end">$slice_name</a><br />};
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

