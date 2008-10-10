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
  $self->print( q(<div id="local-tools">
      <ul>) );

  foreach my $link ( @{$self->entries} ) {
    if( $link->{'class'} eq 'disabled' ) {
      $self->printf('<li class="disabled" title="%s">%s</li>',$link->{'title'},$link->{'caption'});
      next;
    }
    $self->print('<li><a href="'.$link->{'url'}.'"');
    my $class = $link->{'class'};
    if( $link->{'type'} eq 'external' ) {
      $class .= ' ' if $class;
      $class .= 'external';
    }
    $class = qq( class="$class") if $class;
    $self->print( $class );
    if ($link->{'type'} eq 'external') {
      $self->print(' rel="external"');
    }
    $self->print('>'.$link->{'caption'}.'</a></li>');
  }

  $self->print( q(
      </ul>
      </div>) );
}

return 1;
