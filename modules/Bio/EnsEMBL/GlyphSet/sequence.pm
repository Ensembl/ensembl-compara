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
sub zmenu {
    my ($self, $f ) = @_;
    return undef;
}

sub image_label {
    my ($self, $f ) = @_;
    return $f->seqname(),'overlaid';
}

1;
