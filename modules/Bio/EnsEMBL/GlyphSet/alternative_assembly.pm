package Bio::EnsEMBL::GlyphSet::alternative_assembly;

use strict;

use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SimpleFeature;
use EnsEMBL::Web::ExtURL;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {
    my $self = shift;
    return $self->my_config('other') . " assembly";
}

sub features {
  my $self = shift;

    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
  my $reg = "Bio::EnsEMBL::Registry";
  my $species = $self->{'config'}->{'species'};
  my $orig_group;
  if( my $vega_dnadb = $reg->get_DNAAdaptor($species, "vega") ) {
    $orig_group = $vega_dnadb->group;
  }
  $reg->add_DNAAdaptor($species, "vega", $species, "vega");

    # get a Vega slice to do the projection
  my $vega_slice = $self->{'container'};
  if( my $vega_sa = Bio::EnsEMBL::Registry->get_adaptor($species, "vega", "Slice") ) {
    $vega_slice = $vega_sa->fetch_by_region(
      ( map { $self->{'container'}->$_ } qw( coord_system_name seq_region_name start end strand) ),
      $self->{'container'}->coord_system->version
    );
  }

  my $res = [];
  my $projection = $vega_slice->project('chromosome', $self->species_defs->ALTERNATIVE_ASSEMBLY);

  foreach my $seg ( @$projection ) {
    my $slice = $seg->to_Slice;
    my $location = $slice->seq_region_name.":".$slice->start."-".$slice->end;
    my $f = Bio::EnsEMBL::SimpleFeature->new(
      -display_label  => $location,
      -start          => $seg->from_start,
      -end            => $seg->from_end,
      -strand         => $slice->strand,
    );
    push @$res, $f;
  }

  # set dnadb back to what it was originally
  $reg->add_DNAAdaptor($species, "vega", $species, $orig_group) if ($orig_group);
    
  return $res;
}

sub href {
    my ($self, $f) = @_;
    my ($cloneid) = split /\./ ,  $f->display_id;
    my $exturl = new EnsEMBL::Web::ExtURL(
        $self->species_defs->name,
        $self->species_defs
    );
    return $exturl->get_url(uc($self->my_config('other')))."@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?l=".$f->display_id;
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->display_id, 'overlaid');
}

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption' => $f->display_id,
        '03:Assembly: '.$self->species_defs->ALTERNATIVE_ASSEMBLY => '',
        '04:Jump to '.$self->my_config('other') => $self->href($f),
    };
    return $zmenu;
}

1;
