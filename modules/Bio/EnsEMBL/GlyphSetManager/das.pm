package Bio::EnsEMBL::GlyphSetManager::das;
use strict;
use Bio::EnsEMBL::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::das;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSetManager);
use Data::Dumper;
use ExternalDAS;
use EnsWeb;

##
## 2001/07/03	js5		Added external DAS source code
## 2001/07/04	js5		Added sub add_glyphset to remove duplication in code in init!
##

sub init {
    my ($self) = @_;

    $self->label("Das Sources");

    my $Config = $self->{'config'};
    my @das_source_names = 
         ref( EnsWeb::species_defs->ENSEMBL_INTERNAL_DAS_SOURCES ) eq 'HASH' ?
	 keys %{EnsWeb::species_defs->ENSEMBL_INTERNAL_DAS_SOURCES}          :
	 ();

    #########
    # apply parallelisation here |
    #                            V
    #
    for my $das_source_name (@das_source_names) {
		next unless( $Config->get($das_source_name,'on') eq 'on' );
		my $extra_config = EnsWeb::species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{$das_source_name};
		$extra_config->{'name'} = $das_source_name;
		$self->add_glyphset( $extra_config );
	}
	my $ext_das = new ExternalDAS();
	$ext_das->get_sources();

    for my $das_source_name ( keys %{$ext_das->{'data'}} ) {
		next unless( $Config->get("extdas_$das_source_name",'on') eq 'on' );
		my $extra_config 		    = $ext_das->{'data'}->{$das_source_name};
		$extra_config->{'name'} 	= "extdas_$das_source_name";
		$extra_config->{'url'} 		= "http://$extra_config->{'URL'}/das";
		$self->add_glyphset( $extra_config );		
	}	
}

sub add_glyphset {
	my ($self,$extra_config) = @_;	
		
	my $das_glyphset;

	eval {
		$das_glyphset = new Bio::EnsEMBL::GlyphSet::das(
			$self->{'container'},
			$self->{'config'},
			$self->{'highlights'},
			$self->{'strand'},
		$extra_config);
	};
							   
	if($@) {
		print STDERR "DAS GLYPHSET $extra_config->{'name'} failed\n";
	} else {
		push @{$self->{'glyphsets'}}, $das_glyphset;
	}
}

1;
