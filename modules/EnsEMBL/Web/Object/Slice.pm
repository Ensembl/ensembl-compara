package EnsEMBL::Web::Object::Slice;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub snp_display {
  my $self = shift; 
  my $value = $self->param('snp_display');
  my $SNPS = [];
  if( $value eq 'snp' ){
    my $slice = $self->Obj();
    eval {
      if( $self->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
        $SNPS = $self->database('glovar');
        return $slice->get_all_ExternalFeatures('GlovarSNP');
      } elsif( $self->species_defs->databases->{'ENSEMBL_VARIATION'} ) {
        $SNPS = $slice->get_all_VariationFeatures;
      }
    };
  }
  return $SNPS;
}

sub exon_display {
  my $self = shift;
  my $exontype = $self->param('exon_display');
  my @exons;
  my( $s, $e ) = ( $self->Obj->start, $self->Obj->end );
  if( $exontype eq 'vega' or $exontype eq 'est' ){
    @exons = ( grep { $_->seq_region_start <= $e && $_->seq_region_end   >= $s }
               map  { @{$_->get_all_Exons } }
               @{ $self->Obj->get_all_Genes('',$exontype) } );
  } elsif( $exontype eq 'prediction' ){
    @exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
               map { @{$_->get_all_Exons } }
               @{$self->Obj->get_all_PredictionTranscripts } );
  } else {
    @exons = @{$self->Obj->get_all_Exons};
  }
  my $ori = $self->param('exon_ori');
  if( $ori eq 'fwd' ) {
    @exons = grep{$_->seq_region_strand > 0} @exons; # Only fwd exons
  } elsif( $ori eq 'rev' ){
    @exons = grep{$_->seq_region_strand < 0} @exons; # Only rev exons
  }
  return \@exons;
}

sub highlight_display {
  my $self = shift;
  if( @_ ){
    my @features = @{$_[0] || []}; # Validate arg list
    map{$_->isa('Bio::EnsEMBL::Feature') or die( "$_ is not a Bio::EnsEMBL::Feature" ) } @features;
    $self->{_highlighted_features} = [@features];
  }
  return( $self->{_highlighted_features} || [] );
}

sub line_numbering {
  my $self  = shift;
  my $linenums = $self->param('line_numbering');
  if( $linenums eq 'sequence' ){ #Relative to sequence
    return( 1, $self->Obj->length );
  } elsif( $linenums eq 'slice' ){ #Relative to slice. May need to invert
    return $self->Obj->strand > 0 ? ( $self->Obj->start, $self->Obj->end ) : ( $self->Obj->end, $self->Obj->start );
  }
  return();
}

1;
