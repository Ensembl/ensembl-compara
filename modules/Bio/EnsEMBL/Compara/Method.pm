=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Method

=head1 SYNOPSIS

    my $my_method       = Bio::EnsEMBL::Compara::Method->new( -type => 'FAMILY', -class => 'Family.family' );

    $method_adaptor->store( $my_method );

    my $dbID = $my_method->dbID();

=head1 DESCRIPTION

Method is a data object that roughly represents the type of pipeline run and the corresponding type of data generated.

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Method;

use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


=head2 new

  Arg [..]   : Takes a set of named arguments
  Example    : my $my_method = Bio::EnsEMBL::Compara::Method->new(
                                -dbID            => $dbID,
                                -type            => 'SYNTENY',
                                -class           => 'SyntenyRegion.synteny',
                                -adaptor         => $method_adaptor );
  Description: Creates a new Method object
  Returntype : Bio::EnsEMBL::Compara::Method

=cut


sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);

    my ($type, $mclass) =
        rearrange([qw(TYPE CLASS)], @_);

    $self->type($type)        if (defined ($type));
    $self->class($mclass)     if (defined ($mclass));

    return $self;
}


=head2 type

  Arg [1]    : (opt.) string type
  Example    : my $type = $method->type();
  Example    : $method->type('BLASTZ_NET');
  Description: Getter/Setter for the type of this method
  Returntype : string type

=cut

sub type {
    my $self = shift;

    $self->{'_type'} = shift if(@_);

    return $self->{'_type'};
}


=head2 class

  Arg [1]    : (opt.) string class
  Example    : my $class = $method->class();
  Example    : $method->class('GenomicAlignBlock.pairwise_alignment');
  Description: Getter/Setter for the class of this method
  Returntype : string class

=cut

sub class {
    my $self = shift;

    $self->{'_class'} = shift if(@_);

    return $self->{'_class'};
}


=head2 toString

  Args       : (none)
  Example    : print $method->toString()."\n";
  Description: returns a stringified representation of the method
  Returntype : string

=cut

sub toString {
    my $self = shift;

    return ref($self).": dbID=".($self->dbID || '?').", type='".$self->type."', class='".$self->class."'";
}

1;

