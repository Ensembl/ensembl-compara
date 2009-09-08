package EnsEMBL::Web::Component::Location::SelectAlignment;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $params = $object->multi_params;
  my $url = $object->_url($params, 1);
  my $alignments = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $object->species;
  
  my %species;
  my (@add, @remove);
  my $extra_inputs;
  
  my $add_options = '<option value="">-- Select a species --</option>';
  my $remove_options = $add_options;
  
  # get species (and parameters) already shown on the page
  my %shown = map { $object->param("s$_") => $_ } grep s/^s(\d+)$/$1/, $object->param;
  my $next_id = 1 + scalar keys %shown;
  
  foreach (sort keys %{$url->[1]}) {
    $extra_inputs .= sprintf '
      <input type="hidden" name="%s" value="%s" />', escapeHTML($_), escapeHTML($url->[1]{$_});
  }
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      # this will fail for vega intra species compara
      if ($alignments->{$i}->{'species'}->{$primary_species} && !/^$primary_species|merged$/) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        $species{$_} = $object->species_defs->species_label($_, 1) . "###$type";
      }
    }
  }
  
  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = $object->species_defs->species_label($primary_species, 1) . "###chromosome $chr";
  }
  
  foreach (sort { $species{$a} cmp $species{$b} } keys %species) {
    if ($shown{$_}) {
      push @remove, [ $shown{$_}, join ' - ', split /###/, $species{$_} ];
    } else {
      push @add, [ $_, join ' - ', split /###/, $species{$_} ];
    }
  }
  
  $add_options    .= qq{<option value="$_->[0]">$_->[1]</option>} for @add;
  $remove_options .= qq{<option value="$_->[0]">$_->[1]</option>} for @remove;
  
  return sprintf ('
    <div class="autocenter navbar" style="width:%spx; text-align:left">
      <form action="%s" method="get">
        <div class="alignment_selector%s">
          <label for="align">Add an alignment:</label>
          <select name="s%s">
            %s
          </select>
          <input value="Go&gt;" type="submit" class="go-button" />
        </div>
        <div class="alignment_selector%s">
          <label for="align">Remove an alignment:</label>
          <select name="remove_alignment">
            %s
          </select>
          %s
        </div>
        %s
      </form>
    </div>',
    $self->image_width,
    $url->[0],
    scalar @add ? '' : ' hide',
    $next_id, 
    $add_options,
    scalar @remove ? '' : ' hide',
    $remove_options,
    scalar @add ? '' : '<input value="Go&gt;" type="submit" class="go-button" />',
    $extra_inputs
  );
}

1;
