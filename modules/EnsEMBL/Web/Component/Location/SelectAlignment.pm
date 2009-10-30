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
  my $url = $object->_url({
    type     => 'Component',
    action   => $object->type,
    function => 'Web/SelectAlignment/ajax',
    no_wrap  => 1,
    %{$object->multi_params}
  });
  
  return sprintf('
    <div class="autocenter navbar" style="width:%spx; text-align: left; clear: both">
      <a class="modal_link" href="%s">Select species for comparison</a>
    </div>',
    $self->image_width,
    $url
  );
}

sub content_ajax {
  my $self = shift;
  my $object = $self->object;
  
  my $params = $object->multi_params;  
  my $url = $object->_url({ function => undef, align => $object->param('align') }, 1);
  
  my $alignments = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $object->species;
  
  my %species;
  my ($include_list, $exclude_list);
  my $extra_inputs;
  
  # get species (and parameters) already shown on the page
  my %shown = map { $object->param("s$_") => $_ } grep s/^s(\d+)$/$1/, $object->param;
  my $next_id = 1 + scalar keys %shown;
  
  $extra_inputs .= sprintf '<input type="hidden" name="%s" value="%s" />', escapeHTML($_), escapeHTML($url->[1]{$_}) for sort keys %{$url->[1]};
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      # this will fail for vega intra species compara
      if ($alignments->{$i}->{'species'}->{$primary_species} && !/^$primary_species|merged$/) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        if ($species{$_}) {
          $species{$_} .= "/$type";
        } else {
          $species{$_} = $object->species_defs->species_label($_, 1) . "###$type";
        }
      }
    }
  }
  
  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = $object->species_defs->species_label($primary_species, 1) . "###chromosome $chr";
  }
  
  $include_list .= sprintf '<li class="%s"><span>%s</span><span class="switch"></span></li>', $_, join ' - ', split /###/, $species{$_} for sort { $shown{$a} <=> $shown{$b} } keys %shown;
  $exclude_list .= sprintf '<li class="%s"><span>%s</span><span class="switch"></span></li>', $_, join ' - ', split /###/, $species{$_} for sort { $species{$a} cmp $species{$b} } grep !$shown{$_}, keys %species;
  
  my $content = sprintf('
    <div class="content">
      <form action="%s" method="get">%s</form>
      <div class="species_list">
        <h2>Current species</h2>
        <ul class="included">
          %s
        </ul>
      </div>
      <div class="species_list">
        <h2>Other available species</h2>
        <ul class="excluded">
          %s
        </ul>
      </div>
      <p class="invisible">.</p>
    </div>',
    $url->[0],
    $extra_inputs,
    $include_list,
    $exclude_list,
  );
  
  $content =~ s/\n//g;
  
  return qq{{'content':'$content','panelType':'SpeciesSelector','wrapper':'<div class="panel modal_wrapper"></div>','nav':''}};
}

1;
