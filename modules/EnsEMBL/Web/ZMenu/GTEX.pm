=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ZMenu::GTEX;

use strict;

use List::Util qw(min max);

use Bio::EnsEMBL::IO::Parser;
use EnsEMBL::Web::REST;

use base qw(EnsEMBL::Web::ZMenu);

use List::Util qw(min);

# Note that the value of y-scale and the calculation of value must match
# or you will get the wrong ZMenus appearing.

sub summary_zmenu {
  my ($self, $args) = @_;

  my ($fudge, $slice) = $self->_menu_setup($args); 

  my $id  = $args->{'dbid'};
  my $r   = $args->{'r'};
  my $s   = $args->{'start'};
  my $e   = $args->{'end'};
  my $y   = $args->{'click_y'}/$args->{'height'};
  my $y_scale = $args->{'y_scale'};
  my $renderer = $args->{'renderer'};

  # Round fudge to 1sf
  my $mult = "1"."0"x(length(int $fudge)-1);
  $fudge = int(($fudge/$mult)+0.5)*$mult;  
  my $mid = ($s+$e)/2;
  $s = int($mid - $fudge/2);
  $e = int($mid + $fudge/2);
 
  # See what we can find
  my $rest = EnsEMBL::Web::REST->new($self->hub);
  my ($data,$error) = $rest->fetch_via_ini($args->{'species'},'gtex',{
    stableid => $args->{'g'},
    tissue => $args->{'tissue'}
  });
  if($error || !defined $data) {
    $self->caption("REST service failed");
    $self->add_entry({  type => "Overview",
                       label => "Could not retrieve data from server"});
    return;
  }

  # Which match?
  my @hits;
  my $statistic = "p-value";
  $statistic= "beta" if $renderer eq 'beta';
  foreach my $f (@$data) {
    next unless $f->{'statistic'} eq $statistic;
    next if $f->{'seq_region_end'} < $s;
    next if $f->{'seq_region_start'} > $e;
    push @hits,$f;
  }

  if(!@hits) {
    $self->caption("No hits nearby");
    $self->add_entry({ type => "Summary",
                       label => "No hits nearby" });
    return;
  }

  # Summarize
  $self->caption("Found ".(scalar @hits)." hits nearby");
  my $i = 0;
  my $last_val;
  my $colourmap = $self->hub->colourmap;
  my $var_styles = $self->hub->species_defs->colour('variation');
  @hits = sort { abs($a->{'value'}) <=> abs($b->{'value'}) } @hits;
  @hits = reverse @hits if $renderer eq 'beta';
  my $fmt = "p < %s";
  $fmt = "%s";
  my $more_fmt = "p >= %s";
  $more_fmt = "abs < %s" if $renderer eq 'beta';
  foreach my $f (@hits) {
    my $value;
    if($renderer eq 'beta') {
      $value = sprintf("%3.3f",$f->{'value'});
    } else {
      my $exp = int(log($f->{'value'})/log(10))-1;
      my $mant = $f->{'value'}/10**$exp;
      $value = sprintf("%2.2f",$mant);
      $value .= " x 10^$exp" if $exp;
    }

    my $url = $self->hub->url({
      type => 'Variation',
      action => 'Mappings',
      v => $f->{'snp'},
    });

    my $conseq = $f->{'display_consequence'};
    my $conseq_colour = $colourmap->hex_by_name(
      $var_styles->{$conseq}{'default'}
    );
    my $html = qq(
      <span class="colour ht _ht" title="$conseq"
            style="background-color:$conseq_colour; min-width: 0.5em; display: inline-block;">&nbsp;</span>
      <a href="$url">$f->{'snp'}</a>
    );
    $self->add_entry({
      label_html => $html,
      type => sprintf($fmt,$value),
    });
    $last_val = $value;
    last if $i++ > 18;
  }

  my $more = scalar(@hits)-$i;
  if($more) {
    $self->add_entry({
      label => "$more more hits",
      type => sprintf($more_fmt,$last_val),
    });
  }
}

sub _menu_setup {
  my ($self, $args) = @_;

  my $id  = $args->{'dbid'};
  my $r   = $args->{'r'};
  my $s   = $args->{'start'};
  my $e   = $args->{'end'};
 
  # Widen to include a few pixels around
  my $fudge = 16/$args->{'scalex'};
  $fudge = 0 if $fudge < 1;
  
  my $sa = $self->hub->database('core')->get_SliceAdaptor;
  my $slice = $sa->fetch_by_toplevel_location($r)->seq_region_Slice;
  
  return ($fudge, $slice);
}

sub content {
  my ($self) = @_;

  my $hub     = $self->hub;
  my $r       = $hub->param('r');
  my $s       = $hub->param('click_start');
  my $e       = $hub->param('click_end');
  my $scalex  = $hub->param('scalex');
  my $renderer = $hub->param('renderer');

  $r =~ s/:.*$/:$s-$e/;
  # We need to defeat js-added fuzz to see if it was an on-target click.
  if($e - $s + 1 < 2 * $scalex && $s != $e) { # range within 1px, assume click.
    # fuzz added is symmetric
    $s = ($s + $e - 1) / 2;
    $e = $s + 1;
  }

  my @params = qw(r strand scalex width tissue g click_y height y_scale);
  my %args;

  foreach (@params) {
    $args{$_} = $hub->param($_) if defined($hub->param($_));
  }

  $args{'species'} = $hub->param('sp');
  $args{'renderer'} = $renderer;
  $args{'start'}  = $s;
  $args{'end'}    = $e;

  $self->summary_zmenu(\%args);
}

1;
