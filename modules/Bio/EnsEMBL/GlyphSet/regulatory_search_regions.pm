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

    if  ( my $type = lc($f->ensembl_object_type) ) {
      my $id = $f->ensembl_object()->stable_id();
      my $link;
      if ($type eq 'translation') {
	$link = "protview";
	$type = "peptide";
      }
      elsif ($type eq 'transcript') {
	$link = "transview";
      }
      else {
	$link = "geneview";

#	$return->{"04: [CisRed]"} = "$cisred" if $analysis =~/cisred/i;
      }
      if ($analysis) {
	my $cisred = $analysis =~/cisred/i ? "http://www.cisred.org/human2/gene_view?ensembl_id=$id" : "";
	$return->{"02:Analysis: $analysis"} = "$cisred";
      }
      $return->{"04:Associated $type: $id"} = "$link?$type=$id";
    }
    return $return;
}

# Search regions with similar analyses should be in the same colour
# Choose a colour from the pool

sub colour2 {
  my ($self, $f) = @_;
  my $name = $f->analysis->logic_name;

  return $self->{'colours'}{$name}[0],
    $self->{'colours'}{$name}[2],
      $f->start > $f->end ? 'invisible' : '';
#}
###

  unless ( exists $self->{'config'}{'pool'} ) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  $self->{'config'}{'_regulatory_search_region_colours'}||={};
  my $return = $self->{'config'}{'_regulatory_search_region_colours'}{ "$name" };
  unless( $return ) {
    $return = $self->{'config'}{'_regulatory_search_region_colours'}{"$name"} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)  %@{$self->{'config'}{'pool'}} ];
  }
  return $return, $return;
}


1;
