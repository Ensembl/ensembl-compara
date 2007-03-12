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
           $self->{'config'}->{'species_defs'}->multi( 'BLASTZ_RAW',       $self->{'species'} ),
           );
		my %vega_config = $self->{'config'}->{'species_defs'}->multiX('VEGA_COMPARA_CONF');
		if (defined %vega_config) {
			my ($ps_name,$ps_start,$ps_end) = split /:/, $self->{'location'};
			my $this_species = $self->{'species'};
			#only add links for alignments actually in the database
			my $methods_names = [ [qw(BLASTZ_RAW chromosome)], [qw(BLASTZ_CHAIN clone)] ];
			foreach my $method_link ( @{$methods_names} ) {
				my $method = $method_link->[0];
				foreach my $other_species (sort keys %{$vega_config{$method}{$this_species}}) {
					foreach my $alignment (keys %{$vega_config{$method}{$this_species}{$other_species}}) {			
						my $this_name = $vega_config{$method}{$this_species}{$other_species}{$alignment}{'source_name'};
						#sanity check for alignments that exclude this slice
						next unless ($ps_name eq $this_name);
						my $start = $vega_config{$method}{$this_species}{$other_species}{$alignment}{'source_start'};
						my $end = $vega_config{$method}{$this_species}{$other_species}{$alignment}{'source_end'};
						#only create entries for alignments that overlap the current slice
						if ($end > $ps_start && $start < $ps_end) {
							my $chr = $vega_config{$method}{$this_species}{$other_species}{$alignment}{'target_name'};
							$self->add_link(
											"Add/Remove $other_species:$chr",
											$LINK."flip=$other_species:$chr",
											''
										   );
						}
					}
				}
			}
		}
		else {
			foreach my $species( keys %species ) {
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
