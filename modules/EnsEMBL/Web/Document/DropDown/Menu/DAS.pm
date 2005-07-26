package EnsEMBL::Web::Document::DropDown::Menu::DAS;

use strict;
use EnsEMBL::Web::ExternalDAS;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
				@_, ## This contains the menu containers as the first element
				'image_name'  => 'y-dassource',
				'image_width' => 98,
				'alt'         => 'DAS sources'
				);

  my $script = $self->{'script'} || $ENV{ENSEMBL_SCRIPT};

  my $ext_das = new EnsEMBL::Web::ExternalDAS( $self->{'location'} );
  $ext_das->getConfigs($script, $script);

  my $ds2 = $ext_das->{'data'};

  my %das_list = map {(exists $ds2->{$_}->{'species'} && $ds2->{$_}->{'species'} ne $self->{'species'}) ? ():($_,$ds2->{$_}) } keys %$ds2;
  my $EXT = $self->{config}->{species_defs}->ENSEMBL_INTERNAL_DAS_SOURCES;

  foreach my $source ( sort { $EXT->{$a}->{'label'} cmp $EXT->{$b}->{'label'} }  keys %$EXT ) {
# skip those that not configured for this view      
      my @valid_views = defined ($EXT->{$source}->{enable}) ? @{$EXT->{$source}->{enable}} : (defined($EXT->{$source}->{on}) ? @{$EXT->{$source}->{on}} : []);
      next if (! grep {$_ eq $script} @valid_views);
      $self->add_checkbox( "managed_$source", $EXT->{$source}->{'label'} || $source );

  }

  foreach my $source ( sort { $das_list{$a}->{'label'} cmp $das_list{$b}->{'label'} } keys %das_list ) {
# skip those that not configured for this view      
      my @valid_views = defined ($das_list{$source}->{enable}) ? @{$das_list{$source}->{enable}} : (defined($das_list{$source}->{on}) ? @{$das_list{$source}->{on}} : []);
      next if (! grep {$_ eq $script} @valid_views);
      $self->add_checkbox( "managed_extdas_$source", $das_list{$source}->{'label'} || $source );
  }

  my $URL = sprintf qq(/%s/dasconfview?conf_script=%s;%s), $self->{'species'}, $script, $self->{'LINK'};
  $self->add_link( "Manage sources...", qq(javascript:X=window.open('$URL','das_sources','left=10,top=10,resizable,scrollbars=yes');X.focus()), '');

  $URL = sprintf qq(/%s/%s?%sscript=%s), $self->{'species'}, 'urlsource', $self->{'LINK'}, $script;
  $self->add_link( "URL based data...",  qq(javascript:X=window.open('$URL','urlsources','left=10,top=10,scrollbars=yes');X.focus()),'');
  $self->add_link( 'Server directory...', '/Docs/wiki/html/EnsemblDocs/DASdirectory.html', 'server' );
  return $self;
}

1;
