package Bio::EnsEMBL::GlyphSet::snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "SNP"; }

sub features {
    my ($self) = @_;
    return grep { $_->isa("Bio::EnsEMBL::ExternalData::Variation") }
        $self->{'container'}->get_all_SNPFeatures( $self->glob_bp() );
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=".$f->id;
}

sub zmenu {
    my ($self, $f ) = @_;
    my $ext_url = $self->{'config'}->{'ext_url'};
    
    my %zmenu = ( 
        'caption'           => "SNP: ".$f->id,
        '01:SNP properties'    => $self->href( $f),
        '02:dbSNP data'        => $ext_url->get_url('SNP',$f->id),
    );
    foreach ($f->each_DBLink()){
        next if $_->database() =~ /JCM/;
        my $db  = $_->database() . " data";
        my $pid = $_->primary_id();
            
        if ($db =~ /TSC/){
            $zmenu{"03:$db"} =$ext_url->get_url( 'TSC',      $pid ); 
        } elsif ($db =~ /CGAP/) {
            $zmenu{"04:$db"} =$ext_url->get_url( 'CGAP-GAI', $pid );
        } elsif ($db =~ /HGBASE/) {
            $zmenu{"05:$db"} =$ext_url->get_url( 'HGBASE',   $pid );
        }
    }    
    return \%zmenu;
}
1;
