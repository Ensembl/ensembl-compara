package Bio::EnsEMBL::GlyphSet::codonseq;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SeqFeature;
use Bio::Seq;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Amino acids"; }

sub features {
    my ($self) = @_;
    my $seq = $self->{'container'}->subseq(-2,$self->{'container'}->length+4);
    my $strand = $self->strand;
    my @features;
    foreach my $phase ( 0..2 ) {
        my $string = substr( $seq, $phase , 3 * int ( (length($seq) - $phase)/3 ) );
        if($strand == -1 ) {
           $string = reverse $string;
           $string =~tr/AGCT/TCGA/ ;
        }
        my $bioseq = new Bio::Seq( -seq => $string, -moltype => 'dna' );
        $string = $bioseq->translate->seq;
        $string = reverse $string if $strand == -1;
        my $start = $phase - 5;
        push @features, map {
            Bio::EnsEMBL::SeqFeature->new(
	       -start => $start+=3,
	       -end   => $start+2,
               -seqname => $_,
               -strand  => $strand
           )
        } split //, $string;
    }
    return \@features;
}

sub colour {
    my ($self, $f) = @_;
    return $self->{'colours'}{$f->seqname} || $self->{'feature_colour'},
           $self->{'label_colour'};

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
