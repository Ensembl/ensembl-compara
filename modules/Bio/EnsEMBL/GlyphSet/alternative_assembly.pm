### Needs go be re-worked to be generic
### need to speak to Steve (st3) over this one

package Bio::EnsEMBL::GlyphSet::alternative_assembly;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::SimpleFeature;

sub features {
    my $self = shift;
    my $db  = $self->my_config( 'assembly_db'   );
    my $key = $self->my_config( 'assembly_name' );
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
    my ($location) = split /\./ ,  $f->display_id;
    my $species = $self->species;
    return "http://vega.sanger.ac.uk/$species/contigview?l=$location";
}

sub feature_label {
    my ($self, $f ) = @_;
    return ($f->display_id, 'overlaid');
}

sub title {
    my ($self, $f ) = @_;
    my $title = $f->display_id.'; Assembly: Vega';
}

1;
