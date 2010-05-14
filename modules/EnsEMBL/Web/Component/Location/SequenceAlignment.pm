package EnsEMBL::Web::Component::Location::SequenceAlignment;

use strict;

use Bio::EnsEMBL::MappedSliceContainer;
use Bio::EnsEMBL::DBSQL::StrainSliceAdaptor;

use base qw(EnsEMBL::Web::Component::Location EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  
  my $object    = $self->object;
  my $threshold = 50001;
  
  if ($object->length > $threshold) {
    return $self->_warning(
      'Region too large',
      '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>'
    );
  }
  
  my $original_slice = $object->slice;
  $original_slice    = $original_slice->invert if $object->param('strand') == -1;
  my $ref_slice      = $self->new_object('Slice', $original_slice, $object->__data); # Get reference slice
  my $ref_slice_obj  = $ref_slice->Obj;
  my $var_db         = $object->species_defs->databases->{'DATABASE_VARIATION'};
  my @individuals;
  my $html;
    
  my $config = {
    display_width  => $object->param('display_width') || 60,
    site_type      => ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl',
    species        => $object->species,
    comparison     => 1,
    ref_slice_name => $ref_slice->get_individuals('reference')
  };
  
  foreach ('exon_ori', 'match_display', 'snp_display', 'line_numbering', 'codons_display', 'title_display') {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
  }
  
  # FIXME: Nasty hack to allow the parameter to be defined, but false. Used when getting variations.
  # Can be deleted once we get the correct set of variations from the API 
  # (there are currently variations returned when the resequenced individuals match the reference)
  $config->{'match_display'} ||= 0;  
  $config->{'exon_display'} = 'selected' if $config->{'exon_ori'};
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'}     = 1;
  }
  
  foreach ('DEFAULT_STRAINS', 'DISPLAY_STRAINS') {
    foreach my $ind (@{$var_db->{$_}}) {
      push @individuals, $ind if $object->param($ind) eq 'yes';
    }
  }
  
  if (scalar @individuals) {
    $config->{'slices'} = $self->get_slices($ref_slice_obj, \@individuals, $config);
    
    my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
    
    # Order is important for the key to be displayed correctly
    $self->markup_exons($sequence, $markup, $config)     if $config->{'exon_display'};
    $self->markup_codons($sequence, $markup, $config)    if $config->{'codons_display'};
    $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
    $self->markup_comparisons($sequence, $markup, $config); # Always called in this view
    $self->markup_line_numbers($sequence, $config)       if $config->{'line_numbering'};
    
    my $slice_name = $original_slice->name;
    
    my (undef, undef, $region, $start, $end) = split /:/, $slice_name;
    my $url = $object->_url({ action => 'View', r => "$region:$start-$end" });
    
    my $table = qq{
      <table>
        <tr>
          <th>$config->{'species'} &gt;&nbsp;</th>
          <td><a href="$url">$slice_name</a><br /></td>
        </tr>
      </table>
    };
    
    $config->{'html_template'} = sprintf('<div class="sequence_key">%s</div>', $self->get_key($config)) . "$table<pre>%s</pre>";
  
    $html = $self->build_sequence($sequence, $config);
  } else {
    my $strains = ($object->species_defs->translate('strain') || 'strain') . 's';
    
    if ($ref_slice->get_individuals('reseq')) {
      $html = $self->_info('No strains specified', qq{<p>Please select $strains to display from the "<strong>Configure this page</strong>" link to the left</p>});
    } else {
      $html = $self->_warning('No strains available', qq{<p>No resequenced $strains available for this species</p>});
    }
  }
  
  return $html;
}

sub get_slices {
  my $self = shift;
  my ($ref_slice_obj, $individuals, $config) = @_;
  
  my $object = $self->object;
  
  # Chunked request
  if (!defined $individuals) {
    my $var_db = $object->species_defs->databases->{'DATABASE_VARIATION'};
    
    foreach ('DEFAULT_STRAINS', 'DISPLAY_STRAINS') {
      foreach my $ind (@{$var_db->{$_}}) {
        push @$individuals, $ind if $object->param($ind) eq 'yes';
      }
    }
  }
  
  my $msc = new Bio::EnsEMBL::MappedSliceContainer(-SLICE => $ref_slice_obj, -EXPANDED => 1);
  
  $msc->set_StrainSliceAdaptor(new Bio::EnsEMBL::DBSQL::StrainSliceAdaptor($ref_slice_obj->adaptor->db));
  $msc->attach_StrainSlice($_) for @$individuals;
  
  my @slices = ({ 
    name  => $config->{'ref_slice_name'},
    slice => $ref_slice_obj
  });
  
  foreach (@{$msc->get_all_MappedSlices}) {
    my $slice = $_->get_all_Slice_Mapper_pairs->[0]->[0];
    
    push @slices, { 
      name  => $slice->can('display_Slice_name') ? $slice->display_Slice_name : $config->{'species'}, 
      slice => $slice,
      seq   => $_->seq(1)
    };
  }
  
  $config->{'ref_slice_start'} = $ref_slice_obj->start;
  $config->{'ref_slice_end'}   = $ref_slice_obj->end;
  $config->{'ref_slice_seq'}   = [ split //, $msc->seq(1) ];
  $config->{'mapper'}          = $msc->mapper;
  
  return \@slices;
}

1;
