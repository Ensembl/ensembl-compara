package Bio::EnsEMBL::GlyphSet::rat_match;
use strict;
use vars qw(@ISA);
use       Bio::EnsEMBL::GlyphSet_feature2;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);


sub my_label { return "Rn cons"; }

sub features {
    my ($self) = @_;
    
    my $assembly = 
      EnsWeb::species_defs->other_species('Rattus_norvegicus')->{'ENSEMBL_GOLDEN_PATH'};

    return [] unless $assembly;

    return $self->{'container'}->get_all_compara_DnaAlignFeatures(
							   'Rattus norvegicus',
							    $assembly,'WGA');
}

sub href {
    my ($self, $chr_pos ) = @_;
    return "/Rattus_norvegicus/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
    my ($self, $id, $chr_pos ) = @_;
    return { 
	'caption'    => $id, # $f->id,
	'Jump to Rattus norvegicus' => $self->href( $chr_pos )
    };
}


sub unbumped_zmenu {
    my ($self, $ref, $target,$width ) = @_;
    my ($chr,$pos) = @$target;
    my $chr_pos = "l=$chr:".($pos-$width)."-".($pos+$width);

    return {
        'caption'    => 'Dot-plot',
        'Dotter' => $self->unbumped_href( $ref, $target ),
        'Jump to Rattus norevgicus' => $self->href( $chr_pos )
    };
}

sub unbumped_href {
    my ($self, $ref, $target ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/dotterview?ref=".join(':',$ENV{'ENSEMBL_SPECIES'},@$ref).
                        "&hom=".join(':','Rattus_norvegicus', @$target ) ;
}


1;

