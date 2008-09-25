package EnsEMBL::Web::DASConfig;

use strict;
use Data::Dumper;
use Time::HiRes qw(time);
use Bio::EnsEMBL::Utils::Exception qw(warning);
use base qw(Bio::EnsEMBL::ExternalData::DAS::Source);

# TODO: do these need to exist, and if so is this the best place for them?
our %DAS_DEFAULTS = (
  'LABELFLAG'      => 'u',
  'STRAND'         => 'b',
  'DEPTH'          => '4',
  'GROUP'          => '1',
  'DEFAULT_COLOUR' => 'grey50',
  'STYLESHEET'     => 'Y',
  'SCORE'          => 'N',
  'FG_MERGE'       => 'A',
  'FG_GRADES'      => 20,
  'FG_DATA'        => 'O',
  'FG_MIN'         => 0,
  'FG_MAX'         => 100,
);

# Create a new SourceConfig using a hash reference for parameters.
# Can also use an existing Bio::EnsEMBL::ExternalData::DAS::Source or
# EnsEMBL::Web::DASConfig object.
# Hash should contain:
#   url
#   dsn
#   coords
#   logic_name    (optional)
#   label         (optional)
#   description   (optional)
#   homepage      (optional)
#   maintainer    (optional)
#   active        (optional)
#   enable        (optional)
sub new_from_hashref {
  my ( $class, $hash ) = @_;
  
  # Convert old-style type & assembly parameters to single coords
  if (my $type = $hash->{type}) {
    $type =~ s/^ensembl_location//;
    push @{ $hash->{coords} }, Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
      -name    => $type,
      -version => $hash->{assembly},
      -species => $ENV{ENSEMBL_SPECIES},
    );
  }
  
  # Create a Bio::EnsEMBL::ExternalData::DAS::Source object to wrap
  # Valid params: url, dsn, coords, logic_name, label, description, homepage, maintainer
  my %params = map { '-'.uc $_ => $hash->{$_} } keys %{ $hash };
  my $self   = $class->SUPER::new( %params );
  
  bless $self, $class;
  
  for my $var ( qw( active enable )  ) {
    if ( exists $hash->{$var} ) {
      $self->$var( $hash->{$var} );
    }
  }
  
  # TODO: process manual stylesheet parameters (e.g. gradients)
  
  # TODO: process linkurls???
  
  return $self;
}

# DAS sources can be added from URL
# URL will have to be of the following format:
# /geneview?gene=BRCA2&add_das_source=(url=http://das1:9999/das+dsn=mouse_ko_allele+type=markersymbol+name=MySource+active=1)
# other parameters also can be specified, but those are optional ..
#  !!! You have to make sure that the name is unique before calling this function !!!
# TODO: move this code elsewhere?
sub new_from_URL {
  my ( $class, $URL ) = @_;
  $URL =~ s/[\(|\)]//g;                                # remove ( and |
  return unless $URL;
  $URL =~ s/\\ /###/g; # Preserve escaped spaces in source label
  my @das_keys = split(/\s/, $URL);                    # break on spaces...
  my %das_data = map { split (/\=/, $_,2) } @das_keys; # split each entry on =
  
  unless( exists $das_data{url} && exists $das_data{dsn} && (exists $das_data{type} || exists $das_data{coords}) ) {
    warning("DAS source ".$das_data{name}." ($URL) has not been added: Missing parameters");
    next;
  }
  
  # Don't allow external setting of category, ensure default is kept (external)
  delete $das_data{category};
  
  # Expand multi-value parameters
  $das_data{enable} = [split /,/, $das_data{enable}];
  $das_data{coords} = [split /,/, $das_data{coords}];
  
  # Restore spaces in the label
  if ($das_data{label}) {
    $das_data{label} =~ s/###/ /g ;
  }
  
  # Re-encode link URL
  if ($das_data{linkurl}) {
    $das_data{linkurl} =~ s/\$3F/\?/g;
    $das_data{linkurl} =~ s/\$3A/\:/g;
    $das_data{linkurl} =~ s/\$23/\#/g;
    $das_data{linkurl} =~ s/\$26/\&/g;
  }
  
  # TODO: are we still going to have a 'dasconfview'?
  push @{$das_data{enable}}, $ENV{'ENSEMBL_SCRIPT'} unless $ENV{'ENSEMBL_SCRIPT'} eq 'dasconfview';
  
  # TODO: not sure about these, we're handling coordinate systems differently
  #push @{$das_data{mapping}} , split(/\,/, $das_data{type});
  #$das_data{conftype} = 'external';
  #$das_data{type}     = 'mixed'    if scalar @{$das_data{mapping}} > 1;

  my $self = $class->new_from_hashref(\%das_data);
  return $self;
}

#================================#
#  Web-specific get/set methods  #
#================================#

=head2 active

  Arg [1]    : $is_active (scalar)
  Description: get/set for whether the source is turned on (true/false)
  Returntype : scalar
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub active {
  my ( $self, $is_active ) = @_;
  if ( defined $is_active ) {
    $self->{'active'} = $is_active;
  }
  return $self->{'active'};
}

=head2 enable

  Arg [1]    : $enabled_on (arrayref)
  Description: get/set for the views the source is available on (arrayref)
  Returntype : arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub enable {
  my ( $self, $enabled_on ) = @_;
  if ( defined $enabled_on ) {
    $self->{'enable'} = $enabled_on;
  }
  return $self->{'enable'};
}

=head2 category

  Arg [1]    : $category (scalar)
  Description: get/set for the data category (menu location) of the source
  Returntype : scalar
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub category {
  my ( $self, $category ) = @_;
  if ( defined $category ) {
    $self->{'category'} = $category;
  }
  return $self->{'category'};
}

sub internal {
  my $self = shift;
  $self->{'internal'} = shift if @_;
  return $self->{'internal'};
}

sub is_session {
  my $self = shift;
  return ($self->category || '') eq 'session';
}

sub is_user {
  my $self = shift;
  return ($self->category || '') eq 'user';
}

sub is_group {
  my $self = shift;
  return ($self->category || '') eq 'group';
}

sub is_external {
  my $self = shift;
  return $self->is_session || $self->is_user || $self->is_group ? 1 : 0;
}

#================================#
#   Audit/modification methods   #
#================================#

sub is_deleted {
  my $self = shift;
  return $self->{'_deleted'};
}

sub mark_clean {
  my $self = shift;
  $self->{'_altered'} = 0;
  $self->{'_deleted'} = 0;
}

sub mark_deleted {
  my $self = shift;
  $self->{'_deleted'} = 1;
  $self->{'_altered'} = 1;
}

sub mark_altered {
  my $self = shift;
  $self->{'_altered'} = 1;
}

sub is_altered {
  my $self = shift;
  return $self->{'_altered'};
}

sub equals {
  my ( $self, $cmp ) = @_;
  if ($self->full_url eq $cmp->full_url) {
    my $c1 = join '*', sort { $a cmp $b } map { $_->name.':'.$_->version } @{ $self->coord_systems };
    my $c2 = join '*', sort { $a cmp $b } map { $_->name.':'.$_->version } @{ $cmp ->coord_systems };
    return $c1 eq $c2;
  }
  return 0;
}

1;
