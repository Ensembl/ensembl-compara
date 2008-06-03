package EnsEMBL::Web::Document::HTML::GlobalContext;

### Generates the global context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub add_entry {
### a
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}
sub entries {
### a
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  $self->print( '
    <div id="tabs">
      <dl class="tabs">' );
  foreach my $entry ( @{$self->entries} ) {
    my $name = $entry->{caption};
    if ($name eq '-') {
      $name =  sprintf( '<span title="%s">%s</span>', $entry->{'disabled'}, $entry->{'type'});
    }
    else { 
      $name = CGI::escapeHTML( $name );
      if( $entry->{'url'} ) {
        $name = sprintf( '<a href="%s">%s</a>', $entry->{'url'}, $name );
      }
    }
    $self->printf( '
        <dd class="link %s">%s</dd>', $entry->{class}, $name );
  }
  $self->print( '
        <dt class="hidden">.</dt>
      </dl>
    </div>' );
}

return 1;
