package Bio::EnsEMBL::GlyphSet::snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use ExtURL;

use Bump;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'SNP',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my $highlights    = $self->highlights();
    my $cmap          = new ColourMap;
    my $snp_col       = $Config->get('snp','col');
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type          = $Config->get('gene','src');

    my @xf            = $VirtualContig->get_all_SNPFeatures( $self->glob_bp() );

    my $ext_url = ExtURL->new;
    ## need to sort external features into SNPs or traces and treat them differently
    my @snp = grep $_->isa("Bio::EnsEMBL::ExternalData::Variation"), @xf;

    my $rect;
    my $colour;
    foreach my $s (@snp) {
        my $x = $s->start();
        my $id = $s->id();
        my $snpglyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $x,
            'y'         => 0,
            'width'     => 0,
            'height'    => $h,
            'colour'    => $snp_col,
            'absolutey' => 1,
            'href'      => "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=$id",
            'zmenu'     => { 
                'caption'           => "SNP: $id",
                'SNP properties'    => "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=$id",
                'dbSNP data'        => $ext_url->get_url('SNP',$id),
            },
        });
        
        foreach ($s->each_DBLink()){
            next if $_->database() =~ /JCM/;
            my $db  = $_->database() . " data";
            my $pid = $_->primary_id();
            
            if ($db =~ /TSC/){
                $snpglyph->{'zmenu'}->{$db} =$ext_url->get_url('TSC',$pid); 
            } elsif ($db =~ /CGAP/){
                $snpglyph->{'zmenu'}->{$db} =$ext_url->get_url('CGAP-GAI',$pid); 
            } elsif ($db =~ /HGBASE/){
                $snpglyph->{'zmenu'}->{$db} =$ext_url->get_url('HGBASE',$pid);
            }
        }    
        $self->push($snpglyph);
    }
}

1;
