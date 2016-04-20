package EnsEMBL::Web::Query::GlyphSet::Marker;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 15;

sub href {
  my ($self,$f,$args) = @_;

  return {
    species => $args->{'species'},
    type => 'Marker',
    m => $f->{'drawing_id'}
  };
}

sub colour_key { return lc $_[1]->marker->type; }

sub precache {
  return {
    markers => {
      loop => 'genome',
      args => {
        species => "Homo_sapiens"
      }
    }
  }
}

sub fixup {
  my ($self) = @_;

  $self->fixup_slice('slice','species',1000000);
  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_unique('_unique');
  $self->fixup_href('href');
  $self->fixup_colour('colour','magenta');
  $self->fixup_colour('label_colour','magenta');
  $self->SUPER::fixup();
}

sub get {
  my ($self,$args) = @_;

  my $slice = $args->{'slice'};
  my $length = $slice->length;
  my $data = [];

  # Get them
  my @features;
  if($args->{'text_export'}) {
    @features = @{$slice->get_all_MarkerFeatures};
  } else {
    my $map_weight = 2;
    @features = @{$slice->get_all_MarkerFeatures($args->{'logic_name'},
                                                 $args->{'priority'},
                                                 $map_weight)};

    # Force add marker with our id if missed out above
    if($args->{'marker_id'} and
      !grep {$_->display_id eq $args->{'marker_id'}} @features) {
      my $m = $slice->get_MarkerFeatures_by_Name($args->{'marker_id'});
      push @features,@$m;
    }
  }

  # Determine drawing_id for each marker
  foreach my $f (@features) {
    my $ms  = $f->marker->display_MarkerSynonym;
    my $id  = $ms ? $ms->name : '';
      ($id) = grep $_ ne '-', map $_->name, @{$f->marker->get_all_MarkerSynonyms || []} if $id eq '-' || $id eq '';
    
    $f->{'drawing_id'} = $id;
  }
 
  # Build output 
  foreach my $f (sort { $a->seq_region_start <=> $b->seq_region_start } @features) {  
    my $id = $f->{'drawing_id'};
    my $feature_colour = $self->colour_key($f);
    push @$data, {
                  '_unique'       => join(':',$id,$f->start,$f->end),
                  'start'         => $f->start,
                  'end'           => $f->end,
                  'colour'        => $feature_colour,
                  'label'         => $id,
                  'label_colour'  => $feature_colour, 
                  'href'          => $self->href($f,$args),
                  };  
  }
  return $data;
}

1;
