package Bio::EnsEMBL::GlyphSet::zebrafish_match;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature2;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);


sub my_label { return "Dr cons"; }

sub features {
    my ($self) = @_;
    
    my $assembly = 
      EnsWeb::species_defs->other_species('Danio_rerio','ENSEMBL_GOLDEN_PATH');

    return [] unless $assembly;

    return $self->{'container'}->get_all_compara_DnaAlignFeatures(
							   'Danio rerio',
							    $assembly,'WGA');
}

sub href {
    my ($self, $chr_pos  ) = @_;
    return "/Danio_rerio/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
    my ($self, $id, $chr_pos, $text ) = @_;
    return { 
		'caption'    => $id, # $f->id,
		'Jump to Danio rerio' => $self->href( $chr_pos ), 
    };
}


sub unbumped_zmenu {
    my ($self, $ref, $target,$width, $text ) = @_;
    my ($chr,$pos) = @$target;
    my $chr_pos = "l=$chr:".($pos-$width)."-".($pos+$width);
    return { 
    	'caption'    => 'Dot-plot', 
    	'Dotter' => $self->unbumped_href( $ref, $target ),
	'Jump to Danio rerio' => $self->href( $chr_pos ), 
        $text => ''

    };
}

sub unbumped_href {
    my ($self, $ref, $target ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/dotterview?ref=".join(':',@{[$self->{container}{_config_file_name_}]},@$ref).
                        "&hom=".join(':','Danio_rerio', @$target ) ;
}


1;

