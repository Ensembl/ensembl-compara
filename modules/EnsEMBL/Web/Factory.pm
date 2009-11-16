package EnsEMBL::Web::Factory;

use strict;
use warnings;
no warnings 'uninitialized';

use CGI qw(escapeHTML);

use EnsEMBL::Web::CoreObjects;

use base qw(EnsEMBL::Web::Proxiable);

# Additional Factory functionality

sub new {
  my ($class, $data) = @_;
  my $self = $class->SUPER::new($data);
  return $self;
}

sub DataObjects {
  my $self = shift;
  push @{$self->{'data'}{'_dataObjects'}}, @_ if @_;
  return $self->{'data'}{'_dataObjects'};
}

sub fastCreateObjects {
  my $self = shift;
  $self->createObjects(@_);
}

sub clearDataObjects {
  my $self = shift;
  $self->{'data'}{'_dataObjects'} = [];
}

sub featureIds {
  my $self = shift;
  $self->{'data'}{'_feature_IDs'} = shift if @_;
  return $self->{'data'}{'_feature_IDs'};
}

sub _archive {
  my ($self, $type, $parameter) = @_;

  # Redirect -> now uses code in idhistory
  my $db   = $self->param('db')||'core';
  my $name = $self->param($parameter) || $self->param('peptide') || $self->param('transcript') || $self->param('gene');
  my $var  = $self->param($parameter) ? lc(substr $parameter, 0, 1) : 
    $self->param('peptide')    ? 'p' :
    $self->param('transcript') ? 't' :
    'g';
    
  my $archiveStableID;
  
  eval {
    my $achiveStableIDAdaptor = $self->database($db)->get_ArchiveStableIdAdaptor;
    $name =~ s/(\S+)\.(\d+)/$1/; # remove version
    $archiveStableID = $achiveStableIDAdaptor->fetch_by_stable_id($name);
  };

  return unless $archiveStableID;
  
  $self->param($var, $name);
  $self->problem('archived');
}

sub _help {
  my ($self, $string) = @_;
  return sprintf '<p>%s</p>', escapeHTML($string);
}

sub _known_feature {
  my ($self, $type, $parameter) = @_;
  
  my $db           = $self->param('db')||'core';
  my $name         = $self->param($parameter) || $self->param(lc(substr $parameter, 0 , 1)) || $self->param('peptide') || $self->param('transcript') || $self->param('gene') || $self->param('t') || $self->param('g');
  my $sitetype     = $self->species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my @features     = ();
  my $adaptor_name = "get_$type".'Adaptor';
  my $adaptor;
  
  eval { 
    $adaptor = $self->database($db)->$adaptor_name; 
  };
  
  die "Datafactory: Unknown DBAdapter in get_known_feature: $@" if $@;
  
  eval {
    my $f = $adaptor->fetch_by_display_label($name);
    push @features, $f if $f;
  };
  
  if (!@features) {
    eval {
      @features = @{$adaptor->fetch_all_by_external_name($name)};
    };
  }
  
  if ($@) {
    $self->problem('fatal', "Error retrieving $type from database", $self->_help("An error occured while trying to retrieve the $type $name."));
  } elsif (@features) {
    $self->__data->{'objects'} = [ map {{ 'db' => $db, lc($type) => $_->stable_id }} @features ];
    
    if (scalar @features == 1) {
      $self->problem('mapped_id', 'Re-Mapped Identifier', 'The identifer has been mapped to a synonym');
    } else {
      $self->problem('mapped_id', 'Multiple mapped IDs',  'This feature id maps to multiple synonyms');
    }
  } else {
    my $db_adaptor = $self->database(lc $db);
    my $uoa        = $db_adaptor->get_UnmappedObjectAdaptor;
    
    eval { 
      @features = @{$uoa->fetch_by_identifier($name)}; 
    };
    
    if (!$@ && @features) {
      $self->problem('unmapped');
    } else {
      $self->problem('fatal', "$type '$name' not found", $self->_help("The identifier '$name' is not present in the current release of the $sitetype database. ") )  ;
    }
  }
}

1;
