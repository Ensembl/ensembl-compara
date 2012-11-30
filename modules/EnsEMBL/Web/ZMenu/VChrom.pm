package EnsEMBL::Web::ZMenu::VChrom;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

use List::Util qw(min max);

sub _half_way {
  my ($self,$chr,$size) = @_;

  my $sa = $self->hub->get_adaptor('get_SliceAdaptor');
  my $slice = $sa->fetch_by_region(undef,$chr);
  return (1,1) unless($slice);
  return (max(0,$slice->length/2-$size),
          min($slice->length,$slice->length/2+$size));
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $chr = $hub->param('chr');
  my $summary_url = $hub->url({'type' => 'Location',
                                'action' => 'Chromosome',
                                '__clear' => 1, 
                                'r' => $chr});   
  # Half way along, maybe?
  my ($start,$end) = $self->_half_way($chr,50000);
  my $r = sprintf("%s:%d-%d",$chr,$start,$end);
  my $detail_url = $hub->url({ type => 'Location',
                               action => 'View',
                               r => $r });

  $self->caption("Chromosome $chr");
  $self->add_entry({
    type  => 'Summary',
    label => "Chromosome $chr", 
    link => $summary_url,
    order => 1,
  });
  $self->add_entry({
    type => "Example",
    label => "Example region on $chr",
    link => $detail_url,
    order => 2,
  });
}

1;
