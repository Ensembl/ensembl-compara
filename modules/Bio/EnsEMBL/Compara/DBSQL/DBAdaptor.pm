#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -host   => 'caldy',
        -dbname => 'pog',
        -species => 'Multi',
        );

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -url => 'mysql://user:pass@host:port/db_name');


=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBAdaptor );


=head2 new

  Arg [..]   : list of named arguments.  See Bio::EnsEMBL::DBConnection.
               [-URL mysql://user:pass@host:port/db_name] alternative way to specify the
               connection parameters. Pass and port are optional. If none is speciefied,
               the species name will be equal to the db_name.
               [-GROUP] This option is *always* set to "compara". Use another DBAdaptor
               for other groups.
  Example    :  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
                    -user   => 'root',
                    -pass => 'secret',
                    -host   => 'caldy',
                    -port   => 3306,
                    -dbname => 'ensembl_compara',
                    -species => 'Multi');
  Example    :  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
                    -url => 'mysql://root:secret@caldy:3306/ensembl_compara'
                    -species => 'Multi');
  Description: Creates a new instance of a DBAdaptor for the compara database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub new {
  my ($class, @args) = @_;

  my ($url, $species) = rearrange(['URL', 'SPECIES'], @args);

  if ($url and $url =~ /mysql\:\/\/([^\@]+\@)?([^\:\/]+)(\:\d+)?\/(.+)/) {
    my $user_pass = $1;
    my $host = $2;
    my $port = $3;
    my $dbname = $4;

    $user_pass =~ s/\@$//;
    my ($user, $pass) = $user_pass =~ m/([^\:]+)(\:.+)?/;
    $pass =~ s/^\:// if ($pass);
    $port =~ s/^\:// if ($port);
    push(@args, "-user" => $user) if ($user);
    push(@args, "-pass" => $pass) if ($pass);
    push(@args, "-port" => $port) if ($port);
    push(@args, "-host" => $host);
    push(@args, "-dbname" => $dbname);
    if (!$species) {
      push(@args, "-species" => $dbname);
    }
  }

  my $self = $class->SUPER::new(@args);

  return $self;
}


=head2 get_db_adaptor [DEPRECATED]

  Arg [1]    : string $species
               the name of the species to obtain a genome DBAdaptor for.
  Arg [2]    : string $assembly
               the name of the assembly to obtain a genome DBAdaptor for.
  Example    : $hs_db = $db->get_db_adaptor('Homo sapiens','NCBI_30');
  Description: Obtains a DBAdaptor for the requested genome if it has been
               specified in the configuration file passed into this objects
               constructor, or subsequently added using the add_db_adaptor
               method.  If the DBAdaptor is not available (i.e. has not
               been specified by one of the abbove methods) undef is returned.
               DEPRECATED: see Bio::EnsEMBL::Registry module.
  Returntype : Bio::EnsEMBL::DBSQL::DBConnection or undef
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDBAdaptor

=cut

sub get_db_adaptor {
  my ($self, $species, $assembly) = @_;

  deprecate("get_db_adaptor is deprecated. Correct method is to call\n".
            "dba->get_GenomeDBAdaptor->fetch_by_name_assembly(<name>,<assembly>)->db_adaptor\n".
            "Or to use get_DBAdaptor using the Bio::EnsEMBL::Registry\n");

  unless($species && $assembly) {
    throw("species and assembly arguments are required\n");
  }
  
  my $gdb;

  eval {
    $gdb = $self->get_GenomeDBAdaptor->fetch_by_name_assembly($species, $assembly);
  };
  if ($@) {
    warning("Catched an exception, here is the exception message\n$@\n");
    return undef;
  }

  return $gdb->db_adaptor;
}


sub get_available_adaptors {
 
  my %pairs =  (
      "MetaContainer" => "Bio::EnsEMBL::DBSQL::MetaContainer",
      "MethodLinkSpeciesSet" => "Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor",
      "SyntenyRegion"   => "Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor",
      "DnaAlignFeature" => "Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor",
      "GenomeDB"        => "Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor",
      "SpeciesSet"      => "Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor",
      "DnaFrag" => "Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor",
      "DnaFragRegion" => "Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor",
      "GenomicAlignBlock" => "Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor",
      "GenomicAlign" => "Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor",
      "GenomicAlignGroup" => "Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor",
      "GenomicAlignTree" => "Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTreeAdaptor",
      "AlignSlice" => "Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor",
      "Homology" => "Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor",
      "Family" => "Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor",
      "Domain" => "Bio::EnsEMBL::Compara::DBSQL::DomainAdaptor",
      "Subset" => "Bio::EnsEMBL::Compara::DBSQL::SubsetAdaptor",
      "Member" => "Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor",
      "Attribute" => "Bio::EnsEMBL::Compara::DBSQL::AttributeAdaptor",
      "NCBITaxon" => "Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor",
      "PeptideAlignFeature" => "Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor",
      "Sequence" => "Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor",
      "ProteinTree" => "Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor",
      "SuperProteinTree" => "Bio::EnsEMBL::Compara::DBSQL::SuperProteinTreeAdaptor",
      "NCTree" => "Bio::EnsEMBL::Compara::DBSQL::NCTreeAdaptor",
      "Analysis" => "Bio::EnsEMBL::DBSQL::AnalysisAdaptor",
      "ConservationScore" => "Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor",
      "ConstrainedElement" => "Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor",
      "SitewiseOmega" => "Bio::EnsEMBL::Compara::DBSQL::SitewiseOmegaAdaptor",
      "SpeciesTree" => "Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor",
        );
  return (\%pairs);
}
 

1;
