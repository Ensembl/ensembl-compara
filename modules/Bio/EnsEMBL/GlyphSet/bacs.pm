package Bio::EnsEMBL::GlyphSet::bacs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "BACs"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MapFrags( 'bacs' );
}

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( 'bacs', 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption'   => "BAC: ".$f->name,
        '01:Status: '.$f->status => ''
    };
    foreach( $f->embl_accs ) {
        $zmenu->{"02:bacend: $_"} = $self->ID_URL( 'EMBL', $_);
    }
    return $zmenu;
}

sub colour {
    my ($self, $f) = @_;
    my $state = $f->status;
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"},
           $f->length > $self->{'config'}->get( "bacs", 'outline_threshold' ) ? 'border' : '';
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->name,'overlaid');
}

1;

