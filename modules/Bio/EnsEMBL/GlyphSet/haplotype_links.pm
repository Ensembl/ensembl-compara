package Bio::EnsEMBL::GlyphSet::haplotype_links;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Haplotype blocks"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MiscFeatures( 'haplotype' );
}

sub href {
    my ($self,$f)= @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?l=@{[$f->get_attribute('name')]}";
}
sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( 'bacs', 'threshold_navigation' ) || 2e7) * 1000;
    my ($chr,$start, $end) = $f->get_attribute('name') =~ /^(\w+):(\w+)-(\w+)/;
    return { 
        'caption'   => "Haplotype block",
        "Chr: $chr $start-$end" => "",
        'Jump to haplotype' => $self->href($f),
    };
}

sub image_label {
    my ($self, $f ) = @_;
    my ($chr,$start, $end) = $f->get_attribute('name') =~ /^(\w+):(\w+)-(\w+)/;
    return ("Chr: $chr $start-$end",'overlaid');
}

1;

