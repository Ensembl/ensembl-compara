package Bio::EnsEMBL::GlyphSetManager::sub_repeat;

use strict;
use Sanger::Graphics::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::sub_repeat;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::GlyphSetManager);
use EnsWeb;

##
## 2001/07/03	js5		Added external DAS source code
## 2001/07/04	js5		Added sub add_glyphset to remove duplication in code in init!
##

sub init {
    my ($self) = @_;

    $self->label("Das Sources");

    my $Config = $self->{'config'};
    my %sub_repeat_sources = 
         ref( EnsWeb::species_defs->ENSEMBL_SUB_REPEAT_TRACKS ) eq 'HASH' ?
	 %{EnsWeb::species_defs->ENSEMBL_SUB_REPEAT_TRACKS} :
	 ();

    #########
    # apply parallelisation here |
    #                            V
    #
    foreach my $sub_repeat_source_name ( keys %sub_repeat_sources) {
	next unless( $Config->get("repeat_$sub_repeat_source_name",'on') eq 'on' );
	$self->add_glyphset( $sub_repeat_source_name, $sub_repeat_sources{ $sub_repeat_source_name } );
    }
}

sub add_glyphset {
	my ($self,$name, $label ) = @_;	
		
	my $sub_repeat_glyphset;

	eval {
            $sub_repeat_glyphset = new Bio::EnsEMBL::GlyphSet::sub_repeat(
		$self->{'container'},
		$self->{'config'},
		$self->{'highlights'},
		$self->{'strand'},
		{ 'name' => $name, 'label => $label }
	    );
	};
							   
	if($@) {
		print STDERR "REPEAT GLYPHSET $name failed\n";
	} else {
		push @{$self->{'glyphsets'}}, $sub_repeat_glyphset;
	}
}

1;
