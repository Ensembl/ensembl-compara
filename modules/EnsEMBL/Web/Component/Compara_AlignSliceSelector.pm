package EnsEMBL::Web::Component::Compara_AlignSliceSelector;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $cdb          = shift || $self->object->param('cdb') || 'compara';
  my $object       = $self->object;
  my $db_hash      = $object->species_defs->multi_hash;
  my $params       = $object->can('multi_params') ? $object->multi_params : {};
  my $align        = $object->param('align');
  my $url          = $object->_url({ %$params, align => undef }, 1);
  my $extra_inputs = join '', map qq{<input type="hidden" name="$_" value="$url->[1]{$_}" />}, sort keys %{$url->[1] || {}};
  my $alignments   = $db_hash->{'DATABASE_COMPARA' . ($cdb =~ /pan_ensembl/ ? '_PAN_ENSEMBL' : '')}{'ALIGNMENTS'} || {}; # Get the compara database hash

  my $species = $object->species;
  my $options = '<option value="">-- Select an alignment --</option>';
  
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    (my $name = $row->{'name'}) =~ s/_/ /g;
    
    $options .= sprintf(
      '<option value="%d"%s>%s</option>',
      $row->{'id'},
      $row->{'id'} == $align ? ' selected="selected"' : '',
      encode_entities($name)
    );
  }
  
  # For the variation compara view, only allow multi-way alignments
  if ($object->type ne 'Variation') {
    $options .= '<optgroup label="Pairwise alignments">';

    my %species_hash;
    
    foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
      foreach (keys %{$alignments->{$i}->{'species'}}) {
        if ($alignments->{$i}->{'species'}->{$species} && $_ ne $species) {
          my $type = lc $alignments->{$i}->{'type'};
          
          $type =~ s/_net//;
          $type =~ s/_/ /g;
          
          $species_hash{$object->species_defs->species_label($_, 1) . "###$type"} = $i;
        }
      } 
    }
    
    foreach (sort { $a cmp $b } keys %species_hash) {
      my ($name, $type) = split /###/, $_;
      
      $options .= sprintf(
        '<option value="%d"%s>%s</option>',
        $species_hash{$_},
        $species_hash{$_} eq $align ? ' selected="selected"' : '',
        "$name - $type"
      );
    }
    
    $options .= '</optgroup>';
  }
  
  ## Get the species in the alignment
  return sprintf(qq{
    <div class="autocenter_wrapper">
      <div class="autocenter navbar" style="width:%spx; text-align:left">
        <form action="%s" method="get">
          <div style="padding:2px;">
            <label for="align">Alignment:</label> <select name="align" id="align">%s</select>
            %s
            <input value="Go &gt;" type="submit" class="go-button" />
          </div>
        </form>
      </div>
    </div>},
    $self->image_width, 
    $url->[0],
    $options,
    $extra_inputs
  );
}

1;
