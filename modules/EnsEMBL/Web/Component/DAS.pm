=head1 NAME

EnsEMBL::Web::Component::DAS

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;

sub features {
    my( $panel, $object ) = @_;

    my @segments = $object->Locations;

    foreach my $segment (@segments) {
	warn(join ('*', "SEGMENT:", $segment->seq_region_name, $segment->seq_region_start, $segment->seq_region_end));

    }

}

1;
