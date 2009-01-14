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
               [-CONF_FILE] optional name of a file containing configuration
               information for compara genome databases. An example of the conf file
               can be found in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
               *** WARNING *** -CONF_FILE is now deprecated. Compara now uses the more generic
               Bio::EnsEMBL::Registry configuration file.
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

  my ($conf_file, $url, $species) = rearrange(['CONF_FILE', 'URL', 'SPECIES'], @args);

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

  if(defined($conf_file) and $conf_file ne "") {
    deprecate("Compara.conf file is deprecated. Compara is now using the\n" .
              "more generic Bio::EnsEMBL::Registry configuration file\n");

    #read configuration file from disk
    my @conf = @{do $conf_file};

    foreach my $genome (@conf) {
      my ($species, $assembly, $db_hash) = @$genome;
      my $db;

      my $module = $db_hash->{'module'};
      my $mod = $module;

      eval {
        # require needs /'s rather than colons
        if ( $mod =~ /::/ ) {
          $mod =~ s/::/\//g;
        }
        require "${mod}.pm";


        $db = $module->new(-dbname => $db_hash->{'dbname'},
                           -host   => $db_hash->{'host'},
                           -user   => $db_hash->{'user'},
                           -pass   => $db_hash->{'pass'},
                           -port   => $db_hash->{'port'},
                           -driver => $db_hash->{'driver'},
                           -disconnect_when_inactive => $db_hash->{'disconnect_when_inactive'});
      };

      if($@) {
        throw("could not load module specified in configuration file:$@");
      }

      unless($db && ref $db && $db->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) {
        throw("[$db] specified in conf file is not a " .
             "Bio::EnsEMBL::DBSQL::DBAdaptor");
      }

      if (defined $db) {
        # The core db connection will be cached in the genomeDB object, which is itself
        # cached in GenomeDBAdaptor.
        my $gdb = $self->get_GenomeDBAdaptor->fetch_by_name_assembly($species,$assembly);
        $gdb->db_adaptor($db);
      }
    }
  }

  return $self;
}


=head2 add_db_adaptor [DEPRECATED]

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBConnection
  Example    : $compara_db->add_db_adaptor($homo_sapiens_db);
  Description: Adds a genome-containing database to compara.  This database
               can be used by compara to obtain sequence for a genome on
               on which comparative analysis has been performed.  The database
               adaptor argument must define the get_MetaContainer argument
               so that species name and assembly type information can be
               extracted from the database.
               DEPRECATED: see Bio::EnsEMBL::Registry module.
  Returntype : 1 if success 0 otherwise
  Exceptions : Thrown if the argument is not a Bio::EnsEMBL::DBConnection
               or if the argument does not implement a get_MetaContainer
               method.
  Caller     : general

=cut

sub add_db_adaptor {
  my ($self, $dba) = @_;

  deprecate("add_db_adaptor is deprecated. Correct method is to call\n" .
            "dba->get_GenomeDBAdaptor->fetch_by_name_assembly(<name>,<assembly>)->db_adaptor(<coreDBA>)\n".
            "Or to use add_DBAdaptor using the Bio::EnsEMBL::Registry\n");

  unless($dba && ref $dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) {
    $self->throw("dba argument must be a Bio::EnsEMBL::DBSQL::DBAdaptor\n" .
                 "not a [$dba]");
  }

  my $mc = $dba->get_MetaContainer;
  my $csa = $dba->get_CoordSystemAdaptor;
  
  my $species = $mc->get_Species->binomial;
  my ($cs) = @{$csa->fetch_all};
  my $assembly = $cs ? $cs->version : '';
  
  my $gdb;
  try {
    $gdb = $self->get_GenomeDBAdaptor->fetch_by_name_assembly($species,$assembly);
  } catch {
    warning("Catched an exception, no GenomeDb defined\n$_\n");
  };

  return 0 unless (defined $gdb);

  $gdb->db_adaptor($dba);
  return 1;
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
      "Taxon" => "Bio::EnsEMBL::Compara::DBSQL::TaxonAdaptor",
      "NCBITaxon" => "Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor",
      "PeptideAlignFeature" => "Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor",
      "Sequence" => "Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor",
      "NestedSet" => "Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor",
      "ProteinTree" => "Bio::EnsEMBL::Compara::DBSQL::ProteinTreeAdaptor",
      "Analysis" => "Bio::EnsEMBL::DBSQL::AnalysisAdaptor",
      "ConservationScore" => "Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor",
      "ConstrainedElement" => "Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor",
      "SitewiseOmega" => "Bio::EnsEMBL::Compara::DBSQL::SitewiseOmegaAdaptor"
        );
  return (\%pairs);
}
 

1;
