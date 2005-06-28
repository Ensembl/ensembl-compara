package Bio::EnsEMBL::GlyphSet::vega_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::vega_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub features {
    my ($self, $logic_name, $database) = @_;

    # check data availability
    my $chr = $self->{'container'}->seq_region_name;
    my $avail = (split(/ /, $self->my_config('available')))[1]
                . "." . $self->{'container'}->seq_region_name;
    return ([]) unless($self->species_defs->get_config(
                $self->{'container'}{'_config_file_name_'}, 'DB_FEATURES')->{uc($avail)});
    my $db = $self->{'container'}->adaptor->db->get_db_adaptor('vega');
    return $db->get_GeneAdaptor->fetch_all_by_Slice_and_author($self->{'container'}, $self->my_config('author'), $logic_name);
}

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub legend {
    my ($self, $colours) = @_;
    my %X;
    foreach my $colour ( values %$colours ) {
        $colour->[1] =~ s/Curated (.*)/$1/;
        $X{ucfirst($colour->[1])} = $colour->[0];
    }
    my @legend = %X;
    return \@legend;
}

sub ens_ID {
  return '';
}

sub gene_label {
  my( $self, $g ) = @_;
  return $g->external_name || $g->stable_id();
}

sub gene_col {
  my( $self, $g ) = @_;
  ( my $type =  $g->type() ) =~ s/HUMACE-//;
  return $type;
}

1;
