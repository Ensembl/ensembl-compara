package Bio::EnsEMBL::GlyphSetManager::das;

use strict;
use Sanger::Graphics::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::das;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::GlyphSetManager);
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
        #warn( $das_source_name );
	next unless( $Config->get("managed_${das_source_name}",'on') eq 'on' );
	my $extra_config = EnsWeb::species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{$das_source_name};
	$extra_config->{'name'} = "managed_${das_source_name}";
	$self->add_glyphset( $extra_config );
    }
    my $ext_das = new ExternalDAS();
    $ext_das->get_sources();

    for my $das_source_name ( keys %{$ext_das->{'data'}} ) {
        #warn( "managed_extdas_${das_source_name}" );
	next unless( $Config->get("managed_extdas_$das_source_name",'on') eq 'on' );
        my $das_species = $ext_das->{'data'}->{$das_source_name}->{'species'};
        next if( $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'} );
            my $extra_config 		    = $ext_das->{'data'}->{$das_source_name};
         #   foreach( keys(%{$ext_das->{'data'}->{$das_source_name}})) {
	 #        warn("\t$_\t".$ext_das->{'data'}{$das_source_name}{$_}."\n");
         #   }
 
	       $extra_config->{'name'} 	= "managed_extdas_${das_source_name}";
	       $extra_config->{'url'} 		||= "http://$extra_config->{'URL'}/das";
        #warn( "ADDING GLYPHSET $das_species $das_source_name" );
        $self->add_glyphset( $extra_config );		
    }
}

sub add_glyphset {
	my ($self,$extra_config) = @_;	
		
	my $das_glyphset;

        #warn("Attaching..... $extra_config->{'name'} - $extra_config->{'url'}" );
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
