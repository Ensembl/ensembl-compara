package Bio::EnsEMBL::GlyphSet::haplotype;
use strict;
use EnsWeb;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Haplotypes"; }

sub features {
    my ($self) = @_;
    #print STDERR "Getting adaptor!!!\n";
    unless( $self->{'config'}->{'_hap_adaptor'} ) {
        my $db_details = EnsWeb::species_defs->databases;
        #print STDERR "DB: ".$db_details->{'ENSEMBL_HAPLOTYPE'}{'NAME'}."\n";
        #print STDERR "UN: ".$db_details->{'ENSEMBL_HAPLOTYPE'}{'USER'}."\n";
        #print STDERR "PW: ".$db_details->{'ENSEMBL_HAPLOTYPE'}{'PASS'}."\n";
        #print STDERR "HT: ".$db_details->{'ENSEMBL_HAPLOTYPE'}{'HOST'}."\n";
        #print STDERR "PT: ".$db_details->{'ENSEMBL_HAPLOTYPE'}{'PORT'}."\n";
        my $dbad = Bio::EnsEMBL::DBSQL::DBAdaptor->new( 
            -dbname => $db_details->{'ENSEMBL_HAPLOTYPE'}{'NAME'},
            -user   => $db_details->{'ENSEMBL_HAPLOTYPE'}{'USER'},
            -pass   => $db_details->{'ENSEMBL_HAPLOTYPE'}{'PASS'},
            -host   => $db_details->{'ENSEMBL_HAPLOTYPE'}{'HOST'},
            -port   => $db_details->{'ENSEMBL_HAPLOTYPE'}{'PORT'},
        );
        $self->{'config'}->{'_hap_adaptor'} = Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor->new( $dbad );
    }
    #print STDERR "Getting data!!!\n";
    return $self->{'container'}->get_Haplotypes_start_end(
        $self->{'config'}->{'_hap_adaptor'}
    );
}

sub tag {
    my( $self, $f ) = @_;
    my $col = $self->{'config'}->get($self->check(), 'col');
    return { 'style'  => 'right-snp',
             'colour' => $col },
           { 'style'  => 'left-snp',
             'colour' => $col };
}

sub colour {
    my( $self, $f ) = @_;
    return $self->{'config'}->get($self->check(), 'col'), $self->{'config'}->get($self->check(), 'lab'), 'line'; 
}
sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/haploview?haplotype=".$f->id;
}
sub zmenu {
    my ($self, $f ) = @_;
    return { 
        'caption'        => $f->id,
	    'Haplotype info' => $self->href($f)
    };
}

1;
