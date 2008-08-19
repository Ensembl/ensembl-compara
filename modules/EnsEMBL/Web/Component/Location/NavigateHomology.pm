package EnsEMBL::Web::Component::Location::NavigateHomology;

### Module to replace part of the former SyntenyView, in this case 
### the 'navigate homology' links

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $chr     = $object->seq_region_name; 
  my $html;

  my $sliceAdaptor = $object->get_adaptor('get_SliceAdaptor');
  my $max_index = 15;
  my $max_minus = -15;
  my $offset = $object->seq_region_end;

  my $start = $object->seq_region_start || 1;
  my $end   = $object->seq_region_end || $object->chromosome->end;
  my $upstream    = $sliceAdaptor->fetch_by_region('chromosome', $chr, 1, $object->seq_region_start - 1 );
  my $downstream  = $sliceAdaptor->fetch_by_region('chromosome', $chr, $object->seq_region_end + 1, $object->chromosome->end );

  my @up_genes    = @{$object->get_synteny_local_genes($upstream)};
  my @down_genes  = @{$object->get_synteny_local_genes($downstream)};

  $html .= qq(
<table class="autocenter">
<tr>
<th class="center" style="padding:0px 2em" rowspan="2">Navigate homology:</th>
<th class="center" style="padding:0px 2em">&laquo;&nbsp;Upstream</th>
<th class="center" style="padding:0px 2em">Downstream&nbsp;&raquo;</th></tr>
<tr><td class="center">
);

  my $up_count = @up_genes;
  if ($up_count) {
    my @up_sample;
    for (my $i = -1; $i >= $max_minus; $i--) {
      next if !$up_genes[$i];
      push @up_sample, $up_genes[$i];
    }
    $up_count = @up_sample;
    my $up_start    = @up_sample ? $up_sample[0]->start + $offset : 0;
    my $up_end      = @up_sample ? $up_sample[-1]->end + $offset : 0;

    $html .= sprintf(qq(
<a href="/%s/Location/Synteny?otherspecies=%s;r=%s:%s-%s">Previous %s genes</a>),
  $object->species, $object->param('otherspecies'), $chr, $up_start, $up_end, $up_count,
    );
  }
  else {
    $html .= 'No upstream homologues';
  }

  $html .= '</td><td class="center">';

  my $down_count = @down_genes;
  if ($down_count) {
    my @down_sample;
    for (my $j = 0; $j < $max_index; $j++) {
      next if !$down_genes[$j];
      push @down_sample, $down_genes[$j];
    }
    $down_count = @down_sample;
    my $down_start  = @down_sample ? $down_sample[0]->start + $offset : 0;
    $down_start = -$down_start if $down_start < 0;
    my $down_end    = @down_sample ? $down_sample[-1]->end + $offset : 0;

    $html .= sprintf(qq(
<a href="/%s/Location/Synteny?otherspecies=%s;r=%s:%s-%s">Next %s genes</a> ),
  $object->species, $object->param('otherspecies'), $chr, $down_start, $down_end, $down_count,
    );
  }
  else {
    $html .= 'No downstream homologues';
  }
  $html .= qq(</td></tr>
</table>
);

  return '<div class="center">'.$html.'</div>';
}

1;
