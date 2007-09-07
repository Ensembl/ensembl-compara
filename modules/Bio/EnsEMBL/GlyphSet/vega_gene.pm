package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;

use Bio::EnsEMBL::GlyphSet::evega_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet::evega_gene);

sub legend {
    my ($self, $colours) = @_;
	my %sourcenames = (
					   'otter'          => 'Havana ',
					   'otter_external' => 'External ',
					   'otter_corf'     => 'CORF ',
					   'otter_igsf'     => 'IgSF ',
                       'otter_eucomm'   => 'Knockout genes',
					  );
	my $logic_name =  $self->my_config('logic_name');
    my %X;
    foreach my $colour ( values %$colours ) {
		my $l = $sourcenames{$logic_name};
		$l .= $colour->[1];
        $X{$l} = $colour->[0];
    }
    my @legend = %X;
    return \@legend;
}

sub zmenu {
    my ($self, $gene) = @_;
	my $script_name =  $ENV{'ENSEMBL_SCRIPT'};
    my $gid = $gene->stable_id();
    my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
	my $type = $self->format_vega_name($gene);
	my $author;
	if ( defined (@{$gene->get_all_Attributes('author')}) ) {
		$author =  shift( @{$gene->get_all_Attributes('author')} )->value || 'unknown';
	}
	else {
		$author =   'not defined';
	}
    my $zmenu = {
        'caption' 	             => $self->my_config('zmenu_caption'),
        "00:$id"	             => "",
		'02:Author: '.$author    => "",
        "04:Gene:$gid"           => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core),
    };

	#don't show type for an eucomm gene
	$zmenu->{"01:Gene Type:$type"} = "" unless ($gene->analysis->logic_name eq 'otter_eucomm');

	if ($script_name eq 'multicontigview') {
		if (my $href = $self->get_hap_alleles_and_orthologs_urls($gene)) {
			$zmenu->{"03:Realign display around this gene"} =  "$href";
		}
	}
    return $zmenu;
}

1;
