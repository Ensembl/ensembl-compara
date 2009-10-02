package EnsEMBL::Web::Document::HTML::LocalTools;

### Generates the local context tools - configuration, data export, etc.

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  return $self;
}

sub add_entry {
### a
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub entries {
### a
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  return unless @{$self->entries};
  $self->print( q(<div id="local-tools" style="display:none">
    ) );

  my %icons = (
    'Configure this page' =>  'config',
    'Manage your data'    =>  'data',
    'Export data'         =>  'export',
    'Bookmark this page'  =>  'bookmark',
  );

  foreach my $link ( @{$self->entries} ) {
    my $icon = '<img src="/i/'.$icons{$link->{'caption'}}.'.png" alt="" style="vertical-align:middle;padding:0px 4px" />';
    if( $link->{'class'} eq 'disabled' ) {
      $self->printf('<p class="disabled" title="%s">%s%s</p>',$link->{'title'},$icon,$link->{'caption'});
      next;
    }
    $self->print('<p><a href="'.$link->{'url'}.'"');
    my $class = $link->{'class'};
    if( $link->{'type'} eq 'external' ) {
      $class .= ' ' if $class;
      $class .= 'external';
    }
    $class = qq( class="$class") if $class;
    $class .= ' style="display:none"' if $class =~ /modal_link/;
    $self->print( $class );
    if ($link->{'type'} eq 'external') {
      $self->print(' rel="external"');
    }
    $self->print('>'.$icon.$link->{'caption'}.'</a></p>');
  }

  $self->print( q(
      </div>) );
}

return 1;
