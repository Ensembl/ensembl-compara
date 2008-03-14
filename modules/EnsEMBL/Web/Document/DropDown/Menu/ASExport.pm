package EnsEMBL::Web::Document::DropDown::Menu::ASExport;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(
				  @_, ## This contains the menu containers as the first element
				  'image_name'  => 'y-exportas',
				  'image_width' => 58,
				  'alt'         => 'Export data'
  );


    my $location = $self->{'location'};

    my $exportURL = sprintf "/%s/alignview?class=AlignSlice;chr=%s;bp_start=%s;bp_end=%s", $self->{'species'}, $location->seq_region_name, $location->seq_region_start, $location->seq_region_end;

    my $rt = $location->seq_region_type;
    if ($rt ne 'chromosome') {
	$exportURL .= "&region=$rt";
    }
    my $wuc = $self->{config}; 

    my @species = @{$wuc->get('alignslice', 'species') || []};
    my $aID = $wuc->get('alignslice', 'id');
    my $aType = $wuc->get('alignslice', 'type');

    $exportURL .= ";method=$aID";

    my $exports = { 
		    fasta  => { text  => 'Alignment',
				url   => "$exportURL&format=fasta",
				avail => 1 },

		};

    foreach( qw(pdf svg postscript) ) {
	$self->add_checkbox( "format_$_", "Include @{[uc($_)]} links" );
    }
    foreach( keys %{$exports} ){
	if( $exports->{$_}->{avail} ){
	    $self->add_link( $exports->{$_}->{'text'}, $exports->{$_}->{'url'} );
	}
    }
    return $self;
}

1;
