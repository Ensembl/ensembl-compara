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

    my $res = [];
    my $projection = $self->{'container'}->project('chromosome', $self->species_defs->ALTERNATIVE_ASSEMBLY);

    foreach my $seg (@{ $projection }) {
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
