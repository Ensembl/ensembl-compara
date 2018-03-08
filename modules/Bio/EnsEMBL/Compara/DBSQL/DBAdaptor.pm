=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -host   => 'caldy',
        -dbname => 'pog',
        -species => 'Multi',
        );

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -url => 'mysql://user:pass@host:port/db_name');

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use strict;
use warnings;

use Carp;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::DBAdaptor');


=head2 new

  Arg [..]   : list of named arguments.  See Bio::EnsEMBL::DBConnection.
               [-URL mysql://user:pass@host:port/db_name] alternative way to specify the
               connection parameters. Pass and port are optional. If none is speciefied,
               the species name will be equal to the db_name.
               [-GROUP] This option is *always* set to 'compara'. Use another DBAdaptor
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
    push(@args, '-user' => $user) if ($user);
    push(@args, '-pass' => $pass) if ($pass);
    push(@args, '-port' => $port) if ($port);
    push(@args, '-host' => $host);
    push(@args, '-dbname' => $dbname);
    if (!$species) {
      push(@args, '-species' => $dbname);
    }
  }

  my $self = $class->SUPER::new(@args);

  return $self;
}


sub reference_dba {
    my $self = shift @_;
    
    if(@_) {
        $self->{'_reference_dba'} = shift @_;
    }
    return $self->{'_reference_dba'};
}


sub get_available_adaptors {
 
  my %pairs =  (
            # inherited from core:
        'MetaContainer'         => 'Bio::EnsEMBL::DBSQL::MetaContainer',

            # internal:
        'Method'                => 'Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor',
        'GenomeDB'              => 'Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor',
        'SpeciesSet'            => 'Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor',
        'MethodLinkSpeciesSet'  => 'Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor',
        'NCBITaxon'             => 'Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor',
        'SpeciesTree'           => 'Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor',
        'SpeciesTreeNode'       => 'Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor',

            # genomic:
        'DnaFrag'               => 'Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor',
        'SyntenyRegion'         => 'Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor',
        'DnaFragRegion'         => 'Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor',
        'DnaAlignFeature'       => 'Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor',
        'GenomicAlignBlock'     => 'Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor',
        'GenomicAlign'          => 'Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor',
        'GenomicAlignTree'      => 'Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTreeAdaptor',
        'ConservationScore'     => 'Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor',
        'ConstrainedElement'    => 'Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor',
        'AlignSlice'            => 'Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor',

            # genomic_production:
        'DnaFragChunk'          => 'Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor',
        'DnaFragChunkSet'       => 'Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor',
        'DnaCollection'         => 'Bio::EnsEMBL::Compara::Production::DBSQL::DnaCollectionAdaptor',
        'AnchorAlign'           => 'Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor',

            # gene-product:
        'Sequence'              => 'Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor',
        'GeneMember'            => 'Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor',
        'SeqMember'             => 'Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor',
        'GeneAlign'             => 'Bio::EnsEMBL::Compara::DBSQL::GeneAlignAdaptor',
        'AlignedMember'         => 'Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor',
        'Homology'              => 'Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor',
        'Family'                => 'Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor',
        'PeptideAlignFeature'   => 'Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor',
        'GeneTree'              => 'Bio::EnsEMBL::Compara::DBSQL::GeneTreeAdaptor',
        'GeneTreeNode'          => 'Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor',
        'CAFEGeneFamily'        => 'Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyAdaptor',
        'CAFEGeneFamilyNode'    => 'Bio::EnsEMBL::Compara::DBSQL::CAFEGeneFamilyNodeAdaptor',
        'HMMProfile'            => 'Bio::EnsEMBL::Compara::DBSQL::HMMProfileAdaptor',
        'HMMAnnot'              => 'Bio::EnsEMBL::Compara::DBSQL::HMMAnnotAdaptor',
        'GeneTreeObjectStore'   => 'Bio::EnsEMBL::Compara::DBSQL::GeneTreeObjectStoreAdaptor',

    );

    return (\%pairs);
}
 

=head2 go_figure_compara_dba

    Description: this is a method that tries lots of different ways to find connection parameters
                 from a given object/hash and returns a Compara DBA. Does not hash anything, just does the detective magic.

=cut

sub go_figure_compara_dba {
    my ($self, $foo) = @_;

        
    if(UNIVERSAL::isa($foo, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor')) {   # it is already a Compara adaptor - just return it

        return $foo;   

    } elsif(ref($foo) eq 'HASH') {  # simply a hash with connection parameters, plug them in:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( %$foo );

    } elsif(UNIVERSAL::isa($foo, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # a DBConnection itself, plug it in:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo );

    } elsif(UNIVERSAL::can($foo, 'dbc') and UNIVERSAL::isa($foo->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # another DBAdaptor, possibly Hive::DBSQL::DBAdaptor

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo->dbc );

    } elsif(UNIVERSAL::can($foo, 'db') and UNIVERSAL::can($foo->db, 'dbc') and UNIVERSAL::isa($foo->db->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # another data adaptor or Runnable:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo->db->dbc );

    } elsif(!ref($foo) and $foo=~m{^\w*://}) {

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $foo );

    } else {
    
        unless(ref($foo)) {    # maybe it is simply a registry key?
        
            my $dba;
            eval {
                require Bio::EnsEMBL::Registry;
                $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($foo, 'compara');
            };
            if($dba) {
                return $dba;
            }
        }

        croak "Sorry, could not figure out how to make a Compara DBAdaptor out of $foo";
    }
}

sub url {
    my $self = shift;

    my $dbc = $self->dbc;

    my $url = $dbc->driver . "://" . $dbc->user;
    $url .= ":" . $dbc->pass if $dbc->pass;
    $url .= '@' . $dbc->host;
    $url .= ":" . $dbc->port if $dbc->port;
    $url .= "/" . $dbc->dbname;

    return $url;
}


1;

