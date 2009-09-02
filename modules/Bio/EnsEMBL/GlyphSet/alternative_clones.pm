package Bio::EnsEMBL::GlyphSet::alternative_clones;

#retrieve clones from e! or Vega using DAS and compare with those used

use strict;

use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use Bio::EnsEMBL::ExternalData::DAS::Source;
use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {
  my $self = shift;
  return $self->my_config('other') . " clones";
}

sub features {
  my $self       = shift;
  my $slice      = $self->{'container'};
  my $das_source =  $self->my_config('das_source');
  my $conf       = $self->species_defs->$das_source;
  my $res;
  return unless $conf;
  my $source = Bio::EnsEMBL::ExternalData::DAS::Source->new(
    -DSN           => $conf->{'dsn'},
    -URL           => $conf->{'url'},
    -LABEL         => $conf->{'label'},
    -COORDS        => [ Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new( -NAME => 'clone') ],
  );
  my $c = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new([ $source ]);

  # retrieve from each clone on the slice
  my $projection_type = 'clone';
  foreach my $segment (@{ $slice->project($projection_type) }){
    my $clone = $segment->to_Slice->seq_region_name;
    my ($clone_name,$clone_version) = split(/\./, $clone);
#    warn "looking for $ clone_name,$clone_version";
#    warn "looking at this part of the clone ",$segment->to_Slice->start;
    my $struct = $c->fetch_Features( $segment->to_Slice );

    foreach my $logic_name ( keys %{ $struct } ) {
      foreach my $proj_segment ( keys %{ $struct->{$logic_name}{'features'} } ) {
	foreach my $proj (@{$struct->{$logic_name}{'features'}{$proj_segment}{'objects'}}) {
	  if ($proj->type_label eq $projection_type) {
	    my ($proj_name, $proj_version) = split(/\./, $proj->display_id);
#	    warn "  found $proj_name,$proj_version";
#	    warn "from start = ",$proj->slice->start;
	    if ($clone_name eq $proj_name) {
	      my $f = Bio::EnsEMBL::SimpleFeature->new(
		-display_label  => $proj->display_id.':'.$proj->slice->start.'-'.$proj->slice->end,
		-start          => $segment->from_start,
		-end            => $segment->from_end,
		-strand         => $segment->to_Slice->strand,
	      );
	      # is the clone found by DAS newer/older/same as the source clone ?
	      if ($proj_version > $clone_version) {
		$f->{'status'} = 'newer_clone';
	      } elsif ($proj_version == $clone_version){
		$f->{'status'} = 'same_clone';
	      } else {
		$f->{'status'} = 'older_clone';
	      }
	      push(@{$res}, $f);
	    }
	  }
	}
      }
    }
  }
  return $res;
}

sub colour_key {
  my ($self, $f) = @_;
  return ($f->{'status'});
}

sub href {
  my ($self, $f) = @_;
  my ($clone_id) = split /\./ ,  $f->display_id;
  my $status = $f->{'status'};
  my ($loc) = split (/\./, $f->display_id);
  $loc = $f->display_id;
  my $url = $self->_url({
    'r'      => $loc,
    'status' => $f->{'status'},
  });
  return $url;
}

sub feature_label {
  my ($self, $f ) = @_;
  return ($f->display_id, 'overlaid');
}

1;
