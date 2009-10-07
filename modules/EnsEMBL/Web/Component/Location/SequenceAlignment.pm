package EnsEMBL::Web::Component::Location::SequenceAlignment;

use strict;
use warnings;
use Bio::EnsEMBL::AlignStrainSlice;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

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
  my $threshold = 50000;
  
  if ($object->length > $threshold) {
    return $self->_warning(
      'Region too large',
      '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>'
    );
  }
  
  my $config = {
    display_width  => $object->param('display_width') || 60,
    site_type      => ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl',
    species        => $object->species,
    key_template   => '<p><code><span class="%s">THIS STYLE:</span></code> %s</p>',
    key            => '',
    comparison     => 1,
    maintain_exons => 1 # This is to stop the exons being reversed in markup_exons if the strand is -1
  };
  
  for ('exon_ori', 'match_display', 'snp_display', 'line_numbering', 'codons_display', 'title_display') {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
  }
  
  # FIXME: Nasty hack to allow the parameter to be defined, but false. Used when getting variations.
  # Can be deleted once we get the correct set of variations from the API 
  # (there are currently variations returned when the resequenced individuals match the reference)
  $config->{'match_display'} ||= 0;  
  $config->{'exon_display'} = 'selected' if $config->{'exon_ori'};
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'} = 1;
  }
  
  my $original_slice = $object->slice;
  $original_slice = $original_slice->invert if $object->param('strand') == -1;
  
  my $ref_slice = new EnsEMBL::Web::Proxy::Object('Slice', $original_slice, $object->__data); # Get reference slice
  my $ref_slice_obj = $ref_slice->Obj;
  my $var_hash = $object->species_defs->databases->{'DATABASE_VARIATION'};
  my @individuals;
  my @individual_slices;
  my $html;
  
  foreach ('DEFAULT_STRAINS', 'DISPLAY_STRAINS') {
    foreach my $ind (@{$var_hash->{$_}}) {
      push @individuals, $ind if $object->param($ind) eq 'yes';
    }
  }
  
  foreach my $individual (@individuals) {
    my $slice = $ref_slice_obj->get_by_strain($individual);
    
    if ($slice) {
      $slice->remove_indels; # FIXME: Can be removed once resequencing view is fixed by variation team
      push @individual_slices, $slice;
    }
  }
  
  if (scalar @individual_slices) {
    my $align_slice = new Bio::EnsEMBL::AlignStrainSlice(-SLICE => $ref_slice_obj, -STRAINS => \@individual_slices); # Get align slice
    my $slice_array = $align_slice->get_all_Slices; # Get aligned strain slice objects
    
    my @ordered_slices = sort { $a->[0] cmp $b->[0] } map { [ ($_->can('display_Slice_name') ? $_->display_Slice_name : $config->{'species'}), $_ ] } @$slice_array;
    
    $config->{'ref_slice_name'} = $ref_slice->get_individuals('reference');
    
    foreach (@ordered_slices) {
      my $slice = $_->[1];
      
      my $sl = {
        slice             => $slice,
        underlying_slices => $slice->can('get_all_underlying_Slices') ? $slice->get_all_underlying_Slices : [ $slice ],
        name              => $_->[0]
      };
      
      if ($_->[0] eq $config->{'ref_slice_name'}) {
        unshift @{$config->{'slices'}}, $sl; # Put the reference slice at the top
        $config->{'ref_slice_seq'} = [ split //, $_->[1]->seq ];
      } else {
        push @{$config->{'slices'}}, $sl;
      }
    }
    
    my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);
    
    # Order is important for the key to be displayed correctly
    $self->markup_exons($sequence, $markup, $config) if $config->{'exon_display'};
    $self->markup_codons($sequence, $markup, $config) if $config->{'codons_display'};
    $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
    $self->markup_comparisons($sequence, $markup, $config); # Always called in this view
    $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};
    
    $config->{'key'} .= '<p><code>~&nbsp;&nbsp;</code>No resequencing coverage at this position</p>' if $slice_array->[0]->isa('Bio::EnsEMBL::StrainSlice');
    $config->{'key'} =~ s/(Location of SNPs)/$1 - <strong>Note: Inserts and deletes are currently disabled for this display<\/strong>/; # FIXME: Can be removed once resequencing view is fixed by variation team
    
    my $slice_name = $original_slice->name;
    
    my (undef, undef, $region, $start, $end) = split /:/, $slice_name;
    
    my $table = qq{
    <table>
      <tr>
        <th>$config->{'species'} &gt;&nbsp;</th>
        <td><a href="/$config->{'species'}/Location/View?r=$region:$start-$end">$slice_name</a><br /></td>
      </tr>
    </table>
    };
    
    $config->{'html_template'} = "<p>$config->{'key'}</p>$table<pre>%s</pre>";
  
    $html = $self->build_sequence($sequence, $config);
  } else {
    my $strains = ($object->species_defs->translate('strain') || 'strain') . 's';
    
    if ($ref_slice->get_individuals('reseq')) {
      $html = "Please select $strains to display from the 'Configure this page' link to the left";
    } else {
      $html = 'No resequenced $strains available for this species';
    }
  }
  
  return $html;
}

1;
