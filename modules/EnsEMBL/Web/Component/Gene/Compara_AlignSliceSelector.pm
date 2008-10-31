package EnsEMBL::Web::Component::Gene::Compara_AlignSliceSelector;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->_url({}, 1 );
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
        <option value="">== Please select an alignment ==</option>};
  
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    my $row = $hash->{$row_key};
    
    $options .= sprintf '
        <option value="%d" %s>%s</option>',
      $row_key,
      $row_key eq $align ? ' selected="selected"' : '',
      escapeHTML($row->{'name'});
  }
  
 $options .= qq{
        <option value="">== Pairwise alignments ==</option>};

  my $species_hash = {};
  
  foreach my $i (keys %$hash) {
    foreach (keys %{$hash->{$i}->{'species'}}) {
      if ($hash->{$i}->{'class'} =~ /pairwise/ && $hash->{$i}->{'species'}->{$species} && $_ ne $species) {
        if (defined $species_hash->{$_}) {
          my $type1 = $hash->{$species_hash->{$_}}->{'type'};
          my $type2 = $hash->{$i}->{'type'};
          
          $species_hash->{"$_#$type1"} = $species_hash->{$_};
          $species_hash->{"$_#$type2"} = $i;
          
          delete $species_hash->{$_};
        } else {
          $species_hash->{$_} = $i;
        }
      }
    } 
  } 
  
  foreach (sort { $a cmp $b } keys %$species_hash) {
    my ($name, $type) = split (/#/, $_);
    
    if ($type) {
      $type =~ s/_net//i;
      $type =~ s/_/ /g;
      
      $type = " - $type";
    }
    
    $options .= sprintf '
        <option value="%d" %s>%s</option>',
      $species_hash->{$_},
      $species_hash->{$_} eq $align ? ' selected="selected"' : '',
      $object->species_defs->species_label($name) . $type;
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
