package Bio::EnsEMBL::GlyphSet::sequence;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

sub fixed { return 1;}

sub my_label { return "Sequence"; }

sub features {
    my ($self) = @_;
    my $start = 0;
    my $seq = uc($self->{'container'}->seq);
    my $strand = $self->strand;
    if($strand == -1 ) { $seq=~tr/ACGT/TGCA/; }
    my @features = map { 
       Bio::EnsEMBL::Feature->new(
	   -start   => ++$start,
	   -end     => $start,
           -strand  => $strand,
           -seqname => $_,
       )
    } split //, $seq;
    return \@features;
}

sub colour {
    my ($self, $f) = @_;
    return $self->{'colours'}{$f->seqname} || $self->{'feature_colour'},
           $self->{'label_colour'};

}
sub href  { return undef; }
sub zmenu { return undef; }

sub image_label { my ($self, $f ) = @_; return $f->seqname(),'overlaid'; }

1;
