package Bio::EnsEMBL::GlyphSet::Vglovarsnps;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'}; 
    my $chr      = $self->{'container'}->{'chr'};
    my $snps     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'glovar_snp' );
    return unless $snps->size();

    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'SNPs',
        'font'      => 'Small',
        'colour'    => $Config->get('Vglovarsnps','col'),
        'absolutey' => 1,
    });
        
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config = $self->{'config'};
    my $chr      = $self->{'container'}->{'chr'};
    my $snps     = $self->{'container'}->{'da'}->get_density_per_chromosome_type( $chr,'glovar_snp' );
    return unless $snps->size();
    
    my $snps_col = $Config->get( 'Vglovarsnps','col' );
    
    $snps->scale_to_fit( $Config->get( 'Vglovarsnps', 'width' ) );
    $snps->stretch(0);
    my @snps = $snps->get_binvalues();

    foreach (@snps){
        my $g_x = new Sanger::Graphics::Glyph::Rect({
            'x'      => $_->{'chromosomestart'},
            'y'      => 0,
            'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
            'height' => $_->{'scaledvalue'},
            'bordercolour' => $snps_col,
            'absolutey' => 1,
            'href'   => "/@{[$self->{container}{_config_file_name_}]}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
        });
        $self->push($g_x);
    }
}

1;
