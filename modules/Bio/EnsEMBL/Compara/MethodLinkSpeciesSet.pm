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

=head1 NAME

Bio::EnsEMBL::Compara::MethodLinkSpeciesSet -
Relates every method_link with the species_set for which it has been used

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor             => $method_link_species_set_adaptor,
                       -method              => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ'),
                       -species_set_obj     => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]),
                       -max_alignment_length => 10000,
                   );

SET VALUES
  $method_link_species_set->dbID( 12 );
  $method_link_species_set->adaptor( $mlss_adaptor );
  $method_link_species_set->method( Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ') );
  $method_link_species_set->species_set( Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]) );
  $method_link_species_set->max_alignment_length( 10000 );

GET VALUES
  my $mlss_id           = $method_link_species_set->dbID();
  my $mlss_adaptor      = $method_link_species_set->adaptor();
  my $method            = $method_link_species_set->method();
  my $method_link_id    = $method_link_species_set->method->dbID();
  my $method_link_type  = $method_link_species_set->method->type();
  my $species_set       = $method_link_species_set->species_set_obj();
  my $species_set_id    = $method_link_species_set->species_set_obj->dbID();
  my $genome_dbs        = $method_link_species_set->species_set_obj->genome_dbs();
  my $max_alignment_length = $method_link_species_set->max_alignment_length();

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::SpeciesSet;

use base (  'Bio::EnsEMBL::Storable',           # inherit dbID(), adaptor() and new() methods
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );

my $DEFAULT_MAX_ALIGNMENT = 20000;


=head2 new (CONSTRUCTOR)

  Arg [-DBID]           : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]        : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor $adaptor
                            (the adaptor for connecting to the database)
  Arg [-METHOD]         : Bio::EnsEMBL::Compara::Method $method object
  Arg [-SPECIES_SET_OBJ]: Bio::EnsEMBL::Compara::SpeciesSet $species_set object
  Arg [-NAME]           : (opt.) string $name (the name for this method_link_species_set)
  Arg [-SOURCE]         : (opt.) string $source (the source of these data)
  Arg [-URL]            : (opt.) string $url (the original url of these data)
  Arg [-MAX_ALGINMENT_LENGTH]
                        : (opt.) int $max_alignment_length (the length of the largest alignment
                            for this MethodLinkSpeciesSet (only used for genomic alignments)
  Example     : my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor => $method_link_species_set_adaptor,
                       -method => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ' ),
                       -species_set => [$gdb1, $gdb2, $gdb3],
                       -max_alignment_length => 10000,
                   );
  Description : Creates a new MethodLinkSpeciesSet object
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);  # deal with Storable stuff

    my ($method, $method_link_id, $method_link_type, $method_link_class,
        $species_set_obj, $species_set, $species_set_id,
        $name, $source, $url, $max_alignment_length) =
            rearrange([qw(
                METHOD METHOD_LINK_ID METHOD_LINK_TYPE METHOD_LINK_CLASS
                SPECIES_SET_OBJ SPECIES_SET SPECIES_SET_ID
                NAME SOURCE URL MAX_ALIGNMENT_LENGTH)], @_);

  if($method) {
      $self->method($method);
  } else {
      warning("Please consider using -method to set the method instead of older/deprecated ways to do it");
  }

    # the following three should generate a deprecated warning:
  $self->method_link_id($method_link_id) if (defined ($method_link_id));
  $self->method_link_type($method_link_type) if (defined ($method_link_type));
  $self->method_link_class($method_link_class) if (defined ($method_link_class));

  warning("method has not been set in MLSS->new") unless($self->method());

  $self->species_set_obj($species_set_obj) if (defined ($species_set_obj));
  $self->species_set($species_set) if (defined ($species_set));
  $self->species_set_id($species_set_id) if (defined ($species_set_id));

  warning("species_set_obj has not been set in MLSS->new") unless($self->species_set_obj());

  $self->name($name) if (defined ($name));
  $self->source($source) if (defined ($source));
  $self->url($url) if (defined ($url));
  $self->max_alignment_length($max_alignment_length) if (defined ($max_alignment_length));

  return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 method
 
  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::Method object
  Example    : my $method_object = $method_link_species_set->method();
  Example    : $method_link_species_set->method( $method_object );
  Description: get/set for attribute method
  Returntype : Bio::EnsEMBL::Compara::Method
  Exceptions : none
  Caller     : general
 
=cut

sub method {
    my ($self, $method) = @_;

    if($method) {
        if(ref($method) eq 'HASH') {
            $method = Bio::EnsEMBL::Compara::Method->new( %$method ) or die "Could not automagically create a Method";
        }

        $self->{'method'} = $method;
    }

    return $self->{'method'};
}


=head2 species_set_obj

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::SpeciesSet species_set object
  Example    : my $species_set_obj = $mlss->species_set_obj();
  Example    : $mlss->species_set_obj( $species_set_obj );
  Description: getter/setter for species_set_obj attribute
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions : none
  Caller     : general

