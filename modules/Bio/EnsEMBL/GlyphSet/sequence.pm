package Bio::EnsEMBL::GlyphSet::sequence;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SeqFeature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

sub my_label { return "Sequence"; }

sub features {
    my ($self) = @_;
    my $start = 0;
    my $seq = $self->{'container'}->seq;
    my $strand = $self->strand;
    if($strand == -1 ) { $seq=~tr/ACGT/TGCA/; }
 #   &eprof_start('mf');
 #   $self->{'mapfrags'} = $self->{'container'}->get_all_MapFrags( 'assembly' );
 #   &eprof_end('mf');
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
#    foreach(@{$self->{'mapfrags'}}) {
#        return sprintf(
#            #'http://wwwdev.sanger.ac.uk/cgi-bin/tracefetch/viewtrace?species=%s&contig=%s&fo#cus=%s&bori=%s&cori=%s',
#             @{[$self->{container}{_config_file_name_}]}, $_->name, 
#             $_->orientation > 0 ? ( $f->start-$_->start+1 ) : ( #$_->end-$f->start+1 ) ,
#             $self->strand, $_->orientation
#        ) if $_->start <= $f->start && $f->start <= $_->end;
#    }
    return undef;
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
