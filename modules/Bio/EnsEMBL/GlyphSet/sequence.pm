package Bio::EnsEMBL::GlyphSet::sequence;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SeqFeature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Sequence"; }

sub features {
    my ($self) = @_;
    my $start = 0;
    my $seq = $self->{'container'}->seq;
    my $strand = $self->strand;
    if($strand == -1 ) { $seq=~tr/ACGT/TGCA/; }
    $self->{'mapfrags'} = $self->{'container'}->get_all_MapFrags( 'assembly' );
    my @features = map { 
       Bio::EnsEMBL::SeqFeature->new(
	   -start => ++$start,
	   -end   => $start,
           -seqname => $_,
           -strand  => $strand
       )
    } split //, $seq;
    return \@features;
}

sub colour {
    my ($self, $f) = @_;
    return $self->{'colours'}{$f->seqname} || $self->{'feature_colour'},
           $self->{'label_colour'};

}
sub href {
    my( $self,$f) = @_;
    if(@{$self->{'mapfrags'}}) { 
        foreach(@{$self->{'mapfrags'}}) {
	  warn("MF: ".$_->start);
        }
        warn( "SQ: ". $f->start );
    }
}
sub zmenu {
    my ($self, $f ) = @_;
    return undef;
}

sub image_label {
    my ($self, $f ) = @_;
    return $f->seqname(),'overlaid';
}

1;
