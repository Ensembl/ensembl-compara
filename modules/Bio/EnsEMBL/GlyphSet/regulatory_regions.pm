package Bio::EnsEMBL::GlyphSet::regulatory_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Reg. features"; }

sub my_description { return "Reg. features"; }

# This for 
sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    my $slice = $self->{'container'};
    my $features =  $slice->adaptor->db->get_RegulatoryFeatureAdaptor->fetch_all_by_Slice_constraint( $slice );  # $logic name is second param
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

    my $return = {
        'caption'                    => 'regulatory_regions',
        "06:bp: $start-$end"         => "contigview?c=$seq_region:$start;w=1000",
    };

    # Feature
    my $analysis = $f->analysis->logic_name;
    my $feature_link;
    if ($analysis =~ /cisred/i ) {
      $name =~/\w+(\d+)/;
      $feature_link = "http://www.cisred.org/human2/siteseq?fid=$1";
    }
    $return->{"01:Feature: $name"} = $feature_link;

    # Factor
    if (my $factor = $f->factor->name ) {
      $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor";
    }
    else {
      $return->{"02:Factor: Unknown"} = "";
    }

    # Associated xxx
    foreach ( @{ $f->regulated_genes } ) {
      my $stable_id = $_->stable_id;
      if (length($stable_id) >18) { $stable_id = "<br />$stable_id"; }
      $return->{"03:Associated gene: $stable_id"} = "geneview?gene=$stable_id";

      if ($analysis) {
	my $cisred = $analysis =~/cisred/i ? "http://www.cisred.org/human2/gene_view?ensembl_id=$stable_id" : "";
	$return->{"04:Analysis: $analysis"} = "$cisred";
      }
    }

    foreach (@{ $f->regulated_transcripts  }) {
      my $stable_id = $_->stable_id;
      if (length($stable_id) >15) { $stable_id = "<br />$stable_id"; }
      $return->{"05:Associated transcript: $stable_id"} = "transview?transcript=$stable_id";
    }

    return $return;
}



# Features associated with the same factor should be in the same colour
# Choose a colour from the pool

sub colour {
  my ($self, $f) = @_;
  my $name = $f->factor->name;
  unless ( exists $self->{'config'}{'pool'} ) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  $self->{'config'}{'_factor_colours'}||={};
  my $return = $self->{'config'}{'_factor_colours'}{ "$name" };

  unless( $return ) {
    $return = $self->{'config'}{'_factor_colours'}{"$name"} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)  %@{$self->{'config'}{'pool'}} ];
  } 
  return $return, $return;
}



1;