=cut

sub species_set_obj {
    my ($self, $species_set_obj) = @_;

    if($species_set_obj) {
        if(ref($species_set_obj) eq 'HASH') {
            $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new( %$species_set_obj ) or die "Could not automagically create a SpeciesSet";
        }

        $self->{'species_set'} = $species_set_obj;
    }

    return $self->{'species_set'};
}


=head2 method_link_id
 
  Arg [1]    : (opt.) integer method_link_id
  Example    : my $meth_lnk_id = $method_link_species_set->method_link_id();
  Example    : $method_link_species_set->method_link_id(23);
  Description: get/set for attribute method_link_id
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : DEPRECATED, use $mlss->method->dbID instead
 
=cut

sub method_link_id {
    my $self = shift @_;

    deprecate("MLSS->method_link_id() is DEPRECATED, please use MLSS->method->dbID(). method_link_id() will be removed in release 70.");

    if(@_) {
        if($self->method) {
            $self->method->dbID( @_ );
        } else {
            $self->method( Bio::EnsEMBL::Compara::Method->new(-dbID => @_) );
        }
    }

        # type is known => fetch the method from DB and set all of its attributes
    if (!$self->method->dbID and $self->adaptor and my $type = $self->method->type) {
        my $method_adaptor = $self->adaptor->db->getMethodAdaptor;
        if( my $fetched_method = $method_adaptor->fetch_by_type( $type ) ) {
            $self->method( $fetched_method );
        } else {
            warning("Could not fetch method by type '$type'");
        }
    }

    return $self->method->dbID();
}


=head2 method_link_type
 
  Arg [1]    : (opt.) string method_link_type
  Example    : my $meth_lnk_type = $method_link_species_set->method_link_type();
  Example    : $method_link_species_set->method_link_type("BLASTZ_NET");
  Description: get/set for attribute method_link_type
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : DEPRECATED, use $mlss->method->type instead
 
=cut

sub method_link_type {
    my $self = shift @_;

    deprecate("MLSS->method_link_type() is DEPRECATED, please use MLSS->method->type(). method_link_type() will be removed in release 70.");

    if(@_) {
        if($self->method) {
            $self->method->type( @_ );
        } else {
            $self->method( Bio::EnsEMBL::Compara::Method->new(-type => @_) );
        }
    }

        # dbID is known => fetch the method from DB and set all of its attributes
    if (!$self->method->type and $self->adaptor and my $dbID = $self->method->dbID) {
        my $method_adaptor = $self->adaptor->db->getMethodAdaptor;
        if( my $fetched_method = $method_adaptor->fetch_by_dbID( $dbID ) ) {
            $self->method( $fetched_method );
        } else {
            warning("Could not fetch method by dbID '$dbID'");
        }
    }

    return $self->method->type();
}


=head2 method_link_class
 
  Arg [1]    : (opt.) string method_link_class
  Example    : my $meth_lnk_class = $method_link_species_set->method_link_class();
  Example    : $method_link_species_set->method_link_class("GenomicAlignBlock.multiple_alignment");
  Description: get/set for attribute method_link_class
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : DEPRECATED, use $mlss->method->class instead
 
=cut

sub method_link_class {
    my $self = shift @_;

    deprecate("MLSS->method_link_class() is DEPRECATED, please use MLSS->method->class(). method_link_class() will be removed in release 70.");

    if(@_) {
        if($self->method) {
            $self->method->class( @_ );
        } else {
            $self->method( Bio::EnsEMBL::Compara::Method->new(-class => @_) );
        }
    }

        # dbID is known => fetch the method from DB and set all of its attributes
    if (!$self->method->class and $self->adaptor and my $dbID = $self->method->dbID) {
        my $method_adaptor = $self->adaptor->db->getMethodAdaptor;
        if( my $fetched_method = $method_adaptor->fetch_by_dbID( $dbID ) ) {
            $self->method( $fetched_method );
        } else {
            warning("Could not fetch method by dbID '$dbID'");
        }
    }

    return $self->method->class();
}


sub _set_genome_dbs {
    my ($self, $arg) = @_;

    my %genome_db_hash = ();
    foreach my $gdb (@$arg) {
        assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB');

        if(defined $genome_db_hash{$gdb->dbID}) {
            warn("GenomeDB (".$gdb->name."; dbID=".$gdb->dbID .") appears twice in this Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n");
        } else {
            $genome_db_hash{$gdb->dbID} = $gdb;
        }
    }
    my $genome_dbs = [ values %genome_db_hash ] ;

    my $species_set_id = $self->adaptor && $self->adaptor->db->get_SpeciesSetAdaptor->find_species_set_id_by_GenomeDBs_mix( $genome_dbs );

    my $ss_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -genome_dbs     => $genome_dbs,
        $species_set_id ? (-species_set_id => $species_set_id) : (),
    );
    $self->species_set_obj( $ss_obj );
}



