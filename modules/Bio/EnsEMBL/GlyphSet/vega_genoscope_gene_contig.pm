package Bio::EnsEMBL::GlyphSet::vega_genoscope_gene_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::GlyphSet_gene;
@ISA = qw(Bio::EnsEMBL::GlyphSet_gene);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use  Sanger::Graphics::Bump;
use EnsWeb;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);



sub my_label {
return 'Genoscope Genes';
}


sub logic_name {
return 'genoscope';
}


sub my_depth {
 my ($self) = @_;
 my $Config  = $self->{'config'};
return $Config->get('vega_sanger_gene_contig', 'dep') ;
}



1;
        
