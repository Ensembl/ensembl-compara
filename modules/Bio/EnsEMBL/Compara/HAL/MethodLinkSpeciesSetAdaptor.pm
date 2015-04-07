# dummy methodlinkspeciesset since the halAdaptor plays most of the roles.
package Bio::EnsEMBL::Compara::HAL::MethodLinkSpeciesSetAdaptor;

sub new {
    my $class = shift;
    my $adaptor = shift;
    my $self = {};
    bless $self, $class;
    $self->{'hal_adaptor'} = $adaptor;
    return $self;
}

# hacky--but none of the fetching makes any sense so we just return
# the same MethodLinkSpeciesSet for any query.

# TODO: could, and should, create subsets of the species sets if the
# parameters indicate that's a reasonable thing to do.

# TODO: could also use different LOD levels as "methods".
sub fetch_all_by_species_set_id {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return $self->_get_default_mlss();
}

sub fetch_by_method_link_id_species_set_id {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return $self->_get_default_mlss();
}

# NB: here is where we could use LODs as methods if we wanted.
sub fetch_all_by_method_link_type {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return [$self->_get_default_mlss()];
}

sub fetch_all_by_GenomeDB {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return [$self->_get_default_mlss()];
}

sub fetch_all_by_method_link_type_GenomeDB {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return [$self->_get_default_mlss()];
}

# NB: here would be the best place to implement different species
# subsetting.
sub fetch_by_method_link_type_GenomeDBs {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return $self->_get_default_mlss();
}

sub fetch_by_method_link_type_genome_db_ids {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return [$self->_get_default_mlss()];
}

sub fetch_by_method_link_type_registry_aliases {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return $self->_get_default_mlss();
}

sub fetch_by_method_link_type_species_set_name {
    my $self = shift;
    # Ignore everything and just return the only MLSS we have.
    return $self->_get_default_mlss();
}

sub _get_default_mlss {
    my $self = shift;
    return Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method => Bio::EnsEMBL::Compara::Method->new( -type => 'HAL' ),
        -species_set_obj => Bio::EnsEMBL::Compara::SpeciesSet->new());
}

1;
