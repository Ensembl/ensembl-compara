package Bio::EnsEMBL::GlyphSet::regulatory_search_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Search regions"; }

sub my_description { return "Search regions"; }

# This for 
sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    my $slice = $self->{'container'};
    my $features =  $slice->adaptor->db->get_RegulatorySearchRegionAdaptor()->fetch_all_by_Slice( $slice );  # $logic name is second param
    return $features;
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;
    my $name = $f->name();
    if (length($name) >24) { $name = "<br />$name"; }
    my $seq_region = $f->slice->seq_region_name;
    my ($start,$end) = $self->slice2sr( $f->start, $f->end );
    my $analysis = $f->analysis->logic_name;
    my $return = {
        'caption'                    => 'regulatory_search_regions',
        "01:bp: $start-$end"         => "contigview?c=$seq_region:$start;w=1000",
    };
    $return->{"02:Analysis: $analysis"} = "" if $analysis;

    if  ( my $type = lc($f->ensembl_object_type) ) {
      my $id = $f->ensembl_object_id;
      $return->{"04:Regulates $type: $id"} = "$type"."view?$type=$id";
    }
    return $return;
}



1;
