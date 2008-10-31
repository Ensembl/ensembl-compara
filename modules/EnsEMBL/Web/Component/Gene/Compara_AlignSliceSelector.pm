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

  my $options = '';
  my $align = $object->param('align');
  
  ## Get the compara database hash!   
  my $hash = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
  my $species = $object->species;
  
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    my $row = $hash->{$row_key};
    
    $options .= sprintf '
        <option name="align" value="%d" %s>%s</option>',
      $row_key,
      $row_key eq $align ? ' selected="selected"' : '',
      escapeHTML($row->{'name'});
  }
  
  foreach my $row_key (grep { $hash->{$_}{'class'} =~ /pairwise/ } keys %$hash) {
    my $row = $hash->{$row_key};
    
    next unless $row->{'species'}{$species};
    
    foreach (sort keys %{$row->{'species'}}) {
      next if $_ eq $species;       
      
      $options .= sprintf '
          <option name="align" value="%d" %s>%s</option>',
        $row_key,
        $row_key eq $align ? ' selected="selected"' : '',
        $object->species_defs->species_label($_);
    }
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
