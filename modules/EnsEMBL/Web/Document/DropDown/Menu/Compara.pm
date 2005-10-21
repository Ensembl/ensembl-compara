package EnsEMBL::Web::Document::DropDown::Menu::Compara;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(
	   @_, ## This contains the menu containers as the first element
       'image_name'  => 'y-compara',
       'image_width' => 88,
       'alt'         => 'Compara'
       );
	my @menu_entries = @{$self->{'config'}->get('_settings','compara')||[]};

	my $num_checkboxes = 0;
	foreach ( @menu_entries ) { 
		next unless $self->{'config'}->is_available_artefact($_->[0]) || $self->{'scriptconfig'}->is_option( $_->[0]); 
		$self->add_checkbox( @$_ );
		$num_checkboxes++;
	}
	$num_checkboxes || return;

	if( $self->{'config'}->{'multi'} ){
		my $LINK = sprintf qq(/%s/%s?%s), $self->{'species'}, $self->{'script'}, $self->{'LINK'};
		my %species = (
           $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_NET',       $self->{'species'} ),
           $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_GROUP',     $self->{'species'} ),
           $self->{'config'}->{'species_defs'}->multi( 'PHUSION_BLASTN',   $self->{'species'} ),
           $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_RECIP_NET', $self->{'species'} ),
           $self->{'config'}->{'species_defs'}->multi( 'TRANSLATED_BLAT',  $self->{'species'} ),
           $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_RAW',       $self->{'species'} ) 
           );
		my %vega_config = $self->{'config'}->{'species_defs'}->multi('VEGA_BLASTZ_CONF');
		foreach my $species( keys %species ) {
			if (defined %vega_config) { 
				my ($ps_name,$ps_start,$ps_end) = split /:/, $self->{'location'};
				my $comps = $vega_config{$species};
				my (%matches,%sources);
				foreach my $dest (@{$comps}){
					if (($dest->[1] ne $ps_name) && ($dest->[0] eq $ps_name)) {
						$sources{$dest->[0]}++;
						$matches{$dest->[1]}++;
					}
				}
				if (grep {$ps_name eq $_} keys %sources) {
					my $sr = $vega_config{'regions'}{$ps_name}{'first'};
					my $er = $vega_config{'regions'}{$ps_name}{'last'};
					foreach my $hap (keys %matches) {
						if (($ps_end > $sr && $ps_end < $er) || ($ps_start < $er && $ps_start > $sr)) {
							$self->add_link(
											"Add/Remove $species:$hap",
											$LINK."flip=$species:$hap",
											''
										   );
						}
					}
				}
			} else {
				$self->add_link(
								"Add/Remove $species",
								$LINK."flip=$species",
								''
							   );
			}
		}
	}
	return $self;
}

1;
