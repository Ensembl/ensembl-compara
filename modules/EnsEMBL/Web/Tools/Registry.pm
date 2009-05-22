package EnsEMBL::Web::Tools::Registry;

use strict;
use base qw(EnsEMBL::Web::Root);

use Bio::EnsEMBL::Registry;


sub new {
  my( $class, $conf ) = @_;
  my $self = { 'conf' => $conf };
  bless $self, $class;
  return $self;
}

sub configure {
  ### Loads the adaptor into the registry from the self->{'conf'} definitions
  ### Returns: none
  my $self = shift;

  my %adaptors = (
    'VARIATION'        => 'Bio::EnsEMBL::Variation::DBSQL::DBAdaptor',
    'FUNCGEN'          => 'Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor',
    'OTHERFEATURES'    => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'CDNA'             => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'VEGA'             => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'VEGA_ENSEMBL'     => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'CORE'             => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'COMPARA'          => 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor',
    'USERDATA'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
    'COMPARA_MULTIPLE' => undef,
    'WEBSITE'          => undef,
    'HEALTHCHECK'      => undef,
    'BLAST'            => undef,
    'BLAST_LOG'        => undef,
    'MART'             => undef,
    'GO'               => undef,
    'FASTA'            => undef,
  );

  for my $species ( keys %{$self->{'conf'}->{_storage}},'MULTI' ) {
    (my $sp = $species ) =~ s/_/ /g;
    $sp = 'Ancestral sequences' if $sp eq 'MULTI';
    
    next unless ref $self->{'conf'}->{'_storage'}{$species};
    
    Bio::EnsEMBL::Registry->add_alias( $species, $sp );
    for my $type ( keys %{$self->{'conf'}->{'_storage'}{$species}{databases}}){
## Grab the configuration information from the SpeciesDefs object
      my $TEMP = $self->{'conf'}->{'_storage'}{$species}{databases}{$type};
## Skip if the name hasn't been set (mis-configured database)
      if(! $TEMP->{NAME}){warn((' 'x10)."[WARN] no NAME for $sp $type") && next}
      if(! $TEMP->{USER}){warn((' 'x10)."[WARN] no USER for $sp $type") && next}
      next unless $TEMP->{NAME};
      next unless $TEMP->{USER};
     
      my %arg = ( '-species' => $species, '-dbname' => $TEMP->{NAME} );
## Copy through the other parameters if defined
      foreach (qw(host pass port user driver)) {
        $arg{ "-$_" } = $TEMP->{uc($_)} if defined $TEMP->{uc($_)};
      }
## Check to see if the adaptor is in the known list above
      if( $type =~ /DATABASE_(\w+)/ && exists $adaptors{$1}  ) {
## If the value is defined then we will create the adaptor here...
        if( my $module = $adaptors{ my $key = $1 } ) {
## Hack because we map DATABASE_CORE to 'core' not 'DB'....
          my $group = lc( $key );
## Create a new "module" object... stores info - but doesn't create connection yet!
          if( $self->dynamic_use( $module ) ) {
            $module->new( %arg, '-group' => $group );
          }
## Add information to the registry...
#          Bio::EnsEMBL::Registry->set_default_track( $species, $group );
        }
      } else {
        warn("unknown database type $type\n");
      }
    }
  }
  Bio::EnsEMBL::Registry->load_all($SiteDefs::ENSEMBL_REGISTRY);
  if ($SiteDefs::ENSEMBL_NOVERSIONCHECK) {
    Bio::EnsEMBL::Registry->no_version_check(1);
  }
}

1;
