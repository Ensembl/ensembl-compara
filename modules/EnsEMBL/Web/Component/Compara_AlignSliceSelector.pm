package EnsEMBL::Web::Component::Compara_AlignSliceSelector;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->_url({ align => undef }, 1 );
  my $extra_inputs;
  
  foreach (sort keys %{$url->[1]||{}}) {
    $extra_inputs .= sprintf '
      <input type="hidden" name="%s" value="%s" />', escapeHTML($_), escapeHTML($url->[1]{$_});
  }

  my $align = $object->param('align');
  
  ## Get the compara database hash!
  my $hash = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
  my $species = $object->species;
  
  my $options = qq{
        <option value="">-- Select an alignment --</option>};
  
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    my $row = $hash->{$row_key};
    
    next unless $row->{'species'}->{$species};
    
    $options .= sprintf '
        <option value="%d"%s>%s</option>',
      $row_key,
      $row_key eq $align ? ' selected="selected"' : '',
      escapeHTML($row->{'name'});
  }
  
  # For the variation compara view, only allow multi-way alignments
  if ($object->type ne 'Variation') {
    $options .= qq{
          <optgroup label="Pairwise alignments">};

    my $species_hash = {};
    
    foreach my $i (keys %$hash) {
      foreach (keys %{$hash->{$i}->{'species'}}) {
        if ($hash->{$i}->{'class'} =~ /pairwise/ && $hash->{$i}->{'species'}->{$species} && $_ ne $species) {
          my $type = lc $hash->{$i}->{'type'};
          
          $type =~ s/_net//i;
          $type =~ s/_/ /g;
          
          $species_hash->{$object->species_defs->species_label($_, 1) . "###$type"} = $i;
        }
      } 
    }
    
    foreach (sort { $a cmp $b } keys %$species_hash) {
      my ($name, $type) = split (/###/, $_);
      
      $options .= sprintf '
            <option value="%d"%s>%s</option>',
        $species_hash->{$_},
        $species_hash->{$_} eq $align ? ' selected="selected"' : '',
        "$name - $type";
    }
    
    $options .= qq{
          </optgroup>};
  }
  
  
  ## Get the species in the alignment and turn on the approriate Synteny tracks!
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx; text-align:left" >
    <form action="%s" method="get"><div style="padding:2px;">
      <label for="align">Alignment:</label> <select name="align" id="align">%s
      </select>%s
      %s
      <input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
  </div>),
    $self->image_width, 
    $url->[0],
    $options,
    $extra_inputs;
}

1;
