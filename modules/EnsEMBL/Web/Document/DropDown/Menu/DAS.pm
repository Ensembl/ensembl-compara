package EnsEMBL::Web::Document::DropDown::Menu::DAS;

use strict;

use base qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-dassource',
    'image_width' => 98,
    'alt'         => 'DAS sources'
  );

  my $script = $self->{'script'} || $ENV{ENSEMBL_SCRIPT};
  my $config = $self->{config};
## Replace this with the code which gets DAS sources from the Session... probably need some cute cacheing

  my $internal_das = $config->{species_defs}->ENSEMBL_INTERNAL_DAS_SOURCES;

  foreach my $source ( sort { $internal_das->{$a}->{'label'} cmp $internal_das->{$b}->{'label'} }  keys %$internal_das ) {
# skip those that not configured for this view      
    my $source_config = $internal_das->{$source};
    my @valid_views = defined ($source_config->{enable}) ? @{$source_config->{enable}} : (defined($source_config->{on}) ? @{$source_config->{on}} : []);
    next unless grep { $_ eq $script } @valid_views ; # skip those that not configured for this view
    if( my @select_views = defined ($source_config->{select}) ? @{$source_config->{select}} : () ) {
      next unless grep { $_ eq $script } @select_views;
      $config->set("managed_$source", "on", "on", 1) unless defined $config->get("managed_$source", "on");
    }
    $self->add_checkbox( "managed_$source", $source_config->{'label'} || $source );
  }

  my $ext_das = $self->{'object'}->get_session->get_das();
  foreach my $source (
    map  { $_->[1] }
    sort { $a->[0] cmp $b->[0] }
    map  { [ $_->get_data->{'label'}, $_ ] }
    grep { !( exists $_->get_data->{'species'} && $_->get_data->{'species'} ne $self->{'species'} )} @$ext_das
  ) { 
    my $source_config = $source->get_data;
    my @valid_views = defined ($source_config->{enable}) ? @{$source_config->{enable}} : (defined($source_config->{on}) ? @{$source_config->{on}} : []);
    next unless grep { $_ eq $script } @valid_views ;  # skip those that not configured for this view
    $self->add_checkbox( "managed_extdas_".$source->get_key, $source_config->{'label'} || $source->get_key );
  }


  my $URL = sprintf qq(/%s/dasconfview?conf_script=%s;%s), $self->{'species'}, $script, $self->{'LINK'};
  $self->add_link( "Manage sources...", qq(javascript:X=window.open('$URL','das_sources','left=10,top=10,resizable,scrollbars=yes');X.focus()), '');
  $URL = sprintf qq(/%s/%s?%sscript=%s), $self->{'species'}, 'urlsource', $self->{'LINK'}, $script;
  $self->add_link( "URL based data...",  qq(javascript:X=window.open('$URL','urlsources','left=10,top=10,scrollbars=yes');X.focus()),'');

  return $self;
}

1;
