package EnsEMBL::Web::Component::Location::SelectAlignment;

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
#  $url = $object->_url();
#  warn Data::Dumper::Dumper($url);

  ## Get the compara database hash!
  my $hash = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
#  warn Data::Dumper::Dumper($hash);
  my $species = $object->species;
  my $options;
  my $species_hash;
  my $c = 0;
  foreach my $i (keys %$hash) {
    foreach (keys %{$hash->{$i}->{'species'}}) {
      #this will fail for vega intra species compara
      if ($hash->{$i}->{'class'} =~ /pairwise/ && $hash->{$i}->{'species'}->{$species} && $_ ne $species) {
	my $type = lc $hash->{$i}->{'type'};
	$type =~ s/_/ /g;
	next if ($object->species_defs->species_label($_, 1) eq 'Ancestral sequence');
	$c++;
	$species_hash->{$_} = $object->species_defs->species_label($_, 1) . "###$type";
      }
    }
  }

  #get core input param
#  my $extra_inputs;
#  foreach (sort keys %{$url->[1]||{}}) {
#    warn "extra input = $_";
#    $extra_inputs .= sprintf '
#      <input type="hidden" name="%s" value="%s" />', escapeHTML($_), escapeHTML($url->[1]{$_});
#  }


  #get species (and parameters) already shown on the page
  my $max_s;
  my @shown_species;
  my $extra_inputs;
  foreach my $param($object->param) {
    if ($param =~ /^s/) {
      (my $c) = $param =~ /(\d+)/;
      $max_s = $c > $max_s ? $c : $max_s;
      my $species = $object->param($param);
      push @shown_species, [ $species, $param ];
    }
    if ($param =~ /^[srg]/) {
#      next if $param eq 'r';
      $extra_inputs .= sprintf '
      <input type="hidden" name="%s" value="%s" />', escapeHTML($param), escapeHTML($object->param($param));
    }
  }

  #new species
#  warn Data::Dumper::Dumper($species_hash);
  $options .= qq{<optgroup label="Add alignment">};
  foreach my $sp (sort { $species_hash->{$a} cmp $species_hash->{$b} } keys %$species_hash) {
    if (! grep {$_->[0] eq $sp} @shown_species) {
      my ($name, $type) = split (/###/, $species_hash->{$sp});
      $options .= sprintf '
              <option value="%s"%s>%s</option>',
	      $sp,
	      '',
	      "$name - $type";
    }
  }
  $options .= qq{</optgroup>};

 #species to remove
  $options .= qq{<optgroup label="Remove alignment">};
  foreach my $sp (sort { $a cmp $b } keys %$species_hash) {
    if (grep {$_->[0] eq $sp} @shown_species) {
      my ($name, $type) = split (/###/, $species_hash->{$sp});
      $options .= sprintf '
              <option value="%s"%s>%s</option>',
	      $sp,
	      '',
	      "$name - $type";
    }
  }
  $options .= qq{</optgroup>};

  $max_s++;
  #render the navigation bar
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx; text-align:left" >
    <form action="%s" method="get"><div style="padding:2px;">
      <label for="align">Add/Remove an alignment:</label>
      <select name="%s" id="species">%s</select>%s
      <input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
  </div>),
    $self->image_width,
    $url->[0],
    's'.$max_s, $options, $extra_inputs;
}

1;