=head2 species_set_id

  Arg [1]    : (opt.) integer species_set_id
  Example    : my $species_set_id = $method_link_species_set->species_set_id();
  Example    : $method_link_species_set->species_set_id(23);
  Description: get/set for attribute species_set_id
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : DEPRECATED, use $mlss->species_set_obj->dbID instead

=cut

sub species_set_id {
    my $self = shift @_;

    deprecate("MLSS->species_set_id() is DEPRECATED, please use MLSS->species_set_obj->dbID(). species_set_id() will be removed in release 70.");

    if(my $species_set_obj = $self->species_set_obj) {
        return $species_set_obj->dbID( @_ );
    } else {
        warning("SpeciesSet object has not been set, so cannot deal with its dbID");
        return undef;
    }
}


=head2 species_set
 
  Arg [1]    : (opt.) listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Example    : my $meth_lnk_species_set = $method_link_species_set->species_set();
  Example    : $method_link_species_set->species_set([$gdb1, $gdb2, $gdb3]);
  Description: get/set for attribute species_set
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Exceptions : Thrown if any argument is not a Bio::EnsEMBL::Compara::GenomeDB
               object or a GenomeDB entry appears several times
  Caller     : general
  Status     : DEPRECATED, use $mlss->species_set_obj->genome_dbs instead
 
=cut

sub species_set {
    my ($self, $arg) = @_;

    deprecate("MLSS->species_set() is DEPRECATED, please use MLSS->species_set_obj->genome_dbs(). species_set() will be removed in release 70.");

    if($arg) {
        if(UNIVERSAL::isa($arg, 'Bio::EnsEMBL::Compara::SpeciesSet')) {

            $self->species_set_obj( $arg );

        } elsif((ref($arg) eq 'ARRAY') and @$arg) {

            $self->_set_genome_dbs( $arg );

        } else {
            die "Wrong type of argument to $self->species_set()";
        }
    }
    return $self->species_set_obj->genome_dbs;      # for compatibility, we shall keep this method until everyone has switched to using species_set_obj()
}


=head2 name

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->name();
  Example    : $method_link_species_set->name("families");
  Description: get/set for attribute name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub name {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'name'} = $arg ;
  }

  return $self->{'name'};
}


=head2 source

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->source();
  Example    : $method_link_species_set->source("ensembl");
  Description: get/set for attribute source. The source refers to who
               generated the data in a first instance (ensembl, ucsc...)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub source {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'source'} = $arg ;
  }

  return $self->{'source'};
}


=head2 url

  Arg [1]    : (opt.) string $url
  Example    : my $name = $method_link_species_set->source();
  Example    : $method_link_species_set->url("http://hgdownload.cse.ucsc.edu/goldenPath/monDom1/vsHg17/");
  Description: get/set for attribute url. Defines where the data come from if they
               have been imported
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub url {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'url'} = $arg ;
  }

  return $self->{'url'};
}


=head2 get_common_classification

  Arg [1]    : -none-
  Example    : my $common_classification = $method_link_species_set->
                   get_common_classification();
  Description: This method fetches the taxonimic classifications for all the
               species included in this
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object and
               returns the common part of them.
  Returntype : array of strings
  Exceptions : 
  Caller     : general

=cut

sub get_common_classification {
  my ($self) = @_;
  my $common_classification;

  my $species_set = $self->species_set();

  foreach my $this_genome_db (@$species_set) {
    my @classification = split(" ", $this_genome_db->taxon->classification);
    if (!defined($common_classification)) {
      @$common_classification = @classification;
    } else {
      my $new_common_classification = [];
      for (my $i = 0; $i <@classification; $i++) {
        for (my $j = 0; $j<@$common_classification; $j++) {
          if ($classification[$i] eq $common_classification->[$j]) {
            push(@$new_common_classification, splice(@$common_classification, $j, 1));
            last;
          }
        }
      }
      $common_classification = $new_common_classification;
    }
  }

  return $common_classification;
}


=head2 max_alignment_length
 
  Arg [1]    : (opt.) int $max_alignment_length
  Example    : my $max_alignment_length = $method_link_species_set->
                   max_alignment_length();
  Example    : $method_link_species_set->max_alignment_length(1000);
  Description: get/set for attribute max_alignment_length
  Returntype : integer
  Exceptions : 
  Caller     : general
 
=cut

sub max_alignment_length {
    my $self = shift @_;

    if(@_) {
        $self->add_tag('max_align', shift @_);
    }

    return $self->get_value_for_tag('max_align') || $DEFAULT_MAX_ALIGNMENT;
}


=head2 toString

  Args       : (none)
  Example    : print $mlss->toString()."\n";
  Description: returns a stringified representation of the method_link_species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    return ref($self).": dbID=".($self->dbID || '?').
                      ", name='".$self->name.
                      "', source='".$self->source.
                      "', url='".$self->url.
                      "', max_alignment_length=".($self->max_alignment_length || '?').
                      ", {".$self->method->toString."} x {".$self->species_set_obj->toString."}";
}


1;
