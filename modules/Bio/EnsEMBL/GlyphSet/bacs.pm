package Bio::EnsEMBL::GlyphSet::bacs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "BACs"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MiscFeatures( 'bacs' );
}

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( 'bacs', 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption'   => "BAC: @{[$f->get_scalar_attribute('name')]}",
        '01:Status: @{[$f->get_scalar_attribute('status')]}" => ''
    };
    foreach( $f->get_scalar_attribute('embl_accs') ) {
        $zmenu->{"02:bacend: $_"} = $self->ID_URL( 'EMBL', $_);
    }
    return $zmenu;
}

sub colour {
    my ($self, $f) = @_;
    my $state = $f->get_scalar_attribute('status');
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"},
           $f->length > $self->{'config'}->get( "bacs", 'outline_threshold' ) ? 'border' : '';
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->get_scalar_attribute('name'),'overlaid');
}

1;

