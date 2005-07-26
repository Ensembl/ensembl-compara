# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Species;

=head1 NAME

  GO::Model::Species;

=head1 DESCRIPTION

represents a gene product in a particular species (this will
effectively always be refered to implicitly by the gene symbol even
though a gene may have >1 product)

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);

sub _valid_params {
    return qw(id ncbi_taxa_id genus species common_name lineage_string apph);
}

sub from_bpspecies {
    my $class = shift;
    my $species = shift;
    my $division = shift;
    my $taxon = $class->new;
    $taxon->common_name($species->common_name);
    $taxon->genus($species->genus);
    $taxon->species($species->species);
#    $taxon->taxon_code($division) if $division;
    $taxon;
}

sub binomial {
    my $self = shift;
    return $self->genus." ".$self->species;
}

