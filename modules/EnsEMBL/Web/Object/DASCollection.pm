package EnsEMBL::Web::Object::DASCollection;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;
use Data::Dumper;
use SOAP::Lite;

@EnsEMBL::Web::Object::DASCollection::ISA = qw(EnsEMBL::Web::Object);

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

#======================================================================

=head2 get_DASAdaptor_attributes_by method

  Arg [1]   : List of DASAdaptor attributes method names
  Function  : Returns an arrayref of hashes where each hash contains 
              name=>value pairs for each requested attribute. One hash per
              DAS object.
  Returntype: Listref of hashrefs
  Exceptions: Given attribute is not a DASAdaptor method
  Caller    : 
  Example   : 

=cut

sub get_DASAdaptor_attributes_by_method{
  my $self    = shift;
  
  my @attribs = @_;
  my @das_objs = ( sort{$a->adaptor->name cmp $b->adaptor->name } @{$self->Obj} );
  my $attrib_data_listref = [];
  foreach my $das( @das_objs ){
    my $adpt = $das->adaptor;
    my $attrib_data = {};
    foreach my $attrib( @attribs ){
      $attrib_data->{$attrib} = $adpt->$attrib();
    }
    push @$attrib_data_listref, $attrib_data;
  }
  return $attrib_data_listref;
}

#----------------------------------------------------------------------

=head2 get_DASSeqFeatures_by_source_name

  Arg [1]   : DBLink container obj, e.g. Bio::EnsEMBL::Gene
  Arg [2]   : string - source name
  Arg [3]   : scope (optional): global | local
  Function  : Returns GeneDAS annotation from specified source 
              with specified scope
  Returntype: array of DASSeqFeature objects
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_DASSeqFeatures_by_source_name{
  my $self   = shift;
  my $dblink_container = shift || die( "Need a DBLink container obj" );
  my $name   = shift || die( "Need a DAS name!" );
  my $scope  = shift || undef();
  
  my( $das_obj ) = grep{$_->adaptor->name eq $name} @{$self->Obj};
  $das_obj || ( warn( "Not found: DAS object named $name" ) && return() );
  
  my( $label, $dataref ) = $das_obj->fetch_all_by_DBLink_Container( $dblink_container, $das_obj->adaptor->type );

  return grep{ $_->das_id() eq $_->das_segment_id() } @$dataref if $scope eq 'global';
  return grep{ $_->das_id() ne $_->das_segment_id() } @$dataref if $scope eq 'local';
  return @$dataref;
}

sub getEnsemblMapping {
  my ($self, $cs) = @_;

  my ($realm, $base, $species) = ($cs->{name}, $cs->{category}, $cs->{organismName});
  my $smap ='unknown';
  if ($base =~ /Chromosome|Clone|Contig|Scaffold/) {
    $smap = 'ensembl_location_'.lc($base);
  } elsif ($base eq 'NT_Contig') {
    $smap = 'ensembl_location_supercontig';
  } elsif ($base eq 'Gene_ID') {
    $smap = $realm eq 'Ensembl'       ? 'ensembl_gene'
          : $realm eq 'HUGO_ID'       ? 'hugo'
          : $realm eq 'MGI'           ? 'mgi'
          : $realm eq 'MarkerSymbol'  ? 'markersymbol'
          : $realm eq 'MGISymbol'     ? 'markersymbol'
          : $realm eq 'EntrezGene'    ? 'entrezgene_acc'
          : $realm eq 'IPI_Accession' ? 'ipi_acc'
          : $realm eq 'IPI_ID'        ? 'ipi_id'
          :                             'unknown'
          ;
  } elsif ($base eq 'Protein Sequence') {
    $smap = $realm eq 'UniProt'       ? 'uniprot/swissprot_acc'
          : $realm eq 'TrEMBL'        ? 'uniprot/sptrembl'
          : $realm =~ /Ensembl/       ? 'ensembl_peptide'
          :                             'unknown'
          ;
  }
  $species or $species = '.+';
#    warn "A:$cs#".join('*', $realm, $base, $species)."#$smap";
  return wantarray ? ($smap, $species) : $smap;
}

sub getRegistrySources {
  my $self = shift;
  if (defined($self->{data}->{_das_registry})) {
    return $self->{data}->{_das_registry};
  }

  my $filterT = sub { return 1; };
  my $filterM = sub { return 1; };
  my $keyText = $self->param('keyText');
  my $keyMapping = $self->param('keyMapping');
  if (defined (my $dd = $self->param('_das_filter'))) {
    if ($keyText) {
      $filterT = sub { 
        my $src = shift; 
        return 1 if ($src->{url} =~ /$keyText/); 
        return 1 if ($src->{nickname} =~ /$keyText/); 
        return 1 if ($src->{description} =~ /$keyText/); 
        return 0;
      };
    }
    if ($keyMapping ne 'any') {
      $filterM = sub { 
        my $src = shift; 
        foreach my $cs (@{$src->{coordinateSystem}}) {
          return 1 if ($self->getEnsemblMapping($cs) eq $keyMapping);
### Special case for Ensembl Location
          return 1 if ($self->getEnsemblMapping($cs) =~ /^$keyMapping/);
        }
        return 0;
      };
    }
  }
  my $das_url = $self->species_defs->DAS_REGISTRY_URL;

  my $source_arr = SOAP::Lite->service("${das_url}/services/das:das_directory?wsdl")->listServices();
  my $i = 0;
  my %registryHash = ();
  my $spec = $ENV{ENSEMBL_SPECIES};
  $spec =~ s/\_/ /g;
  while(ref $source_arr->[$i]){
    my $dassource = $source_arr->[$i++];
    next if ("@{$dassource->{capabilities}}" !~ /features/);
    if ($dassource->{url} !~ /(https?:\/\/)(.+das)\/(.+)/) {
      warn("Invalid URL : $dassource->{url}");
      next;
    }
    foreach my $cs (@{$dassource->{coordinateSystem}}) {
      my ($smap, $sp) = $self->getEnsemblMapping($cs);
      if ($smap ne 'unknown' && ($spec =~ /$sp/) && $filterT->($dassource) && $filterM->($dassource)) {
        my $id = $dassource->{id};
        $registryHash{$id} = $dassource; 
        last;
      }
    }
  }
  $self->{data}->{_das_registry} = \%registryHash;
  return $self->{data}->{_das_registry};
}

sub get_DASCollection {
  my ($self) = @_;
  return $self->{data}->{_object};
}

1;

