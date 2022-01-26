=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tools::Registry;

use strict;
use base qw(EnsEMBL::Web::Root);

use Bio::EnsEMBL::Registry;

sub new {
  my ($class, $conf) = @_;
  my $self = { 'conf' => $conf };
  bless $self, $class;
  return $self;
}

sub configure {
  ### Loads the adaptor into the registry from the self->{'conf'} definitions
  ### Returns: none
  my $self = shift;

  my %adaptors = (
    VARIATION           => 'Bio::EnsEMBL::Variation::DBSQL::DBAdaptor',
    VARIATION_PRIVATE   => 'Bio::EnsEMBL::Variation::DBSQL::DBAdaptor',
    FUNCGEN             => 'Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor',
    OTHERFEATURES       => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    RNASEQ              => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    CDNA                => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    CORE                => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    COMPARA             => 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor',
    COMPARA_PAN_ENSEMBL => 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor',
    USERDATA            => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    METADATA            => 'Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor',
    COMPARA_MULTIPLE    => undef,
    WEBSITE             => undef,
    GENE_AUTOCOMPLETE   => undef,
    WEB_HIVE            => undef,
    WEB_TOOLS           => undef,
    ARCHIVE             => undef,
    MART                => undef,
    GO                  => [ 'Bio::EnsEMBL::DBSQL::OntologyDBAdaptor', 'ontology' ],
    STABLE_IDS          => undef,
  );

  for my $species (sort keys %{$self->{'conf'}->{'_storage'}}, 'MULTI') {
    (my $sp = $species) =~ s/_/ /g;
    $sp = 'ancestral_sequences' if $sp eq 'MULTI';
    
    next unless ref $self->{'conf'}->{'_storage'}{$species};
    ## Owing to code changes elsewhere, some top-level keys aren't actually species-related
    ## Hawever a real species _must_ have a production name
    my $prod_name = $self->{'conf'}->{'_storage'}{$species}{'SPECIES_PRODUCTION_NAME'};
    next if (!$prod_name && $species ne 'MULTI');
    
    Bio::EnsEMBL::Registry->add_alias($species, $sp);

    Bio::EnsEMBL::Registry->add_alias($species, $prod_name) unless $sp eq 'ancestral_sequences';
    
    for my $type (sort { $b =~ /CORE/ <=> $a =~ /CORE/ } keys %{$self->{'conf'}->{'_storage'}{$species}{'databases'}}){
      ## Grab the configuration information from the SpeciesDefs object
      my $TEMP = $self->{'conf'}->{'_storage'}{$species}{'databases'}{$type};
     
      ## Skip if the name hasn't been set (mis-configured database)
      if ($sp ne 'ancestral_sequences') {
        warn((' ' x 10) . "[WARN] no NAME for $sp $type") unless $TEMP->{'NAME'};
        warn((' ' x 10) . "[WARN] no USER for $sp $type") unless $TEMP->{'USER'};
      }
      
      next unless $TEMP->{'NAME'} && $TEMP->{'USER'};

      my $is_collection = $self->{'conf'}->{'_storage'}{$species}{'SPP_IN_DB'} > 1 ? 1 : 0;
 
      my %arg = ( '-species' => $species, '-dbname' => $TEMP->{'NAME'}, '-species_id' =>  $self->{'conf'}->{'_storage'}{$species}->{SPECIES_META_ID} || 1, '-multispecies_db' => $is_collection );
      
      ## Copy through the other parameters if defined
      foreach (qw(host pass port user driver)) {
        $arg{"-$_"} = $TEMP->{uc $_} if defined $TEMP->{uc $_};
      }
      
      ## Check to see if the adaptor is in the known list above
      if ($type =~ /DATABASE_(\w+)/ && exists $adaptors{$1}) {
        my ($module, $group) = ref $adaptors{$1} eq 'ARRAY' ? @{$adaptors{$1}} : ($adaptors{$1}, lc $1);
        
        ## If the value is defined then we will create the adaptor here
        if ($module) {
          ## Create a new "module" object. Stores info - but doesn't create connection yet
          $module->new(%arg, '-group' => $group) if ($self->dynamic_use($module) && $module->can('new'));
        }
      } elsif ($type !~ /^DATABASE_(SESSION|ACCOUNTS)$/ && $type !~ /_MART_/) {
        warn "unknown database type $type\n";
      }
    }
  }
  
  Bio::EnsEMBL::Registry->load_all($SiteDefs::ENSEMBL_REGISTRY);
  Bio::EnsEMBL::Registry->no_version_check(1) if $SiteDefs::ENSEMBL_NOVERSIONCHECK;
}

1;
