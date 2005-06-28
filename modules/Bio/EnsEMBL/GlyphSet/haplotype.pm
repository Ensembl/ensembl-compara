package Bio::EnsEMBL::GlyphSet::haplotype;
use strict;

use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Haplotypes"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_Haplotypes;
}

sub tag {
    my( $self, $f ) = @_;
    my $col = $self->{'config'}->get($self->check(), 'col');
    my $vc_start = $self->{'container'}->start()-1;
    my @tags = ();
    my %snps = $f->fetchSNPs( ); # returns a hash -> name => location
    foreach my $snp ( keys %snps ) {
        push @tags, { 'style' => 'snp', 'start' => $snps{$snp} - $vc_start, colour => $col };
    }
    return @tags;
}

sub colour {
    my( $self, $f ) = @_;
    return 
$self->{'config'}->get($self->check(), 'col'), $self->{'config'}->get($self->check(), 'lab'), 'line'; 
}

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/haploview?haplotype=".$f->id;
}
sub zmenu {
    my ($self, $f ) = @_;
    return { 
        'caption'        => $f->id,
	    'Haplotype info' => $self->href($f)
    };
}

1;
